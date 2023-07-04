# Dantzig-Wolfe and Benders decompositions

Coluna is a framework to optimize mixed-integer programs that you can decompose.
In other words, if you remove the linking constraints or linking variables from your
program, you'll get sets of constraints (blocks) that you can solve independently.

Decompositions are typically used on programs whose constraints or variables can be divided into a set of "easy" constraints (respectively easy variables) and a set of "hard" constraints (respectively hard variables). Decomposing on constraints leads to Dantzig-Wolfe transformation while decomposing on variables leads to the Benders transformation. Both of these decompositions are implemented in Coluna. 

## Dantzig-Wolfe


### Original formulation

Let's consider the following coefficient matrix that has a block diagonal structure
in gray and some linking constraints in blue :

![Dantzig-Wolfe decomposition](../assets/img/dwdec.png)

You penalize the violation of the linking constraints in the
objective function. You can then solve the blocks independently.

The Dantzig-Wolfe reformulation gives rise to a master problem with an
exponential number of variables. Coluna dynamically generates these variables by
solving the subproblems. It's the column generation algorithm.

Let's consider the following original formulation in which we partition variables into
two vectors $x_1$ and $x_2$ :

```math
\begin{aligned}
\min \quad& c_1' x_1 + c_2' x_2 & \\
\text{s.t.} \quad& A_1 x_1 + A_2 x_2 \geq b & (1)\\
& D_1 x_1 \quad \quad \quad   \geq d_1 & (2) \\
& \quad   \quad \quad D_2 x_2 \geq d_2 & (3) \\
\end{aligned}
```

- variables $x_1$ and $x_2$ are the original variables of the problem (duty: `OriginalVar`)
- constraints $(1)$ are the linking constraints (duty: `OriginalConstr`)
- constraints $(2)$ shapes the first subproblem (duty: `OriginalConstr`)
- constraints $(3)$ shapes the second subproblem (duty: `OriginalConstr`)

### Master

When you apply a Dantzig-Wofe decomposition to this formulation, 
Coluna reformulates it into the following master problem :

```math
\begin{aligned}
\min \quad& \sum\limits_{q \in Q_1} c_1' \tilde{x_1}^q \lambda_q + \sum\limits_{q \in Q_2} c_2' \tilde{x_2}^q \lambda_q + f'a \\
\text{s.t.} \quad& \sum\limits_{q \in Q_1} A_1 \tilde{x_1}^q \lambda_q + \sum\limits_{q \in Q_2} A_2 \tilde{x_2}^q \lambda_q + a \geq b & (1)\\
& L_1 \leq \sum\limits_{q \in Q_1} \tilde{z}_1\lambda_q \leq U_1 & (2)\\
& L_2 \leq \sum\limits_{q \in Q_2} \tilde{z}_2\lambda_q \leq U_2 & (3)\\
& \lambda_q \geq 0, \quad q \in Q_1 \cup Q_2
\end{aligned}
```

where:
- set $Q_1$ is the index set of the solutions to the first subproblem 
- set $Q_2$ is the index set of the solutions to the second subproblem
- set of the solutions to the first is $\{\tilde{x}^q_1\}_{q \in Q_1}$ (duty: ` MasterRepPricingVar`)
- set of the solutions to the second subproblem is $\{\tilde{x}^q_2\}_{q \in Q_2}$ respectively (duty: ` MasterRepPricingVar`)
- constraint $(1)$ is the reformulation of the linking constraints (duty: `MasterMixedConstr`)
- constraint $(2)$ is the convexity constraint of the first subproblem and involves the lower $L_1$ and upper $U_1$ multiplicity of the subproblem (duty: `MasterConvexityConstr`)
- constraint $(3)$ is the convexity constraint of the second subproblem and involves the lower $L_2$ and upper $U_2$ multiplicity of the subproblem (duty: `MasterConvexityConstr`)
- variables $\tilde{z}_1$ and $\tilde{z}_2$ are representative of pricing setup variables in the master (always equal to $1$) (duty: `MasterRepPricingVar`)
- variables $\lambda_q$ are the columns (duty: `MasterCol`)
- variable $a$ is the artificial variable (duty: `MasterArtVar`)

At the beginning of the column generation algorithm, the master formulation does
not have any master columns. Therefore, the master may be infeasible. 
To prevent this, Coluna adds a local artificial variable $a$ specific to each constraint of the master and a global artificial variable.
Costs $f$ of artificial and global artificial variables can be defined in [Coluna.Params](@ref).

Lower and upper multiplicities of subproblems are $1$ by default.
However, when some subproblems are identical (same coefficient matrix and right-hand side), 
you can avoid solving all of them at each iteration by defining only one subproblem and
setting its multiplicity to the number of times it appears. See this [tutorial](@ref tuto_identical_sp) to get an example of Dantzig-Wolfe decomposition with identical subproblems. 


### Pricing Subproblem

Subproblems take the following form (here, it's the first subproblem):

```math
\begin{aligned}
\min \quad& \bar{c_1}' x_1 + z_1\\
\text{s.t.} \quad& D_1x_1 \geq d_1 & (1)\\
& \quad x_1 \geq 0
\end{aligned}
```

where:
- vector $\bar{c}$ is the reduced cost of the subproblem variables computed by the column generation algorithm. 
- variables $x_1$ are the subproblem variables (duty: `DwSpPricingVar`)
- constraint $(1)$ is the subproblem constraint (duty: `DwSpPureConstr`)
- variable $z_1$ is the pricing setup variable (always equal to $1$) (duty: `DwSpSetupVar`)


## Benders

### Original formulation

Let's consider the following coefficient matrix that has a block diagonal structure
in gray and some linking variables in blue :

![Benders decomposition](../assets/img/bdec.png)

The intuition behind Benders decomposition is that some hard problems can become much easier with some of their variables fixed. 
Benders aims to divide the variables of the problem into two "levels": the 1st level variables which, once fixed, make it easier to find a solution for the remaining variables, the so-called 2nd-level variables.

The question is how to set the 1st level variables. Benders' theory proceeds by the successive generation of cuts: given a 1st-level solution, we ask the following questions:

- Is the subproblem infeasible? If so, then the 1st-level solution is not correct and must be eliminated. A feasibility cut will be derived from the dual subproblem and added to the master.
- Does the aggregation of the master and subproblem solutions give rise to an optimal solution to the problem? It depends on a criterion that can be computed. If it is the case, we are done, else, we derive an optimality cut from the dual subproblem and add it into the master.

Formally, given an original MIP:

```math
\begin{aligned}
\min \quad& cx + fy & \\
\text{s.t.} \quad& Ax \geq a & (2) \\
& Ey \geq e                  & (3) \\
& Bx + Dy \geq d             & (4)\\
& x, y \geq 0, ~ x \in \mathbb{Z}^n\\
\end{aligned}
```

where:
- variables $x$ are the 1st-level variables (duty: `OriginalVar`)
- variables $y$ are the 2nd-level variables (duty: `OriginalVar`)
- constraints (2) are the 1st-level constraints (duty: `OriginalConstr`)
- constraints (3) are the 2nd-level constraints (duty: `OriginalConstr`)
- constraints (4) are the linking constraints (duty: `OriginalConstr`)

### Master

When you apply a Benders decomposition to this formulation, 
Coluna reformulates it into the following master problem :

```math
\begin{aligned}
\min \quad& cx + \sum\limits_{k \in K}\eta_k & \\
\text{s.t.} \quad& Ax \geq a & (5)\\
& <~\text{benders cuts}~> & (6) \\
& \eta_k \in \mathbb{R} \quad \forall k \in K\\
\end{aligned}
```

where:
- variables $x$ are the 1st-level variables (duty: `MasterBendFirstStageVar`)
- variables $\eta$ are the second stage cost variables (duty: `MasterBendSecondStageCostVar`)
- constraints (5) are the first-level constraints (duty: `MasterPureConstr`)
- constraints (6) are the benders cuts (duty: ``)

Note that the $\eta$ variables are free.

### Separation subproblem

Here is the form of a given separation subproblem:

```math
\begin{aligned}
\min \quad& fy & \\
\text{s.t.} \quad& Dy \geq d - B\bar{x} & (7) \\
& Ey \geq e & (8) \\
& y \geq 0 \\
\end{aligned}
```

where:
- variables $y$ are the 2nd-level variables (duty: `BendSpSepVar`)
- values $\bar{x}$ are a solution to the master problem 
- constraints (7) are the linking constraints with the 1st-level variables fixed to $\bar{x}$ (duty: `BendSpTechnologicalConstr`)
- constraints (8) are the 2nd-level constraints (duty: `BendSpPureConstr`)

Note that in the special case where the master problem is unbounded, the shape of the subproblem is slightly modified. See the [API](@ref api_benders) section to get more information.

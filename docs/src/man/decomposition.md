# Dantzig-Wolfe and Benders decompositions

Coluna is a framework to optimize mixed-integer programs that you can decompose.
In other words, if you remove the linking constraints or linking variables from you
program, you'll get sets of constraints (blocks) that you can solve independently.

Decompositions are typically used on programs whose constraints or variables can be divided into a set of "easy" constraints (respectively easy variables) and a set of "hard" constraints (respectively hard variables). Decomposing on constraints leads to Dantzig-Wolfe tranformation while decomposing on variables leads to Benders transformation. Both of these decompositions are implemented in Coluna. 

## Dantzig-Wolfe

### Classic Dantzig-Wolfe decomposition

Let's consider the following coefficient matrix that has a block diagonal structure
in gray and some linking constraints in blue :

![Dantzig-Wolfe decomposition](../assets/img/dwdec.png)

You penalize the violation of the linking constraints in the
objective function. You can then solve the blocks independently.

The Dantzig-Wolfe reformulation gives raise to a master problem with an
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

- $x_1$ and $x_2$ are the original variables of the problem
- $(1)$ are the linking constraints
- $(2)$ is the first subproblem
- $(3)$ is the second subproblem

When you apply a Dantzig-Wofe decomposition to this formulation, 
Coluna reformulates it into the following master problem :

```math
\begin{aligned}
\min \quad& \sum\limits_{q \in Q_1} c_1' \tilde{x_1}^q \lambda_q + \sum\limits_{q \in Q_2} c_2' \tilde{x_2}^q \lambda_q\\
\text{s.t.} \quad& \sum\limits_{q \in Q_1} A_1 \tilde{x_1}^q \lambda_q + \sum\limits_{q \in Q_2} A_2 \tilde{x_2}^q \lambda_q \geq b & (1)\\
& L_1 \leq \sum\limits_{q \in Q_1} \lambda_q \leq U_1 & (2)\\
& L_2 \leq \sum\limits_{q \in Q_2} \lambda_q \leq U_2 & (3)\\
& \lambda_q \geq 0, \quad q \in Q_1 \cup Q_2
\end{aligned}
```

where $Q_1$ is the index-set of the solutions to the first subproblem and 
$Q_2$ is the index-set of the solutions to the second subproblem.
The set of the solutions to the first and the second subproblems are $\{\tilde{x}^q_1\}_{q \in Q_1}$ and $\{\tilde{x}^q_2\}_{q \in Q_2}$ respectively. These solutions are expressed
in terms of the original variables.
The multiplicity of the subproblems is defined in the convexity constraints $(2)$ and $(3)$. $(1)$ is called the Master mixed constraint.
Lower and upper multiplicity are $1$ by default.

At the beginning of the column generation algorithm, the master formulation does
not have any master columns. Therefore, the master may be infeasible. 
To prevent this, Coluna adds a local artifical variable specific to each constraint of the master and a global artificial variable.
Costs of articial and global artificial variables can be defined in [Coluna.Params](@ref).

Subproblems take the following form (here, it's the first subproblem) :

```math
\begin{aligned}
\min \quad& \bar{c_1}' x_1\\
\text{s.t.} \quad& D_1x_1 \geq d_1 & (1)\\
& \quad x_1 \geq 0
\end{aligned}

```

where $\bar{c}$ is the reduced cost of the original variables computed by the column generation algorithm. $(1)$ is called the Dantzig-Wolfe subproblem "pure constraint". 

### Dantzig-Wolfe with identical subproblems (alpha)

When some subproblems are identical (same coefficient matrix and right-hand side), 
you can avoid solving all of them at each iteration by defining only one subproblem and
setting its multiplicity to the number of time it appears. See this [tutorial](@ref tuto_identical_sp) to get an example of Dantzig-Wolfe decomposition with identical subproblems. 


## Benders (alpha)

Let's consider the following coefficient matrix that has a block diagonal structure
in gray and some linking variables in blue :

![Benders decomposition](../assets/img/bdec.png)

The intuition behind Benders decomposition is that some hard problems can become much easier with some of their variables fixed. 
Benders aims to divide the variables of the problem into two "levels": the 1st level variables which, once fixed, make it easier to find a solution for the remaining variables, the so-called 2nd-level variables.

The question is how to set the 1st level variables. Benders' theory proceeds by successive generation of cuts: given a first-level solution, we ask the following questions:

- Is the subproblem infeasible? If so, then the 1st-level solution is not correct and must be eliminated. A feasibility cut will be derived from the dual subproblem and added to the master.
- Does the aggregation of the master and subproblem solutions give rise to an optimal solution to the problem? It depends on a criterion that can be computed. If it is the case, we are done, else, we derive an optimality cut from the dual subproblem and add it into the master.

Formally, given an original MIP:

TODO: create and insert draw-handing picture as in DW section

we decompose it into a master problem:

TODO: same with MASTER

and a subproblem:

TODO: same with CGLP

Note that in the special case where the master problem is unbounded, the shape of the subproblem is slightly modified. We must retrieve an unbounded ray $$(u^*, u_0^*)$$ from the master and consider the following subproblem instead:

TODO: same with modified CGLP

The rules used to generate the cuts are detailed in [this paper](https://link.springer.com/chapter/10.1007/978-3-030-45771-6_7) 

(or TODO: describe the rules ? or ref to the different methods of the API that implement the cut generation process and should explain how cuts are generated)


This decomposition is an alpha feature.




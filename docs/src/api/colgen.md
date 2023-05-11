```@meta
CurrentModule = Coluna
```

# ColGen API

Coluna provides an interface and generic functions to implement a multi-stage column
generation algorithm.Here is an overview of the main concepts and a description of the 
default implementation:

## Phases

In the first iterations, the restricted master LP contains a few columns and may be 
infeasible. To prevent this , we introduce artificial variables and we change the 
formulation depending on whether we want to prove the infeasibility of the master LP or find 
the optimal solution. The default implementation provides three phases:

```@docs
Coluna.Algorithm.ColGenPhase1
Coluna.Algorithm.ColGenPhase2
Coluna.Algorithm.ColGenPhase3
```

Here are the references of the interface:

```@docs
Coluna.ColGen.AbstractColGenPhase
Coluna.ColGen.AbstractColGenPhaseIterator
Coluna.ColGen.new_phase_iterator
Coluna.ColGen.initial_phase
Coluna.ColGen.next_phase
Coluna.ColGen.setup_reformulation!
Coluna.ColGen.setup_context!
Coluna.ColGen.stop_colgen_phase
```

## Stages

A stage is a set of consecutive iterations in which we use a given pricing solver. 
The goal is to solve the pricing subproblem with very fast heuristic solvers first and then
switch to a "more exact" solver when a given condition is met. The last stage generally uses
an exact solver.

Here are the references of the interface:

```@docs
Coluna.ColGen.AbstractColGenStage
Coluna.ColGen.AbstractColGenStageIterator
Coluna.ColGen.new_stage_iterator
Coluna.ColGen.initial_stage
Coluna.ColGen.next_stage
Coluna.ColGen.get_pricing_subprob_optimizer
Coluna.ColGen.stage_id
Coluna.ColGen.is_exact_stage
```

The default implementation of the stages is as follows.

```@docs
Coluna.ColGen.ColGenStageIterator
```

## Optimization of the Master

At each iteration, the algorithm requires a dual solution to the master LP to compute the
reduced cost of subproblem variables.

The default implementation optimizes the master with an LP solver through MathOptInterface.
It returns a primal and a dual solution.

Here are the references of the interface:

```@docs
Coluna.ColGen.optimize_master_lp_problem!
Coluna.ColGen.get_obj_val
Coluna.ColGen.get_primal_sol
Coluna.ColGen.get_dual_sol
Coluna.ColGen.is_optimal
Coluna.ColGen.is_infeasible
Coluna.ColGen.is_unbounded
```

Optionally, the algorithm can check the integrality of
the primal solution to the master LP in order to improve the global primal bound of the branch-cut-price algorithm.
The default implementation checks the integrality of the primal solution.

```@docs
Coluna.ColGen.check_primal_ip_feasibility!
Coluna.ColGen.isbetter
Coluna.ColGen.update_inc_primal_sol!
```

## Calculation of reduced costs

Reduced costs calculation is written as a math operation in the `run_colgen_iteration!` 
generic function. As a consequence, the dual solution to the master LP and the 
implementation of the two following methods must return data structures that support math operations.

Reduced costs calculation also requires the implementation of the two following methods:

```@docs
Coluna.ColGen.update_master_constrs_dual_vals!
Coluna.ColGen.get_subprob_var_orig_costs
Coluna.ColGen.get_subprob_var_coef_matrix
Coluna.ColGen.update_sp_vars_red_costs!
```

## Pricing strategy

The pricing strategy is basically an iterator used to iterate over the pricing subproblems
to optimize at each iteration of the column generation. The context can serve as memory of
the pricing strategy to change the way we iterate over subproblems between each column
generation iteration.

The default implementation iterates over all subproblems.

Here are the references of the interface:

```@docs
Coluna.ColGen.AbstractPricingStrategy
Coluna.ColGen.get_pricing_strategy
Coluna.ColGen.pricing_strategy_iterate
```

## Pricing subproblem optimization

At each iteration, the algorithm requires primal solutions to the pricing subproblems. The generic function supports multi-columns generation so you can return any number of solutions.

The default implementation supports optimization of the pricing subproblems using a MILP solver or a pricing callback. Non-robust valid inequalities are not supported by MILP solvers as they change the structure of the subproblems. When using a pricing callback, you must be aware of how Coluna calculates the reduced cost of a column:

The reduced cost of a column is splitted into three contributions:
- the contribution of the subproblem variables that is the primal solution cost given the reduced cost of subproblem variables
- the contribution of the non-robust constraints (i.e. master constraints that cannot be expressed using subproblem variables except the convexity constraint) that is not supported by MILP solver but that you must take into account in the pricing callback
- the contribution of the master convexity constraint that is automatically taken into account by Coluna once the primal solution returned.

Therefore, it is very important that you do not discard some columns based only on the primal solution cost because you don't know the contribution of the convexity constraint.


```@docs
Coluna.ColGen.optimize_pricing_problem!
Coluna.ColGen.get_primal_sols
Coluna.ColGen.get_dual_bound
```

You must also implement the `Coluna.ColGen.is_optimal`, `Coluna.ColGen.is_infeasible`, and
`Coluna.ColGen.is_unbounded` for the pricing result.

## Columns management and insertion

You can define your own data structure to manage the columns generated at a given iteration. Columns are inserted after the optimization of all pricing subproblems to allow the parallelization of the latter.

Here are the references of the interface:

```@docs
Coluna.ColGen.set_of_columns
Coluna.ColGen.push_in_set!
Coluna.ColGen.insert_columns!
```

## Dual bound calculation

```@docs
Coluna.ColGen.compute_sp_init_db
Coluna.ColGen.compute_dual_bound
```


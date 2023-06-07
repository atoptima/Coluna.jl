```@meta
CurrentModule = Coluna
```

# Benders API

Coluna provides an interface and generic functions to implement a Benders cut generation
algorithm.
Here is an overview of the main concepts and a description of the default implementation.

## Problem information

The following methods provide information about the reformulation that the Benders cut 
generation algorithm will solve:

```@docs
Coluna.Benders.is_minimization
Coluna.Benders.get_reform
Coluna.Benders.get_master
Coluna.Benders.get_benders_subprobs
```

## Benders cut generation algorithm

The following generic function contains all the logic of the algorithm:

```@docs
Coluna.Benders.run_benders_loop!
```

The latter method calls the following methods:

```@docs
Coluna.Benders.setup_reformulation!
Coluna.Benders.stop_benders
Coluna.Benders.after_benders_iteration
Coluna.Benders.benders_output_type
Coluna.Benders.new_output
```

and the generic function:

```@docs
Coluna.Benders.run_benders_iteration!
```

## Benders cut generation algorithm iteration

The `run_benders_iteration!` generic function calls the following method:

```@docs
Coluna.Benders.benders_iteration_output_type
Coluna.Benders.set_of_cuts
Coluna.Benders.set_of_sep_sols
Coluna.Benders.push_in_set!
Coluna.Benders.master_is_unbounded
Coluna.Benders.insert_cuts!
Coluna.Benders.build_primal_solution
Coluna.Benders.new_iteration_output
```

## Optimization of the Master

The Benders cut generation algorithm is an iterative algorithm that consists in fixing a part of the variable

At each iteration, the algorithm fixes the first-level solution.

The default implementation optimizes the master with an MILP solver through MathOptInterface.
It returns a primal solution.

```@docs
Coluna.Benders.optimize_master_problem!
```

If the master is unbounded...

```@docs
Coluna.Benders.treat_unbounded_master_problem_case!
```

## Separation Problem Optimization


```@docs
Coluna.Benders.setup_separation_for_unbounded_master_case!
Coluna.Benders.update_sp_rhs!
```

```@docs
Coluna.Benders.optimize_separation_problem!
Coluna.Benders.treat_infeasible_separation_problem_case!
```

## Optimization Results

| Method name      | Master | Separation |
| ---------------- | ------ | ---------- |
| `is_unbounded`   | X      | X          |
| `is_infeasible`  | X      | X          |
| `is_certificate` | X      |            |
| `get_primal_sol` | X      | X          |
| `get_dual_sol`   | X      |            |
| `get_obj_val`    | X      | X          |

```@docs
Coluna.Benders.is_unbounded
Coluna.Benders.is_infeasible
Coluna.Benders.is_certificate
Coluna.Benders.get_primal_sol
Coluna.Benders.get_dual_sol
Coluna.Benders.get_obj_val
```

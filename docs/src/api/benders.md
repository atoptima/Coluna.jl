```@meta
CurrentModule = Coluna
```

# Benders cut generation

Coluna provides an interface and generic functions to implement a Benders cut generation
algorithm.

In this section, we are first going to present the generic functions, the implementation with some theory backgrounds and then give the references of the interface.
The default implementation is based on the paper of 

You can find the generic functions and the interface in the `Benders` submodule and the 
default implementation in the `Algorithm` submodule at `src/Algorithm/benders`.

## Context

The `Benders` submodule provides an interface and generic functions to implement a benders cut generation algorithm. The implementation depends on an object called `context`.

```@docs
Coluna.Benders.AbstractBendersContext
```

Benders provides two types of context:

```@docs
Coluna.Algorithm.BendersContext
Coluna.Algorithm.BendersPrinterContext
```

## Generic functions

Generic functions are the core of the Benders cut generation algorithm.
There are three generic functions:

```@docs
Coluna.Benders.run_benders_loop!
```
See ...

```@docs
Coluna.Benders.run_benders_iteration!
```
See ...

These functions are independant of any other submodule of Coluna.
You can use them to implement your own Benders cut generation algorithm.

## Reformulation

The default implementation works with a reformulated problem contained in 
`MathProg.Reformulation` where master and subproblems are `MathProg.Formulation` objects.

The master has the following form:

```math
\begin{aligned}
\min \quad& obj & \\

\end{aligned}
```

The subproblems have the following form:

```math

```

**References**:

```@docs
Coluna.Benders.is_minimization
Coluna.Benders.get_reform
Coluna.Benders.get_master
Coluna.Benders.get_benders_subprobs
```

## Main loop

This is a description of how the `Coluna.Benders.run_benders_loop!` generic function behaves with the default implementation.

The loop stops if one of the following conditions is met:
- the master is infeasible
- a separation subproblem is infeasible
- the time limit is reached
- the maximum number of iterations is reached
- no new cut generated at the last iteration

**References**:

```@docs
Coluna.Benders.setup_reformulation!
Coluna.Benders.stop_benders
Coluna.Benders.after_benders_iteration
Coluna.Benders.AbstractBendersOutput
Coluna.Benders.benders_output_type
Coluna.Benders.new_output
```

## Benders cut generation iteration


```mermaid
flowchart TB;
    id1(Optimize master)
    id2(Treat unbounded master)
    id3(Setup separation subproblems)
    id4(Separation subproblem iterator)
    id5(Optimize separation subproblem)
    id6(Push cut into set)
    id7(Insert cut)
    id8(Iteration output)
    id1 --unbounded--> id2
    id2 --certificate--> id3
    id1 -- optimal --> id3
    id3 --> id4
    id4 -- subproblem --> id5
    id5 --> id6
    id6 --> id4
    id4 -- end --> id7
    id7 --> id8
    click id1 href "#Master-optimization" "Link to doc"
    click id2 href "#Unbounded-master-case" "Link to doc"
    click id3 href "#Setup-separation-subproblems" "Link to doc"
    click id4 href "#Subproblem-iterator" "Link to doc"
    click id5 href "#Separation-subproblem-optimization" "Link to doc"
    click id6 href "#Set-of-generated-cuts" "Link to doc"
    click id7 href "#Cuts-insertion" "Link to doc"
    click id8 href "#Iteration-output" "Link to doc"
```

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

### Master optimization

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

### Unbounded master case

Lorem ipsum:

**References**:

```@docs

```

### Setup separation subproblems

Lorem ipsum.

**References**:
```@docs
Coluna.Benders.setup_separation_for_unbounded_master_case!
Coluna.Benders.update_sp_rhs!
```

### Subproblem iterator

Not implemented yet.

### Separation subproblem optimization

Lorem ipsum

**References**:

```@docs
Coluna.Benders.optimize_separation_problem!
Coluna.Benders.treat_infeasible_separation_problem_case!
```

### Set of generated cuts

Lorem ipsum:

**References**:

```@docs

```

### Cuts insertion

Lorem ipsum:

**References**:

```@docs

```

### Iteration output

Lorem ipsum:

**References**:

```@docs

```


### Getters for Result data structures

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

## Stabilization

Not implemented yet.
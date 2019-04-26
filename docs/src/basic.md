# Basic example (Generalized Assignment Problem)

This quick start guide introduces features of Coluna.jl package.

## Model instantiation

A JuMP model using Coluna model can be instantiated as

```julia
  using JuMP
  import Coluna
  gap = Model(with_optimizer(Coluna.Optimizer))
```  

## Write the model

The model is written as a JuMP model. If you are not familiar with JuMP syntax,
you may want to check its [documentation]
(https://jump.readthedocs.io/en/latest/quickstart.html#defining-variables).

Consider a set of machines `Machines = 1:M` and a set of jobs `Jobs = 1:J`.
A machine `m` has a resource capacity `Capacity[m]`. When we assign a job
`j` to a machine `m`, the job has a cost `Cost[m,j]` and consumes
`Weight[m,j]` resources of the machine `m`. The goal is to minimize the jobs
cost sum by assigning each job to a machine while not exceeding the capacity of
each machine. The model is:

```julia
gap = Model(with_optimizer(AnySolver.Optimizer))

@variable(gap, x[m in data.machines, j in data.jobs], Bin)

@constraint(gap, cov[j in data.jobs],
        sum(x[m,j] for m in data.machines) >= 1)

@constraint(gap, knp[m in data.machines],
        sum(data.weight[j, m] * x[m, j] for j in data.jobs) <= data.capacity[m])

@objective(gap, Min,
        sum(data.cost[j, m] * x[m, j] for m in data.machines, j in data.jobs))
```

## Decomposition

Since the knapsack problem is tractable, we decompose the problem 
over machines to obtain one knapsack subproblem per machine. 

The decomposition is described through an axis. 
Each index of the axis represents a subproblem.

```julia
@axis(M, data.machine)
```

We define the indices of variables and constraints using this axis.

```julia
gap = BlockModel(with_optimizer(Coluna.Optimizer))

@variable(gap, x[m in M, j in data.jobs], Bin)

@constraint(gap, cov[j in data.jobs],
        sum(x[m,j] for m in M) >= 1)

@constraint(gap, knp[m in M],
        sum(data.weight[j, m] * x[m, j] for j in data.jobs) <= data.capacity[m])

@objective(gap, Min,
        sum(data.cost[j, m] * x[m, j] for m in M, j in data.jobs))
```

Afterward, we apply the Dantzig-Wolfe decomposition according to axis `M`.

```julia
@dantzig_wolfe_decomposition(gap, dec, M)
```

Now, we can solve the problem.

```julia
optimize!(gap)
```

## Logs

Here is an example of the solver's basic log

!!! warning
    To be updated ...

For every node, we print the best known primal and dual bounds. Within a node,
and for each column generation iteration, we print:

- the objective value of the restricted master LP `mlp`
- the number of columns added to the restricted master `cols`
- the computed lagrangian dual bound in this iteration `DB`
- the best integer primal bound `PB`

We also use TimerOutputs.jl package to print, at the end of the resolution,
the time consumed and the allocations made in most critical sections.

## Other Examples

Other examples are available [here]
(https://github.com/atoptima/Coluna.jl/tree/master/examples)

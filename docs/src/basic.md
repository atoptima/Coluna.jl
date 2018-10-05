# Basic example

This quick start guide introduces features of Coluna.jl package.

## BlockModel instantiation

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
@variable(gap, x[m in data.machines, j in data.jobs], Bin)

@constraint(gap, cov[j in data.jobs],
        sum(x[m,j] for m in data.machines) >= 1)

@constraint(gap, knp[m in data.machines],
        sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= data.capacity[m])

@objective(gap, Min,
        sum(data.cost[j,m]*x[m,j] for m in data.machines, j in data.jobs))
```

## Decomposition

The decomposition is described through the following annotations:

```julia
# setting constraint annotations for the decomposition
for j in data.jobs
    set(gap, Coluna.ConstraintDantzigWolfeAnnotation(), cov[j], 0)
end
for m in data.machines
    set(gap, Coluna.ConstraintDantzigWolfeAnnotation(), knp[m], m)
end

# setting variable annotations for the decomposition
for m in data.machines, j in data.jobs
    set(gap, Coluna.VariableDantzigWolfeAnnotation(), x[m,j], m)
end
```

Now you can solve the problem and get the solution values as you do with
JuMP when using any other Optimizer.

Other examples are available [here]
(https://github.com/ResourceMind/Coluna.jl/tree/master/examples)

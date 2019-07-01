# Quick start

This quick start guide introduces main features of Coluna.jl package through an
example.

## Instantiation of solver and model

Coluna requires `JuMP` and `BlockDecomposition` to write the model and apply a 
decomposition. In this example, we use `GLPK` as the underlying solver.

```julia
using JuMP, BlockDecomposition, GLPK, Coluna
```

We instantiate the solver and define how we want to solve the decomposed formulation. See the page [Strategies and Algorithms](https://atoptima.github.io/Coluna.jl/latest/strategies/) for more information.

```julia
coluna = JuMP.with_optimizer(
    Coluna.Optimizer,
    params = Coluna.Params(
        global_strategy = Coluna.GlobalStrategy(Coluna.SimpleBnP, Coluna.SimpleBranching, Coluna.DepthFirst)
    ),
    default_optimizer = with_optimizer(GLPK.Optimizer)
)
```

Then, we instanciate the model

```julia
model = BlockModel(coluna, bridge_constraints = false)
```  

!!! note
    Argument `bridge_constraints = false` is mandatory until the fix we made 
    in MathOptInterface.jl is available on the stable version.

## Generalized Assignment problem

The model is written as a JuMP model. If you are not familiar with JuMP syntax,
you may want to check its [documentation]
(http://www.juliaopt.org/JuMP.jl/stable/).

Consider a set of machines `Machines = 1:M` and a set of jobs `Jobs = 1:J`.
A machine `m` has a resource capacity `Capacity[m]`. When we assign a job
`j` to a machine `m`, the job has a cost `Cost[m,j]` and consumes
`Weight[m,j]` resources of the machine `m`. The goal is to minimize the jobs
cost sum by assigning each job to a machine while not exceeding the capacity of
each machine.

Since the knapsack problem is tractable, we decompose the problem 
over machines to obtain one knapsack subproblem per machine. 

The decomposition is described through an axis. 
Each index of the axis represents a subproblem.

```julia
@axis(Machines, 1:M)
Jobs = 1:J
```

Then, we write the model

```julia
@variable(model, x[m in Machines, j in Jobs], Bin)

@constraint(model, cov[j in Jobs],
        sum(x[m, j] for m in Machines) >= 1)

@constraint(model, knp[m in Machines],
        sum(Weight[m, j] * x[m, j] for j in Jobs) <= Capacity[m])

@objective(model, Min,
        sum(Cost[m, j] * x[m, j] for m in Machines, j in Jobs))
```

Afterward, we apply the Dantzig-Wolfe decomposition according to axis `Machines`.

```julia
@dantzig_wolfe_decomposition(model, dec, Machines)
```

Now, we can solve the problem.

```julia
optimize!(model)
```

## Example

Try yourself by copying the following data and the example above in your julia terminal :

```julia
M = 4
J = 30
Cost = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5 15.2 14.3 12.6 9.2 20.8 11.7 17.3 9.2 20.3 11.4 6.2 13.8 10.0 20.9 20.6;  19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2 19.7 19.5 7.2 6.4 23.2 8.1 13.6 24.6 15.6 22.3 8.8 19.1 18.4 22.9 8.0;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7 16.6 8.3 15.9 24.3 18.6 21.1 7.5 16.8 20.9 8.9 15.2 15.7 12.7 20.8 10.4;  13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2 12.9 11.3 7.5 6.5 11.3 7.8 13.8 20.7 16.8 23.6 19.1 16.8 19.3 12.5 11.0]
Weight = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78 71 50 99 92 83 53 91 68 61 63 97 91 77 68 80; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91 75 66 100 69 60 87 98 78 62 90 89 67 87 65 100; 91 81 66 63 59 81 87 90 65 55 57 68 92 91 86 74 80 89 95 57 55 96 77 60 55 57 56 67 81 52;  62 79 73 60 75 66 68 99 69 60 56 100 67 68 54 66 50 56 70 56 72 62 85 70 100 57 96 69 65 50]
Capacity = [1020 1460 1530 1190]
```

## Logs

For every node, we print the best known primal and dual bounds.

```
************************************************************
1 open nodes. Treating node 5. Parent is 1
Current best known bounds : [ 579.0 , 580.0 ]
Elapsed time: 1.2622311115264893 seconds
Subtree dual bound is 580.0
Branching constraint:  + 1.0 x[3,24] >= 1.0 
************************************************************
```

Within a node, and for each column generation iteration, we print:

```
<it=3> <et=7> <mst=0.000> <sp=0.001> <cols=4> <mlp=100570.3000> <DB=-299343.0000> <PB=Inf>
<it=4> <et=7> <mst=0.000> <sp=0.001> <cols=4> <mlp=584.7000> <DB=9.1000> <PB=584.7000>
<it=5> <et=7> <mst=0.000> <sp=0.001> <cols=4> <mlp=439.1000> <DB=9.1000> <PB=439.1000>
```

- the iteration number `it`
- the elapsed time `et` in seconds 
- the elapsed time solving the linear relaxation of the restricted master `mst` in seconds
- the number of columns added to the restricted master `cols`
- the objective value of the restricted master LP `mlp`
- the computed lagrangian dual bound in this iteration `DB`
- the best integer primal bound `PB`

We also use TimerOutputs.jl package to print, at the end of the resolution,
the time consumed and the allocations made in most critical sections.


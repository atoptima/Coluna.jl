# Callbacks

Callbacks are functions defined by the user that allow him to take over part of the default 
algorithm. 
The more classical callbacks in a branch-and-price solver are:

- Pricing callback that takes over the procedure to determine whether the current master LP 
    solution is optimum or produce an entering variable with negative reduced cost
- Separation callback that takes over the procedure to determine whether the current master
    LP solution is feasible or produce a valid problem constraint that is violated
- Branching callback that takes over the procedure to determine whether the current master 
    LP solution is integer or produce a valid branching disjunctive constraint that rules out 
    the current fractional solution.

In this page, we use following aliases : 
```julia
const BD = BlockDecomposition
const MOI = MathOptInterface
```

## Pricing callback

The pricing callback let you define how to solve the subproblems of a Dantzig-Wolfe 
decomposition to generate a new entering column in the master program. 
This callback is usefull when you know an efficient algorithm to solve the subproblems, 
i.e. an algorithm better than solving the subproblem with a MIP solver.

Let us see an example with the generalized assignment problem for which the JuMP model takes the form:

```julia
model = BlockModel(optimizer, bridge_constraints = false)

@axis(M, 1:nb_machines)
J = 1:nb_jobs

# JuMP model
@variable(model, x[m in M, j in J], Bin)
@constraint(model, cov[j in J], sum(x[m,j] for m in M) == 1)
@objective(model, Min, sum(c[m,j]*x[m,j] for m in M, j in J))
@dantzig_wolfe_decomposition(model, dwdec, M)
```

where as you can see, we omitted the knapsack constraints. 
These constraints are implicitly defined by the algorithm called in the pricing callback.

Assume we have the following method that solves efficienlty a knapsack problem:

```julia
solve_knp(job_costs, lb_jobs, ub_jobs, capacity)
```
where 
- `job_costs` is an array that contains the cost of each job
- `lb_jobs` is an array where the $j$-th entry equals $1$ if it is mandatory to put job $j$ in the knapsack
- `ub_jobs` is an array where the $j$-th entry equals $0$ if job $j$ cannot be put in the knapsack
- `capacity` is a real that is equal to the capacity of the knapsack

The pricing callback is a function. It takes as argument `cbdata` which is a data structure
that allows the user to interact with the solver within the pricing callback.

```julia
function my_pricing_callback(cbdata)
    # Retrieve the index of the subproblem (it will be one of the values in M)
    cur_machine = BD.callback_spid(cbdata, model)

    # Retrieve reduced costs of subproblem variables
    red_costs = [BD.callback_reduced_cost(cbdata, x[cur_machine, j]) for j in J]

    # Retrieve current bounds of subproblem variables
    lb_x = [BD.callback_lb(cbdata, x[cur_machine, j]) for j in J]
    ub_x = [BD.callback_ub(cbdata, x[cur_machine, j]) for j in J]

    # Solve the knapsack with a custom algorithm
    jobs_assigned_to_cur_machine = solve_knp(red_costs, lb_x, ub_x, Q[cur_machine])

    # Create the solution (send only variables with non-zero values)
    sol_vars = [x[cur_machine, j] for j in jobs_assigned_to_cur_machine]
    sol_vals = [1.0 for j in jobs_assigned_to_cur_machine]
    sol_cost = sum(red_costs[j] for j in jobs_assigned_to_cur_machine)

    # Submit the solution to the subproblem to Coluna
    MOI.submit(model, BD.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)
    return
end
```

The pricing callback is provided to Coluna using the keyword `solver` in the method 
`specify!`.

```julia
master = BD.getmaster(dwdec)
subproblems = BD.getsubproblems(dwdec)
BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_callback)
```

## Separation callbacks

Separation callbacks let you define how to separate cuts or constraints.

### Robust facultative cuts

This callback allows you to add cuts to the master problem. 
[Example in the JuMP documentation](http://www.juliaopt.org/JuMP.jl/stable/callbacks/#User-cuts-1).
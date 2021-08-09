# # Callbacks

# Callbacks are functions defined by the user that allow him to take over part of the default 
# algorithm. 
# The more classical callbacks in a branch-and-price solver are:

# - Pricing callback that takes over the procedure to determine whether the current master LP 
#     solution is optimum or produces an entering variable with negative reduced cost by solving subproblems
# - Separation callback that takes over the procedure to determine whether the current master
#     LP solution is feasible or produces a valid problem constraint that is violated
# - Branching callback that takes over the procedure to determine whether the current master 
#     LP solution is integer or produces a valid branching disjunctive constraint that rules out 
#     the current fractional solution.

# On this page, we use the following aliases : 

# ## Pricing callback

# The pricing callback let you define how to solve the subproblems of a Dantzig-Wolfe 
# decomposition to generate a new entering column in the master program. 
# This callback is useful when you know an efficient algorithm to solve the subproblems, 
# i.e. an algorithm better than solving the subproblem with a MIP solver.

# First, we load the packages and define aliases :

using Coluna, BlockDecomposition, JuMP, MathOptInterface, GLPK;
const BD = BlockDecomposition;
const MOI = MathOptInterface;

# Let us see an example with the following generalized assignment problem :

nb_machines = 4;
nb_jobs = 30;

c = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5 15.2 14.3 12.6 9.2 20.8 11.7 17.3 9.2 20.3 11.4 6.2 13.8 10.0 20.9 20.6;  19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2 19.7 19.5 7.2 6.4 23.2 8.1 13.6 24.6 15.6 22.3 8.8 19.1 18.4 22.9 8.0;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7 16.6 8.3 15.9 24.3 18.6 21.1 7.5 16.8 20.9 8.9 15.2 15.7 12.7 20.8 10.4;  13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2 12.9 11.3 7.5 6.5 11.3 7.8 13.8 20.7 16.8 23.6 19.1 16.8 19.3 12.5 11.0];
w = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78 71 50 99 92 83 53 91 68 61 63 97 91 77 68 80; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91 75 66 100 69 60 87 98 78 62 90 89 67 87 65 100; 91 81 66 63 59 81 87 90 65 55 57 68 92 91 86 74 80 89 95 57 55 96 77 60 55 57 56 67 81 52;  62 79 73 60 75 66 68 99 69 60 56 100 67 68 54 66 50 56 70 56 72 62 85 70 100 57 96 69 65 50];
Q = [1020 1460 1530 1190];

# with the following Coluna configuration

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default BCP
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

# for which the JuMP model takes the form:

model = BlockModel(coluna);

@axis(M, 1:nb_machines);
J = 1:nb_jobs;

@variable(model, x[m in M, j in J], Bin);
@constraint(model, cov[j in J], sum(x[m,j] for m in M) == 1);
@objective(model, Min, sum(c[m,j]*x[m,j] for m in M, j in J));
@dantzig_wolfe_decomposition(model, dwdec, M);

# where, as you can see, we omitted the knapsack constraints. 
# These constraints are implicitly defined by the algorithm called in the pricing callback.

# Let's use the knapsack algorithms from the unregistered package 
# [KnapsackLib](https://github.com/rafaelmartinelli/KnapsackLib.jl) to solve the
# knapsack subproblems.

using KnapsackLib;

# The pricing callback is a function. 
# It takes as argument `cbdata` which is a data structure
# that allows the user to interact with Coluna within the pricing callback.

function my_pricing_callback(cbdata)
    ## Retrieve the index of the subproblem (it will be one of the values in M)
    cur_machine = BD.callback_spid(cbdata, model)

    ## Retrieve reduced costs of subproblem variables
    red_costs = [BD.callback_reduced_cost(cbdata, x[cur_machine, j]) for j in J]

    ## Keep jobs with negative reduced costs
    selected_jobs = Int[]
    selected_costs = Int[]
    for j in J
        if red_costs[j] <= 0.0
            push!(selected_jobs, j)
            ## scale reduced costs to int
            push!(selected_costs, -round(Int, 10000 * red_costs[j]))
        end
    end

    if sum(w[cur_machine, selected_jobs]) <= Q[cur_machine]
        ## Don't need to run the algorithm, 
        ## all jobs with negative reduced cost are assigned to the machine
        jobs_assigned_to_cur_machine = selected_jobs
    else 
        ## Run the algorithm
        items = [KnapItem(w,c) for (w,c) in zip(w[cur_machine, selected_jobs], selected_costs)]
        data = KnapData(Q[cur_machine], items)

        ## Solve the knapsack with the algorithm from KnapsackLib
        _, jobs_assigned_to_cur_machine = solveKnapExpCore(data)
    end

    ## Create the solution (send only variables with non-zero values)
    sol_vars = [x[cur_machine, j] for j in jobs_assigned_to_cur_machine]
    sol_vals = [1.0 for _ in jobs_assigned_to_cur_machine]
    sol_cost = sum(red_costs[j] for j in jobs_assigned_to_cur_machine)

    ## Submit the solution to the subproblem to Coluna
    MOI.submit(model, BD.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)
    return
end

# The pricing callback is provided to Coluna using the keyword `solver` in the method 
# `specify!`.

subproblems = BD.getsubproblems(dwdec);
BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_callback);

# You can then optimize :

optimize!(model);

# and retrieve information you need as usual :

getobjectivevalue(model)

# # Separation callbacks

# Separation callbacks let you define how to separate cuts or constraints.

# ## Facultative & essential cuts (user cut & lazy constraint)

# This callback allows you to add cuts to the master problem.
# The cuts must be expressed in terms of the original variables.
# Then, Coluna expresses them over the master variables.
# You can find an example of [essential cut separation](https://jump.dev/JuMP.jl/stable/tutorials/Mixed-integer%20linear%20programs/callbacks/#Lazy-constraints)
# and [facultative cut separation](https://jump.dev/JuMP.jl/stable/tutorials/Mixed-integer%20linear%20programs/callbacks/#User-cut) 
# in the JuMP documentation.

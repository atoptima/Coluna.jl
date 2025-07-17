# # [Pricing callback](@id tuto_pricing_callback)

# The pricing callback lets you define how to solve the subproblems of a Dantzig-Wolfe 
# decomposition to generate a new entering column in the master program. 
# This callback is useful when you know an efficient algorithm to solve the subproblems, 
# i.e. an algorithm better than solving the subproblem with a MIP solver.

# First, we load the packages and define aliases :

using Coluna, BlockDecomposition, JuMP, MathOptInterface, GLPK;
const BD = BlockDecomposition;
const MOI = MathOptInterface;

# Let us see an example with the following generalized assignment problem :

M = 1:3;
J = 1:15;
c = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5; 19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7; 13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2];
w = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91;91 81 66 63 59 81 87 90 65 55 57 68 92 91 86; 62 79 73 60 75 66 68 99 69 60 56 100 67 68 54];
Q = [1020 1460 1530];

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

@axis(M_axis, M);

@variable(model, x[m in M_axis, j in J], Bin);
@constraint(model, cov[j in J], sum(x[m,j] for m in M_axis) == 1);
@objective(model, Min, sum(c[m,j]*x[m,j] for m in M_axis, j in J));
@dantzig_wolfe_decomposition(model, dwdec, M_axis);

# where, as you can see, we omitted the knapsack constraints. 
# These constraints are implicitly defined by the algorithm called in the pricing callback.

# Let's use a knapsack algorithm defined by the following function to solve the knapsack
# subproblems:

function solve_knapsack(cost, weight, capacity)
    sp_model = Model(GLPK.Optimizer)
    items = 1:length(weight)
    @variable(sp_model, x[i in items], Bin)
    @constraint(sp_model, weight' * x <= capacity)
    @objective(sp_model, Min, cost' * x)
    optimize!(sp_model)
    x_val = value.(x)
    return filter(i -> x_val[i] ≈ 1, collect(items))
end

# You can replace the content of the function with any algorithm that solves the knapsack
# problem (such as algorithms provided by the unregistered package 
# [Knapsacks](https://github.com/rafaelmartinelli/Knapsacks.jl)).

# The pricing callback is a function. 
# It takes as argument `cbdata` which is a data structure
# that allows the user to interact with Coluna within the pricing callback.

function my_pricing_callback(cbdata)
    ## Retrieve the index of the subproblem (it will be one of the values in M_axis)
    cur_machine = BD.callback_spid(cbdata, model)
    
    ## Uncomment to see that the pricing callback is called.
    ## println("Pricing callback for machine $(cur_machine).")

    ## Retrieve reduced costs of subproblem variables
    red_costs = [BD.callback_reduced_cost(cbdata, x[cur_machine, j]) for j in J]

    ## Run the knapsack algorithm
    jobs_assigned_to_cur_machine = solve_knapsack(red_costs, w[cur_machine, :], Q[cur_machine])

    ## Create the solution (send only variables with non-zero values)
    sol_vars = VariableRef[x[cur_machine, j] for j in jobs_assigned_to_cur_machine]
    sol_vals = [1.0 for _ in jobs_assigned_to_cur_machine]
    sol_cost = sum(red_costs[j] for j in jobs_assigned_to_cur_machine; init = 0.0)

    ## Submit the solution to the subproblem to Coluna
    MOI.submit(model, BD.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)
    
    ## Submit the dual bound to the solution of the subproblem
    ## This bound is used to compute the contribution of the subproblem to the lagrangian
    ## bound in column generation.
    MOI.submit(model, BD.PricingDualBound(cbdata), sol_cost) # optimal solution
    return
end

# The pricing callback is provided to Coluna using the keyword `solver` in the method 
# `specify!`.

subproblems = BD.getsubproblems(dwdec);
BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_callback);

# You can then optimize :

optimize!(model);

# and retrieve the information you need as usual :

objective_value(model)

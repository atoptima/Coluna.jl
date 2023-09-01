# # Initial columns 

# The initial columns callback let you provide initial columns associated to each problem
# ahead the optimization.
# This callback is useful when you have an efficient heuristic that finds feasible solutions
# to the problem. You can then extract columns from the solutions and give them to Coluna
# through the callback.
# You have to make sure the columns you provide are feasible because Coluna won't check their 
# feasibility.
# The cost of the columns will be computed using the perennial cost of subproblem variables.

# Let us see an example with the following generalized assignment problem :

M = 1:3;
J = 1:5;
c = [1 1 1 1 1; 1.2 1.2 1.1 1.1 1; 1.3 1.3 1.1 1.2 1.4];
Q = [3, 2, 3];

# with the following Coluna configuration

using JuMP, GLPK, BlockDecomposition, Coluna;

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default branch-cut-and-price
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

# for which the JuMP model takes the form:

@axis(M_axis, M);
model = BlockModel(coluna); 

@variable(model, x[m in M_axis, j in J], Bin);
@constraint(model, cov[j in J], sum(x[m, j] for m in M_axis) >= 1);
@constraint(model, knp[m in M_axis], sum(x[m, j] for j in J) <= Q[m]);
@objective(model, Min, sum(c[m, j] * x[m, j] for m in M_axis, j in J));

@dantzig_wolfe_decomposition(model, decomposition, M_axis)

subproblems = getsubproblems(decomposition)
specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)


# Let's consider that the following assignment patterns are good candidates:

machine1 = [[1,2,4], [1,3,4], [2,3,4], [2,3,5]];
machine2 = [[1,2], [1,5], [2,5], [3,4]];
machine3 = [[1,2,3], [1,3,4], [1,3,5], [2,3,4]];

initial_columns = [machine1, machine2, machine3];

# We can write the initial columns callback:

function initial_columns_callback(cbdata)
    ## Retrieve the index of the subproblem (it will be one of the values in M_axis)
    spid = BlockDecomposition.callback_spid(cbdata, model)
    println("initial columns callback $spid")

    ## Retrieve assignment patterns of a given machine
    for col in initial_columns[spid]
        ## Create the column in the good representation
        vars = [x[spid, j] for j in col]
        vals = [1.0 for _ in col]

        ## Submit the column
        MOI.submit(model, BlockDecomposition.InitialColumn(cbdata), vars, vals)
    end
end

# The initial columns callback is a function.
# It takes as argument `cbdata` which is a data structure
# that allows the user to interact with Coluna within the callback.

# We provide the initial columns callback to Coluna through the following method:

MOI.set(model, BlockDecomposition.InitialColumnsCallback(), initial_columns_callback)

# You can then optimize:

optimize!(model)

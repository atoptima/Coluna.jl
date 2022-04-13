# # Provide initial columns


# Let us consider the following problem.

M = 1:3;
J = 1:5;
c = [1, 1, 1, 1; 1.2, 1.2, 1.1, 1.1, 1; 1.3, 1.3, 1.1, 1.2, 1.4];
Q = [3, 2, 3];


using JuMP, GLPK, BlockDecomposition, Coluna;

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default branch-cut-and-price
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);


@axis(M_axis, M);
model = BlockModel(coluna); 

@variable(model, x[m in M_axis, j in J], Bin);
@constraint(model, cov[j in J], sum(x[m, j] for m in M_axis) >= 1);
@constraint(model, knp[m in M_axis], sum(w[m, j] * x[m, j] for j in J) <= Q[m]);
@objective(model, Min, sum(c[m, j] * x[m, j] for m in M_axis, j in J));

@dantzig_wolfe_decomposition(model, decomposition, M_axis)

subproblems = getsubproblems(decomposition)
specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)

machine1 = [[1,2,4], [1,3,4], [2,3,4], [2,3,5]];
machine2 = [[1,2], [1,5], [2,5], [3,4]];
machine3 = [[1,2,3], [1,3,4], [1,3,5], [2,3,4]];

initial_columns = [machine1, machine2, machine3];

function initial_columns_callback(cbdata)
    spid = BlockDecomposition.callback_spid(cbdata, model)
    for col in initial_columns[spid]
        vars = [x[spid, j] for j in col]
        vals = [1.0 for _ in col]
        MOI.submit(model, BlockDecomposition.InitialColumn(cbdata), vars, vals)
    end
end

MOI.set(model, BlockDecomposition.InitialColumnsCallback(), initial_columns_callback)

optimize!(model)

using BlockDecomposition, Coluna, JuMP, GLPK;
const BD = BlockDecomposition
function column_generation(model, sp_ids, vars...)
    @dantzig_wolfe_decomposition(model, decomp, sp_ids);
    subproblems = getsubproblems(decomp)
    for v in vars
        subproblemrepresentative(v, subproblems)
    end
    return subproblems
end
coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm(), # default BCP
        # local_art_var_cost = 99.0
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

@axis(sp_ids, 1:1);
model = BlockModel(coluna);
@variable(model, x[1:4] >= 0)
@objective(model, Min, x[1] + 7x[2] + 2x[3] + 3x[4])
@constraint(model, r1, 4x[1] + 2x[2] + 2x[3] + 3x[4] <= 30)
@constraint(model, r2, x[1] + x[2] + x[3] + 2x[4] == 15)
@constraint(model, r3[sp_ids[1]], 2x[1] + 3x[2] - 7x[3] - 6x[4] == 0)
@constraint(model, r4[sp_ids[1]], -x[2] + 2x[3] <= 0)
@constraint(model, r5[sp_ids[1]],  x[2] - 2x[3] - 2x[4] <= 0)
@constraint(model, r6[sp_ids[1]], -x[2] + 3x[3] + 2x[4] <= 2)
subproblems = column_generation(model, sp_ids, x[1], x[2], x[3], x[4])
specify!(subproblems[1], lower_multiplicity = 0, upper_multiplicity = 1)
optimize!(model);
x̄ = [value(x[1]); value(x[2]); value(x[3]); value(x[4])]
@show x̄

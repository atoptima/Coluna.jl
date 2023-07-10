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
        local_art_var_cost = 99.0
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

@axis(sp_ids, 1:1);
model = BlockModel(coluna);
@variable(model, x[1:3] >= 0)
@objective(model, Min, 8x[1] + 13x[2] - 5x[3])
@constraint(model, r1, 4x[1] + x[2] + 2x[3] == 5)
@constraint(model, r2, x[1] + x[2] == 1)
@constraint(model, r3[sp_ids[1]], -2x[1] + 3x[2] + 3x[3] <= 3)
@constraint(model, r4[sp_ids[1]], 3x[1] - x[2] + 6x[3] <= 6)
subproblems = column_generation(model, sp_ids, x[1], x[2], x[3])
specify!(subproblems[1], lower_multiplicity = 0, upper_multiplicity = 1)
optimize!(model);
value(x[1])
value(x[2])
value(x[3])

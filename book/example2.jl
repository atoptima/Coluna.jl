using BlockDecomposition, Coluna, JuMP, GLPK;
const BD = BlockDecomposition
function column_generation(model, sp_ids, vars...)
    @dantzig_wolfe_decomposition(model, decomp, sp_ids);
    subproblems = getsubproblems(decomp)
    for i in eachindex(subproblems)
        for v in vars[i]
            subproblemrepresentative(v, subproblems[i:i])
        end
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

@axis(sp_ids, 1:2);
model = BlockModel(coluna);
@variable(model, x[1:4] >= 0) # TODO (page 36)
@objective(model, Min, 3x[1] + 7x[2] + 2x[3] - x[4])
@constraint(model, r1, 2x[2] + x[3] - x[4] >= 7)
@constraint(model, r2, x[1] + x[2] + 2x[3] + 3x[4] == 12)
@constraint(model, r3[sp_ids[1]], x[1] + x[2] <= 4)
@constraint(model, r4[sp_ids[1]], 3x[1] + x[2] <= 6)
@constraint(model, r5[sp_ids[2]], x[3] + x[4] <= 5)
subproblems = column_generation(model, sp_ids, (x[1], x[2]), (x[3], x[4]))
specify!(subproblems[1], lower_multiplicity = 0, upper_multiplicity = 2)
specify!(subproblems[2], lower_multiplicity = 0, upper_multiplicity = 1)
optimize!(model);
value(x[1])
value(x[2])
value(x[3])
value(x[4])

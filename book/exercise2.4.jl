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
@variable(model, x[1:5] >= 0)
@objective(model, Min, -x[1] + 3x[2] - 6x[3] - 7x[4] + 9x[5])
@constraint(model, r1,  x[1] + 2x[2]         -  x[4] + 3x[5] == 36)
@constraint(model, r2[sp_ids[1]], -x[2] + 2x[3] <= 6)
@constraint(model, r3[sp_ids[1]], x[1] + x[2] + x[3] <= 10)
@constraint(model, r4[sp_ids[2]], 2x[4] + x[5] <= 22)
@constraint(model, r5[sp_ids[2]], x[5] <= 10)
@constraint(model, r6[sp_ids[2]], 3x[4] + x[5] <= 30)
subproblems = column_generation(model, sp_ids, (x[1], x[2], x[3]), (x[4], x[5]))
specify!(subproblems[1], lower_multiplicity = 0, upper_multiplicity = 1)
specify!(subproblems[2], lower_multiplicity = 0, upper_multiplicity = 1)
optimize!(model);
x̄ = [value(x[1]); value(x[2]); value(x[3]); value(x[4]); value(x[5])]
@show x̄

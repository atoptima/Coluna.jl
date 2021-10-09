vid(uid) = ClMP.VarId(ClMP.OriginalVar, uid, 1, 1, 1)

function dw_sp_primalsol_pool()
    pool_sols = dynamicsparse(ClMP.VarId, ClMP.VarId, Float64; fill_mode = false)
    pool_costs = Dict{ClMP.VarId, Float64}()
    
    sol1_id = vid(1)
    sol1_ids = [vid(4), vid(5), vid(8)]
    sol1_vals = [1.0, 2.0, 5.0]
    sol1_repr = dynamicsparsevec(sol1_ids, sol1_vals)
    sol1_cost = 3.0

    sol2_id = vid(2)
    sol2_ids = [vid(4), vid(7), vid(9)]
    sol2_vals = [2.0, 2.0, 3.0]
    sol2_repr = dynamicsparsevec(sol2_ids, sol2_vals)
    sol2_cost = 2.0

    addrow!(pool_sols, sol1_id, sol1_ids, sol1_vals)
    pool_costs[sol1_id] = sol1_cost

    addrow!(pool_sols, sol2_id, sol2_ids, sol2_vals)
    pool_costs[sol2_id] = sol2_cost

    a = ClMP._get_same_sol_in_pool(pool_sols, pool_costs, sol1_repr, sol1_cost)
    @test a == sol1_id
end

function max_nb_form_unit()
    coluna = optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(
            solver = Coluna.Algorithm.TreeSearchAlgorithm() # default BCP
        ),
        "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
    )
    @axis(M, 1:typemax(Int16)+1)
    model = BlockModel(coluna)
    @variable(model, x[m in M], Bin)
    @dantzig_wolfe_decomposition(model, decomposition, M)
    @test_throws ErrorException("Maximum number of formulations reached.") optimize!(model)
    return
end
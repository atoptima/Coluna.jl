vid(uid) = ClMP.VarId(ClMP.OriginalVar, uid, 1)

struct DummyFormulation <: ClMP.AbstractFormulation end

@testset "MathProg - formulation" begin
    @testset "Dantzig-wolfe solution pool" begin
        pool_sols = dynamicsparse(ClMP.VarId, ClMP.VarId, Float64; fill_mode = false)
        pool_ht = ClB.HashTable{ClMP.VarId,ClMP.VarId}()
        form = DummyFormulation()

        sol1_id = vid(1)
        sol1_ids = [vid(4), vid(5), vid(8)]
        sol1_vals = [1.0, 2.0, 5.0]
        sol1_repr = ClMP.PrimalSolution(form, sol1_ids, sol1_vals, 2.0, ClMP.FEASIBLE_SOL)

        sol2_id = vid(2)
        sol2_ids = [vid(4), vid(7), vid(9)]
        sol2_vals = [2.0, 2.0, 3.0]
        sol2_repr = ClMP.PrimalSolution(form, sol2_ids, sol2_vals, 4.0, ClMP.FEASIBLE_SOL)

        sol3_ids = [vid(4), vid(7), vid(9)]
        sol3_vals = [1.0, 2.0, 3.0]
        sol3_repr = ClMP.PrimalSolution(form, sol3_ids, sol3_vals, 5.0, ClMP.FEASIBLE_SOL)

        addrow!(pool_sols, sol1_id, sol1_ids, sol1_vals)
        ClB.savesolid!(pool_ht, sol1_id, sol1_repr)

        addrow!(pool_sols, sol2_id, sol2_ids, sol2_vals)
        ClB.savesolid!(pool_ht, sol2_id, sol2_repr)

        a = ClMP._get_same_sol_in_pool(pool_sols, pool_ht, sol1_repr)
        @test a == sol1_id

        a = ClMP._get_same_sol_in_pool(pool_sols, pool_ht, sol2_repr)
        @test a == sol2_id

        a = ClMP._get_same_sol_in_pool(pool_sols, pool_ht, sol3_repr)
        @test a === nothing
    end
end

# TODO : move this test outside unit tests.
# function max_nb_form_unit()
#     coluna = optimizer_with_attributes(
#         Coluna.Optimizer,
#         "params" => Coluna.Params(
#             solver = Coluna.Algorithm.TreeSearchAlgorithm() # default BCP
#         ),
#         "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
#     )
#     @axis(M, 1:typemax(Int16)+1)
#     model = BlockModel(coluna)
#     @variable(model, x[m in M], Bin)
#     @dantzig_wolfe_decomposition(model, decomposition, M)
#     @test_throws ErrorException("Maximum number of formulations reached.") optimize!(model)
#     return
# end
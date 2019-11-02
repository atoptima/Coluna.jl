function masteripheur_tests()
    infeasible_master_ip_heur_tests()
end

#CL.to_be_pruned(n::CL.Node) = true # issue 166

struct InfeasibleMasterIpHeur <: CL.AbstractConquerStrategy end

function CL.apply!(strategy::InfeasibleMasterIpHeur, reform, node)
    # Apply directly master ip heuristic => infeasible
    mip_rec = CL.apply!(CL.MasterIpHeuristic(), reform, node)
    return
end

function infeasible_master_ip_heur_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer,
            params = CL.Params(
                global_strategy = CL.GlobalStrategy(InfeasibleMasterIpHeur(), CL.NoBranching(), CL.DepthFirst())
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test JuMP.objective_value(problem) == Inf
    end
end
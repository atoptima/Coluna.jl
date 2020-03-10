function masteripheur_tests()
    infeasible_master_ip_heur_tests()
end

#CL.to_be_pruned(n::CL.Node) = true # issue 166

# struct InfeasibleMasterIpHeur <: ClA.AbstractConquerAlgorithm end

# function ClA.run!(strategy::InfeasibleMasterIpHeur, reform, node)
#     # Apply directly master ip heuristic => infeasible
#     mip_rec = ClA.run!(ClA.MasterIpHeuristic(), reform, node)
#     return
# end

function ClA.run!(alg::ClA.IpForm, reform::ClMP.Reformulation, input::ClA.OptimizationInput)
    return ClA.run!(alg, ClMP.getmaster(reform), input)
end

function infeasible_master_ip_heur_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        # Apply directly master ip heuristic => infeasible        
        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(
                solver = ClA.IpForm()
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test JuMP.objective_value(problem) == Inf
    end
end
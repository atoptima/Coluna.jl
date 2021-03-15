function branching_file_completion()
    function get_number_of_nodes_in_branching_tree_file(filename::String)
        filepath = string(@__DIR__ , "/", filename)
        
        existing_nodes = Set()
        
        open(filepath) do file
            for line in eachline(file)
                for pieceofdata in split(line)
                    if pieceofdata[1] == 'n'
                        push!(existing_nodes, Int(pieceofdata[2]))
                    end
                end
            end
        end
        return length(existing_nodes)
    end
    
    @testset "play gap" begin             
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(
                branchingtreefile = "playgap.dot"
            )),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 100)
        BD.objectivedualbound!(model, 0)

        JuMP.optimize!(model)

        @test MOI.get(model, MOI.NodeCount()) == get_number_of_nodes_in_branching_tree_file("playgap.dot")
        @test JuMP.objective_value(model) ≈ 75.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
        @test MOI.get(model, MOI.NumberOfVariables()) == length(x)
        @test MOI.get(model, MOI.SolverName()) == "Coluna"
    end
end
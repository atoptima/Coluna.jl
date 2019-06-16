function gen_random_small_gap_instance()
    nb_jobs = rand(7:15)
    nb_machs = rand(2:3)
    data = CLD.GeneralizedAssignment.Data(nb_machs, nb_jobs)
    for m in 1:nb_machs
        data.capacity[m] = rand(100:120)
    end
    avg_weight = sum(data.capacity)/nb_jobs
    for j in 1:nb_jobs, m in 1:nb_machs
        data.cost[j,m] = rand(1:10)
    end
    for j in 1:nb_jobs, m in 1:nb_machs
        data.weight[j,m] = Int(ceil(0.1*rand(9:25)*avg_weight))
    end
    return data
end

function preprocessing_tests()
    @testset "preprocessing random gap" begin
        for problem_idx in 1:1
            data = gen_random_small_gap_instance()
            coluna = JuMP.with_optimizer(CL.Optimizer,
                default_optimizer = with_optimizer(GLPK.Optimizer),
		params = CL.Params(; global_strategy = CL.GlobalStrategy(CL.BnPnPreprocess,
			  CL.NoBranching, CL.DepthFirst)
		)
            )
            #how to select another strategy? only preprocessing is needed here
            problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
            JuMP.optimize!(problem)

            if MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
	        #here I should disable preprocessing and check if the problem remains infeasible
                coluna = JuMP.with_optimizer(CL.Optimizer,
                            default_optimizer = with_optimizer(GLPK.Optimizer)
                         )
                problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
                JuMP.optimize!(problem)
                @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
	    else
                coluna_optimizer = problem.moi_backend.optimizer
                master = CL.getmaster(coluna_optimizer.inner.re_formulation)
                for (moi_index, var_id) in coluna_optimizer.varmap
                    var = CL.getvar(master, var_id)
                    if CL.getcurlb(var) == CL.getcurub(var)
                        var_name = CL.getname(var)
                        m = parse(Int, split(split(var_name, ",")[1], "[")[2])
                        j = parse(Int, split(split(var_name, ",")[2], "]")[1])
                        forbidden_machs = CL.getcurlb(var) == 0 ? [m] : [mach_idx for mach_idx in data.machines if mach_idx != m]
			modified_data = deepcopy(data)
                        for mach_idx in forbidden_machs
			    modified_data.weights[j,mach_idx] = modified_data.capacity[mach_idx] + 1
			end
                        #here I need the default strategy, without preprocessing
                        coluna = JuMP.with_optimizer(CL.Optimizer,
                            default_optimizer = with_optimizer(GLPK.Optimizer)
                        )
                        modified_problem, x, dec = CLD.GeneralizedAssignment.model(modified_data, coluna)
                        JuMP.optimize!(modified_problem)
                        @test MOI.get(modified_problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
	            end
		end
            end
        end
    end
    return
end

function mycallback(form::CL.Formulation)
    vars = [v for (id,v) in Iterators.filter(CL._active_explicit_, CL.getvars(form))]
    constr = [c for (id,c) in Iterators.filter(CL._active_explicit_, CL.getconstrs(form))][1]
    matrix = CL.getcoefmatrix(form)
    m = JuMP.Model(with_optimizer(GLPK.Optimizer))
    @variable(m, CL.getcurlb(vars[i]) <= x[i=1:length(vars)] <= CL.getcurub(vars[i]), Int)
    @objective(m, Min, sum(CL.getcurcost(vars[j]) * x[j] for j in 1:length(vars)))
    @constraint(m, knp, 
        sum(matrix[CL.getid(constr),CL.getid(vars[j])] * x[j]
        for j in 1:length(vars)) <= CL.getcurrhs(constr)
    )
    optimize!(m)
    result = CL.OptimizationResult{CL.MinSense}()
    result.primal_bound = CL.PrimalBound{CL.MinSense}(JuMP.objective_value(m))
    sol = CL.MembersVector{Float64}(CL.getvars(form))
    for i in 1:length(x)
        val = JuMP.value(x[i])
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            sol[CL.getid(vars[i])] = val
        end
    end
    push!(result.primal_sols, CL.PrimalSolution{CL.MinSense}(result.primal_bound, sol))
    CL.setfeasibilitystatus!(result, CL.FEASIBLE)
    CL.setterminationstatus!(result, CL.OPTIMAL)
    return result
end

build_sp_moi_optimizer() = CL.UserOptimizer(mycallback)
build_master_moi_optimizer() = CL.MoiOptimizer(with_optimizer(GLPK.Optimizer)())

function pricing_callback_tests()

    @testset "GAP with ad-hoc pricing callback " begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.with_optimizer(Coluna.Optimizer)

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        master = BD.getmaster(dec)
        subproblems = BD.getsubproblems(dec)
        
        BD.assignsolver!(master, build_master_moi_optimizer)
        BD.assignsolver!(subproblems[1], build_sp_moi_optimizer)
        BD.assignsolver!(subproblems[2], build_sp_moi_optimizer)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

end

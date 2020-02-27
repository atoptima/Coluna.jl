function mycallback(form::CL.Formulation)
    vars = [v for (id,v) in Iterators.filter(
        v -> (CL.iscuractive(form,v) && CL.getcurisexplicit(form,v)),
        CL.getvars(form)
    )]
    constr = [c for (id,c) in Iterators.filter(
        c -> (CL.iscuractive(form,c) && CL.getcurisexplicit(form,c)),
        CL.getconstrs(form))][1]
    matrix = CL.getcoefmatrix(form)
    m = JuMP.Model(GLPK.Optimizer)
    @variable(m, CL.getcurlb(form, vars[i]) <= x[i=1:length(vars)] <= CL.getcurub(form, vars[i]), Int)
    @objective(m, Min, sum(CL.getcurcost(form, vars[j]) * x[j] for j in 1:length(vars)))
    @constraint(m, knp, 
        sum(matrix[CL.getid(constr),CL.getid(vars[j])] * x[j]
        for j in 1:length(vars)) <= CL.getcurrhs(form, constr)
    )
    optimize!(m)
    result = CL.OptimizationResult{CL.MinSense}()
    result.primal_bound = CL.PrimalBound(form, JuMP.objective_value(m))
    solvarids = Vector{CL.VarId}()
    solvarvals = Vector{CL.Float64}()
    for i in 1:length(x)
        val = JuMP.value(x[i])
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            push!(solvarids, CL.getid(vars[i]))
            push!(solvarvals, val)
        end
    end
    push!(result.primal_sols, CL.PrimalSolution(form, solvarids, solvarvals, result.primal_bound))
    CL.setfeasibilitystatus!(result, CL.FEASIBLE)
    CL.setterminationstatus!(result, CL.OPTIMAL)
    return result
end

build_sp_moi_optimizer() = CL.UserOptimizer(mycallback)
build_master_moi_optimizer() = CL.MoiOptimizer(GLPK.Optimizer())

function pricing_callback_tests()

    @testset "GAP with ad-hoc pricing callback " begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "default_optimizer" => GLPK.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
        )

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

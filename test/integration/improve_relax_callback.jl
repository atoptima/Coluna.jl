# This file implements a toy bin packing model to test the before-cutgen-user algorithm.
# It solves an instance with three items where any two of them fits into a bin but the three
# together do not. Pricing is solved by inspection on the set of six possible solutions
# (three singletons and three pairs) which gives a fractional solution at the root node.
# Then a relaxation improvement function "improve_relaxation" is called to remove two of
# the pairs from the list of pricing solutions and from the master problem.
CL.@with_kw struct ImproveRelaxationAlgo <: ClA.AbstractOptimizationAlgorithm
    userfunc::Function
end

struct VarData <: BD.AbstractCustomData
    items::Vector{Int}
end

struct ToyNodeInfo <: ClA.AbstractNodeUserInfo
    value::Int
end

# TODO: Implement `notify_user_info_change` and `record_user_info`

function ClA.run!(
    algo::ImproveRelaxationAlgo, ::CL.Env, reform::ClMP.Reformulation, input::ClA.OptimizationState
)
    masterform = ClMP.getmaster(reform)
    _, spform = first(ClMP.get_dw_pricing_sps(reform))
    cbdata = ClMP.PricingCallbackData(spform)
    return algo.userfunc(masterform, cbdata)
end


function test_improve_relaxation()
    function build_toy_model(optimizer)
        toy = BlockModel(optimizer, direct_model = true)
        I = [1, 2, 3]
        @axis(B, [1])
        @variable(toy, y[b in B] >= 0, Int)
        @variable(toy, x[b in B, i in I], Bin)
        @constraint(toy, sp[i in I], sum(x[b,i] for b in B) == 1)
        @objective(toy, Min, sum(y[b] for b in B))
        @dantzig_wolfe_decomposition(toy, dec, B)
        customvars!(toy, VarData)

        return toy, x, y, dec, B
    end

    call_improve_relaxation(masterform, cbdata) = improve_relaxation(masterform, cbdata)

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => CL.Params(
            solver = ClA.TreeSearchAlgorithm(
                conqueralg = ClA.ColCutGenConquer(
                    stages = [ClA.ColumnGeneration(
                                pricing_prob_solve_alg = ClA.SolveIpForm(
                                    optimizer_id = 1
                                ))
                                ],
                    primal_heuristics = [],
                    before_cutgen_user_algorithm = ClA.BeforeCutGenUserAlgo(
                            ImproveRelaxationAlgo(
                                userfunc = call_improve_relaxation
                            ), 
                            "Improve relaxation"
                    )
                ),
                dividealg = Branching(root_user_info = ToyNodeInfo(33)),
                maxnumnodes = 1
            )
        )
    )

    model, x, y, dec, B = build_toy_model(coluna)

    relax_improved = false # TODO: use the new user infos to pass this information
    function enumerative_pricing(cbdata)
        # Get the reduced costs of the original variables
        I = [1, 2, 3]
        b = BlockDecomposition.callback_spid(cbdata, model)
        rc_y = BD.callback_reduced_cost(cbdata, y[b])
        rc_x = [BD.callback_reduced_cost(cbdata, x[b, i]) for i in I]

        # check all possible solutions
        if relax_improved
            sols = [[1], [2], [3], [2, 3]]
        else
            sols = [[1], [2], [3], [1, 2], [1, 3], [2, 3]]
        end
        best_s = Int[]
        best_rc = Inf
        for s in sols
            rc_s = rc_y + sum(rc_x[i] for i in s)
            if rc_s < best_rc
                best_rc = rc_s
                best_s = s
            end
        end

        # build the best one and submit
        solcost = best_rc 
        solvars = JuMP.VariableRef[]
        solvarvals = Float64[]
        for i in best_s
            push!(solvars, x[b, i])
            push!(solvarvals, 1.0)
        end
        push!(solvars, y[b])
        push!(solvarvals, 1.0)

        # Submit the solution
        MOI.submit(
            model, BD.PricingSolution(cbdata), solcost, solvars, solvarvals, VarData(best_s)
        )
        MOI.submit(model, BD.PricingDualBound(cbdata), solcost)
        return
    end
    subproblems = BD.getsubproblems(dec)
    BD.specify!.(
        subproblems, lower_multiplicity = 0, upper_multiplicity = 3,
        solver = enumerative_pricing
    )

    function improve_relaxation(masterform, cbdata)
        # Get the reduced costs of the original variables
        I = [1, 2, 3]
        b = BlockDecomposition.callback_spid(cbdata, model)
        rc_y = BD.callback_reduced_cost(cbdata, y[b])
        rc_x = [BD.callback_reduced_cost(cbdata, x[b, i]) for i in I]
        @test (rc_y, rc_x) == (1.0, [-0.5, -0.5, -0.5])

        # deactivate the columns of solutions [1, 2] and [1, 3] from the master
        changed = false
        for (vid, var) in ClMP.getvars(masterform)
            if ClMP.iscuractive(masterform, vid) && ClMP.getduty(vid) <= ClMP.MasterCol
                varname = ClMP.getname(masterform, var)
                @show varname, var.custom_data
                if var.custom_data.items in [[1, 2], [1, 3]]
                    ClMP.deactivate!(masterform, vid)
                    changed = true
                    relax_improved = true
                end
            end
        end

        @info "improve_relaxation $(changed ? "changed" : "did not change")"
        return changed
    end

    JuMP.optimize!(model)
    @show JuMP.objective_value(model)
    @test JuMP.termination_status(model) == MOI.OPTIMAL
    for b in B
        sets = BD.getsolutions(model, b)
        for s in sets
            @test BD.value(s) == 1.0 # value of the master column variable
            @test BD.value(s, x[b, 1]) != BD.value(s, x[b, 2]) # only x[1,1] in its set
            @test BD.value(s, x[b, 1]) != BD.value(s, x[b, 3]) # only x[1,1] in its set
            @test BD.value(s, x[b, 2]) == BD.value(s, x[b, 3]) # x[1,2] and x[1,3] in the same set
        end
    end
end

@testset "Improve relaxation callback" begin
    # TODO: make two tests: one to improve the relaxation and solve at the root node
    # and other to test the inheritance of the new storage unit (increment it in both children
    # nodes and check but check if the ones received from parent are unchanged)
    # Try to mimic MasterBranchConstrsUnit
    test_improve_relaxation()
end
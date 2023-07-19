# This file implements a toy bin packing model for Node Finalizer. It solves an instance with
# three items where any two of them fits into a bin but the three together do not. Pricing is
# solved by inspection onn the set of six possible solutions (three singletons and three pairs)
# which gives a fractional solution at the root node. Then node finalizer function
# "enumerative_finalizer" is called to find the optimal solution still at the root node and
# avoid branching (which would fail because maxnumnodes is set to 1).
# If "heuristic_finalizer" is true, then it allows branching and assumes that the solution found
# is not necessarily optimal. 
CL.@with_kw struct EnumerativeFinalizer <: ClA.AbstractOptimizationAlgorithm
    optimizer::Function
end

function ClA.run!(
    algo::EnumerativeFinalizer, env::CL.Env, reform::ClMP.Reformulation, input::ClA.OptimizationState
)
    masterform = ClMP.getmaster(reform)
    _, spform = first(ClMP.get_dw_pricing_sps(reform))
    cbdata = ClMP.PricingCallbackData(spform)
    isopt, primal_sol = algo.optimizer(masterform, cbdata)
    result = ClA.OptimizationState(
        masterform, 
        ip_primal_bound = ClA.get_ip_primal_bound(input),
        termination_status = isopt ? CL.OPTIMAL : CL.OTHER_LIMIT
    )
    if primal_sol !== nothing
        ClA.add_ip_primal_sol!(result, primal_sol)
    end
    return result
end

function test_node_finalizer(heuristic_finalizer)
    function build_toy_model(optimizer)
        toy = BlockModel(optimizer, direct_model = true)
        I = [1, 2, 3]
        @axis(B, [1])
        @variable(toy, y[b in B] >= 0, Int)
        @variable(toy, x[b in B, i in I], Bin)
        @constraint(toy, sp[i in I], sum(x[b,i] for b in B) == 1)
        @objective(toy, Min, sum(y[b] for b in B))
        @dantzig_wolfe_decomposition(toy, dec, B)

        return toy, x, y, dec, B
    end

    call_enumerative_finalizer(masterform, cbdata) = enumerative_finalizer(masterform, cbdata)

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => CL.Params(
            solver = ClA.TreeSearchAlgorithm(
                conqueralg = ClA.ColCutGenConquer(
                    colgen= ClA.ColumnGeneration(
                        stages_pricing_solver_ids = [1]
                    ),
                    primal_heuristics = [],
                    node_finalizer = ClA.NodeFinalizer(
                            EnumerativeFinalizer(optimizer = call_enumerative_finalizer), 
                            0, "Enumerative"
                    )
                ),
                maxnumnodes = heuristic_finalizer ? 15 : 1
            )
        )
    )

    model, x, y, dec, B = build_toy_model(coluna)

    function enumerative_pricing(cbdata)
        # Get the reduced costs of the original variables
        I = [1, 2, 3]
        b = BlockDecomposition.callback_spid(cbdata, model)
        rc_y = BD.callback_reduced_cost(cbdata, y[b])
        rc_x = [BD.callback_reduced_cost(cbdata, x[b, i]) for i in I]

        # check all possible solutions
        sols = [[1], [2], [3], [1, 2], [1, 3], [2, 3]]
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
            model, BD.PricingSolution(cbdata), solcost, solvars, solvarvals
        )
        MOI.submit(model, BD.PricingDualBound(cbdata), solcost)
        return
    end
    subproblems = BD.getsubproblems(dec)
    BD.specify!.(
        subproblems, lower_multiplicity = 0, upper_multiplicity = 3,
        solver = enumerative_pricing
    )

    function enumerative_finalizer(masterform, cbdata)
        # Get the reduced costs of the original variables
        I = [1, 2, 3]
        b = BlockDecomposition.callback_spid(cbdata, model)
        rc_y = BD.callback_reduced_cost(cbdata, y[b])
        rc_x = [BD.callback_reduced_cost(cbdata, x[b, i]) for i in I]
        @test (rc_y, rc_x) == (1.0, [-0.5, -0.5, -0.5])

        # Add the columns that are possibly missing for the solution [[1], [2,3]] in the master problem
        # [1]
        opt = JuMP.backend(model)
        vars = [y[b], x[b, 1]]
        varids = [CL._get_varid_of_origvar_in_form(opt.env, cbdata.form, v) for v in JuMP.index.(vars)]
        push!(varids, cbdata.form.duty_data.setup_var)
        sol = ClMP.PrimalSolution(cbdata.form, varids, [1.0, 1.0, 1.0], 1.0, CL.FEASIBLE_SOL)
        col_id = ClMP.insert_column!(masterform, sol, "MC")
        mc_1 = ClMP.getvar(masterform, col_id)

        # [2, 3]
        vars = [y[b], x[b, 2], x[b, 3]]
        varids = [CL._get_varid_of_origvar_in_form(opt.env, cbdata.form, v) for v in JuMP.index.(vars)]
        push!(varids, cbdata.form.duty_data.setup_var)
        sol = ClMP.PrimalSolution(cbdata.form, varids, [1.0, 1.0, 1.0, 1.0], 1.0, CL.FEASIBLE_SOL)
        col_id = ClMP.insert_column!(masterform, sol, "MC")
        mc_2_3 =  ClMP.getvar(masterform, col_id)

        # add the solution to the master problem
        varids = [ClMP.getid(mc_1), ClMP.getid(mc_2_3)]
        primal_sol = ClMP.PrimalSolution(masterform, varids, [1.0, 1.0], 2.0, CL.FEASIBLE_SOL)
        return !heuristic_finalizer, primal_sol
    end

    JuMP.optimize!(model)
    @show JuMP.objective_value(model)
    if heuristic_finalizer
        @test JuMP.termination_status(model) == MOI.OPTIMAL
    else
        @test JuMP.termination_status(model) == MOI.OTHER_LIMIT
    end
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

function test_node_finalizer()
    test_node_finalizer(false) # exact
    test_node_finalizer(true)  # heuristic
end
register!(e2e_extra_tests, "node_finalizer", test_node_finalizer)
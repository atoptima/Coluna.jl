CL.@with_kw struct EnumerativeOptimizer <: ClA.AbstractOptimizationAlgorithm
    optimizer::Function
end

function ClA.run!(
    algo::EnumerativeOptimizer, env::CL.Env, reform::ClMP.Reformulation, input::ClA.OptimizationInput
)::ClA.OptimizationOutput
    master = ClMP.getmaster(reform)
    _, spform = first(ClMP.get_dw_pricing_sps(reform))
    cbdata = ClMP.PricingCallbackData(spform, 1)
    algo.optimizer(cbdata)
    return ClA.OptimizationOutput(ClA.OptimizationState(
        master,
        termination_status = CL.OTHER_LIMIT
    ))
end

function conquering_opt_tests()

    function build_toy_model(optimizer)
        toy = BlockModel(optimizer)
        I = [1, 2, 3]
        @axis(B, [1])
        @variable(toy, y[b in B] >= 0, Int)
        @variable(toy, x[b in B, i in I], Bin)
        @constraint(toy, sp[i in I], sum(x[b,i] for b in B) == 1)
        @objective(toy, Min, sum(y[b] for b in B))
        @dantzig_wolfe_decomposition(toy, dec, B)

        return toy, x, y, dec
    end

    @testset "Optimization algorithms that may conquer a node" begin

        call_enumerative_optimizer(cbdata) = enumerative_optimizer(cbdata)

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
                        param_optimizers = [
                            ClA.ParameterisedOptimization(
                                EnumerativeOptimizer(optimizer = call_enumerative_optimizer), 
                                1.0, 1.0, 1, 1000, "Enumerative", true # can conquer the node
                            )
                        ]
                    ),
                    maxnumnodes = 1
                )
            )
        )

        model, x, y, dec = build_toy_model(coluna)

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
            return
        end
        subproblems = BD.getsubproblems(dec)
        BD.specify!.(
            subproblems, lower_multiplicity = 0, upper_multiplicity = 3,
            solver = enumerative_pricing
        )

        function enumerative_optimizer(cbdata)
            # Get the reduced costs of the original variables
            I = [1, 2, 3]
            b = BlockDecomposition.callback_spid(cbdata, model)
            rc_y = BD.callback_reduced_cost(cbdata, y[b])
            rc_x = [BD.callback_reduced_cost(cbdata, x[b, i]) for i in I]
            @test (rc_y, rc_x) == (1.0, [-0.5, -0.5, -0.5])

            # Add the columns that are possibly missing for the solution [[1], [2,3]] in the master problem
            opt = JuMP.backend(model).optimizer.model
            vars = [y[b], x[b, 1]]
            varids = [CL._get_orig_varid_in_form(opt, cbdata.form, v) for v in JuMP.index.(vars)]
            sol = ClMP.PrimalSolution(cbdata.form, varids, [1.0, 1.0], 1.0, CL.FEASIBLE_SOL)
            sol_1_id = ClMP.setprimalsol!(cbdata.form, sol)
            vars = [y[b], x[b, 2], x[b, 3]]
            varids = [CL._get_orig_varid_in_form(opt, cbdata.form, v) for v in JuMP.index.(vars)]
            sol = ClMP.PrimalSolution(cbdata.form, varids, [1.0, 1.0, 1.0], 1.0, CL.FEASIBLE_SOL)
            sol_2_3_id = ClMP.setprimalsol!(cbdata.form, sol)
            return
        end

        JuMP.optimize!(model)
        @show JuMP.objective_value(model)
        @test JuMP.termination_status(model) == MOI.OPTIMAL
    end

end

conquering_opt_tests()

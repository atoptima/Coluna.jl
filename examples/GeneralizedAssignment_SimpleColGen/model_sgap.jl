function model_sgap(data::DataGap)
    # params = Coluna.Params(use_restricted_master_heur = false,
    #                        apply_preprocessing = false,
    #                        #search_strategy = Coluna.DepthFirst,
    #                        force_copy_names = true)

    gap = BlockModel(with_optimizer(Coluna.Optimizer,# #params = params,
                               #master_factory = with_optimizer(Gurobi.Optimizer),
                               #pricing_factory = with_optimizer(Gurobi.Optimizer)
                               #master_factory = with_optimizer(CPLEX.Optimizer),
                               #pricing_factory = with_optimizer(CPLEX.Optimizer))
                               master_factory = with_optimizer(GLPK.Optimizer),
                               pricing_factory = with_optimizer(GLPK.Optimizer)),
                bridge_constraints=false
                )

    @axis(M, data.machines)

    @variable(gap, x[m in M, j in data.jobs], Bin)

    @constraint(gap, cov[j in data.jobs],
            sum(x[m,j] for m in M) >= 1)

    @constraint(gap, knp[m in M],
            sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= data.capacity[m])

    @objective(gap, Min,
            sum(data.cost[j,m]*x[m,j] for m in M, j in data.jobs))

    @dantzig_wolfe_decomposition(gap, dec, M)

    # setting Dantzig Wolfe composition: one subproblem per machine
    # function gap_decomp_func(name, key)
    #     if name in [:knp, :x]
    #         return key[1]
    #     else
    #         return 0
    #     end
    # end
    # Coluna.set_dantzig_wolfe_decompostion(gap, gap_decomp_func)

    # setting pricing cardinality bounds
    # card_bounds_dict = Dict(m => (0,1) for m in data.machines)
    # Coluna.set_dantzig_wolfe_cardinality_bounds(gap, card_bounds_dict)

    return (gap, x)
end

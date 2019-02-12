function model_sgap(data::DataGap)
    params = Coluna.Params(use_restricted_master_heur = true)

    gap = Model(with_optimizer(Coluna.ColunaModelOptimizer, params = params,
                               master_factory = with_optimizer(CPLEX.Optimizer),
                               pricing_factory = with_optimizer(CPLEX.Optimizer)),
                               # master_factory = with_optimizer(GLPK.Optimizer),
                               # pricing_factory = with_optimizer(GLPK.Optimizer)),
                bridge_constraints=false)

    @variable(gap, x[m in data.machines, j in data.jobs], Bin)

    @constraint(gap, cov[j in data.jobs],
            sum(x[m,j] for m in data.machines) >= 1)

    @constraint(gap, knp[m in data.machines],
            sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= data.capacity[m])

    @objective(gap, Min,
            sum(data.cost[j,m]*x[m,j] for m in data.machines, j in data.jobs))

    # setting Dantzig Wolfe composition: one subproblem per machine
    function gap_decomp_func(name, key)
        if name in [:knp, :x]
            return key[1]
        else
            return 0
        end
    end
    Coluna.set_dantzig_wolfe_decompostion(gap, gap_decomp_func)

    # setting pricing cardinality bounds
    card_bounds_dict = Dict(m => (0,1) for m in data.machines)
    Coluna.set_dantzig_wolfe_cardinality_bounds(gap, card_bounds_dict)

    return (gap, x)
end

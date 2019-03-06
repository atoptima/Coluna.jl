function model_sgap(data::DataGap)
    params = Coluna.Params(use_restricted_master_heur = false,
                           apply_preprocessing = false,
                           search_strategy = Coluna.DepthFirst,
                           force_copy_names = true)

    gap = Model(with_optimizer(Coluna.Optimizer, params = params,
                               # master_factory = with_optimizer(Gurobi.Optimizer),
                               # pricing_factory = with_optimizer(Gurobi.Optimizer)),
                               # master_factory = with_optimizer(CPLEX.Optimizer),
                               # pricing_factory = with_optimizer(CPLEX.Optimizer)),
                               master_factory = with_optimizer(GLPK.Optimizer),
                               pricing_factory = with_optimizer(GLPK.Optimizer)),
                bridge_constraints=false)

    Coluna.@axis(M, 1:length(data.machines))

    @variable(gap, x[m in M, j in data.jobs], Bin)

    @constraint(gap, cov[j in data.jobs],
            sum(x[m,j] for m in M) >= 1)

    @constraint(gap, knp[m in M],
            sum(data.weight[j,m] * x[m,j] for j in data.jobs) <= data.capacity[m])

    @objective(gap, Min,
            sum(data.cost[j,m] * x[m,j] for m in M, j in data.jobs))

    Coluna.@dantzig_wolfe_decomposition(gap, dwd, M)

    exit()

    return (gap, x)
end

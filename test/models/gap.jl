"Try presence of pure master variables & a master constraint <="
function gap_with_penalties(data)
    gap = BlockModel(with_optimizer(Coluna.Optimizer,# #params = params,
       master_factory = with_optimizer(GLPK.Optimizer),
      pricing_factory = with_optimizer(GLPK.Optimizer)),
       bridge_constraints=false
    )

    #gap = Model(with_optimizer(GLPK.Optimizer))

    penalties = Float64[sum(data.cost[j,m] for m in data.machines) * 0.7 for j in data.jobs]
    penalties ./= length(data.machines)
    
    capacities = Int[ceil(data.capacity[m] * 0.9) for m in data.machines]

    max_nb_jobs_not_covered = ceil(0.12 * length(data.jobs))

    @axis(M, data.machines)

    @variable(gap, x[m in M, j in data.jobs], Bin)
    @variable(gap, y[j in data.jobs], Bin) #equals one if job not assigned 

    @constraint(gap, cov[j in data.jobs], sum(x[m,j] for m in M) + y[j] >= 1)
    @constraint(gap, limit_pen, sum(y[j] for j in data.jobs) <= max_nb_jobs_not_covered)

    @constraint(gap, knp[m in M],
        sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= capacities[m])

    @objective(gap, Min, 
        sum(data.cost[j,m]*x[m,j] for m in M, j in data.jobs) + 
        sum(penalties[j]*y[j] for j in data.jobs))

    @dantzig_wolfe_decomposition(gap, dec, M)

    return gap
end

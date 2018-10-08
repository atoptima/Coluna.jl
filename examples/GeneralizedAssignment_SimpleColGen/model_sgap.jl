
function model_sgap(data::DataGap)
    gap = Model(with_optimizer(Coluna.ColunaModelOptimizer),
                bridge_constraints=false)

    @variable(gap, x[m in data.machines, j in data.jobs], Bin)

    @constraint(gap, cov[j in data.jobs],
            sum(x[m,j] for m in data.machines) >= 1)

    @constraint(gap, knp[m in data.machines],
            sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= data.capacity[m])

    @objective(gap, Min,
            sum(data.cost[j,m]*x[m,j] for m in data.machines, j in data.jobs))

    # setting constraint annotations for the decomposition
    for j in data.jobs
        set(gap, Coluna.ConstraintDantzigWolfeAnnotation(), cov[j], 0)
    end
    for m in data.machines
        set(gap, Coluna.ConstraintDantzigWolfeAnnotation(), knp[m], m)
    end

    # setting variable annotations for the decomposition
    for m in data.machines, j in data.jobs
        set(gap, Coluna.VariableDantzigWolfeAnnotation(), x[m,j], m)
    end

    # setting pricing cardinality bounds
    card_bounds_dict = Dict(m => (0,1) for m in data.machines)
    set(gap, Coluna.DantzigWolfePricingCardinalityBounds(), card_bounds_dict)

    return (gap, x)
end

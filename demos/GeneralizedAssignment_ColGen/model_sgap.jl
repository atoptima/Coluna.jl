function model_sgap(data::DataGap, solvertype)
    gap = Model(with_optimizer(solvertype), bridge_constraints=false)

    @variable(gap, 0 <= artificial <= 1)   
                        
    @variable(gap, x[m in data.machines, j in data.jobs], Bin)

    @constraint(gap, cov[j in data.jobs],
            sum(x[m,j] for m in data.machines) + artificial >= 1)

    @constraint(gap, knp[m in data.machines],
            sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= data.capacity[m])

    @objective(gap, Min,
            1_000_000_000 * artificial +
            sum(data.cost[j,m]*x[m,j] for m in data.machines, j in data.jobs))
            
    # Annotating constraints for the decomposition
    for j in data.jobs
        MOI.set(gap.moi_backend, Coluna.ConstraintDantzigWolfeAnnotation(), 
                cov[j].index, 0)
    end
    for m in data.machines
        MOI.set(gap.moi_backend, Coluna.ConstraintDantzigWolfeAnnotation(), 
                knp[m].index, m)        
    end
    
    # Annotating variables for the decomposition
    for m in data.machines
        for j in data.jobs
            MOI.set(gap.moi_backend, Coluna.VariableDantzigWolfeAnnotation(), 
                    x[m,j].index, m)
        end
    end
    MOI.set(gap.moi_backend, Coluna.VariableDantzigWolfeAnnotation(), 
            artificial.index, 0)

    # declaring pricing cardinality bounds
    card_bounds_dict = Dict{Int, Tuple{Int, Int}}()
    for m in data.machines
        card_bounds_dict[m] = (0, 1)
    end
    MOI.set(gap.moi_backend, Coluna.DantzigWolfePricingCardinalityBounds(),
            card_bounds_dict)

    return (gap, x)
end
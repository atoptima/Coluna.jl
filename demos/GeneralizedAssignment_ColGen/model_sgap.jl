function model_sgap(data::DataGap, solvertype)
    gap = Model(with_optimizer(solvertype), bridge_constraints=false)
    # gap = Model(solver = solver)

    # START of block to be automated
    @variable(gap, 0 <= artificial <= 1)
    
    @variable(gap, 1 <= convexity_count[m in data.machines] <= 1)
    
    @constraint(gap, convexity_lb[m in data.machines], convexity_count[m] >= 0)
    
    @constraint(gap, convexity_ub[m in data.machines], convexity_count[m] <= 1)
    # END of block to be automated 
                        
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
                convexity_lb[m].index, 0)
        MOI.set(gap.moi_backend, Coluna.ConstraintDantzigWolfeAnnotation(), 
                convexity_ub[m].index, 0)
        MOI.set(gap.moi_backend, Coluna.ConstraintDantzigWolfeAnnotation(), 
                knp[m].index, m)        
    end
    
    # Annotating variables for the decomposition
    for m in data.machines
        MOI.set(gap.moi_backend, Coluna.VariableDantzigWolfeAnnotation(), 
                convexity_count[m].index, m)
        for j in data.jobs
            MOI.set(gap.moi_backend, Coluna.VariableDantzigWolfeAnnotation(), 
                    x[m,j].index, m)
        end
    end
    MOI.set(gap.moi_backend, Coluna.VariableDantzigWolfeAnnotation(), 
            artificial.index, 0)

    # Function describing the Dantzig-Wolfe decomposition
    # function f(cstrname, cstrmid)::Tuple{Symbol, Tuple}
    #   if cstrname == :cov
    #     return (:DW_MASTER, (0,))
    #   else
    #     return (:DW_SP, cstrmid)
    #   end
    # end
    # add_Dantzig_Wolfe_decomposition(gap, f)
    return (gap, x)
end

struct PreprocessNode <: AbstractAlgorithm end

mutable struct PreprocessNodeData
    #incluir solucao parcial fixada
    reformulation::Reformulation # should handle reformulation & formulation
end

struct PreprocessNodeRecord <: AbstractAlgorithmRecord
end

function prepare!(::Type{PreprocessNode}, form, node, strategy_rec, params)
    @logmsg LogLevel(0) "Prepare preprocess node"
    return
end

function run!(::Type{PreprocessNode}, formulation, node, strategy_rec, parameters)
    @logmsg LogLevel(0) "Run preprocess node"

    master = getmaster(formulation)
    master_coef_matrix = getcoefmatrix(master)
    for (constr_id, constr) in filter(_active_explicit_, getconstrs(master))
        if getduty(constr) == MasterConvexityConstr
	    continue
	end
        @show constr
        for (var_id, var_coef) in master_coef_matrix[constr_id,:]
	   var = getvar(master, var_id)
           if _rep_of_orig_var_(var)
               @show var
	   end
	end
        println("")
    end

    for sp_prob in formulation.dw_pricing_subprs 
        sp_coef_matrix = getcoefmatrix(sp_prob)
        for (constr_id, constr) in filter(_active_explicit_, getconstrs(sp_prob))
            @show constr
            for (var_id, var_coef) in sp_coef_matrix[constr_id,:]
	        var = getvar(sp_prob, var_id)
                @show var
	    end
            println("")
	end
    end

    # Record
    record = PreprocessNodeRecord() 
    return record
end

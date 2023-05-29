struct Pool
    solutions::DynamicSparseArrays.DynamicSparseMatrix{VarId,VarId,Float64}
    solutions_hash::ColunaBase.HashTable{VarId,VarId}
    costs::Dict{VarId,Float64}
    custom_data::Dict{VarId,BD.AbstractCustomData}
end

function Pool()
    return Pool(
        DynamicSparseArrays.dynamicsparse(VarId, VarId, Float64; fill_mode = false),
        ColunaBase.HashTable{VarId, VarId}(),
        Dict{VarId, Float64}(),
        Dict{VarId, BD.AbstractCustomData}()
    )
end

# Returns nothing if there is no identical solutions in pool; the id of the
# identical solution otherwise.
function _get_same_sol_in_pool(solutions, hashtable, sol)
    sols_with_same_members = ColunaBase.getsolids(hashtable, sol)
    for existing_sol_id in sols_with_same_members
        existing_sol = @view solutions[existing_sol_id,:]
        if existing_sol == sol
            return existing_sol_id
        end
    end
    return nothing
end

# We only keep variables that have certain duty in the representation of the 
# solution stored in the pool. The second argument allows us to dispatch because
# filter may change depending on the duty of the formulation.
function _sol_repr_for_pool(primal_sol::PrimalSolution)
    var_ids = VarId[]
    vals = Float64[]
    for (var_id, val) in primal_sol
        if getduty(var_id) <= DwSpSetupVar || getduty(var_id) <= DwSpPricingVar
            push!(var_ids, var_id)
            push!(vals, val)
        end
    end
    return var_ids, vals
end

"""
    same_custom_data(custom_data1, custom_data2) -> Bool

Returns `true`if the custom data are the same, false otherwise.
"""
same_custom_data(custom_data1, custom_data2) = custom_data1 == custom_data2

function get_from_pool(pool::Pool, solution)
    existing_sol_id = _get_same_sol_in_pool(pool.solutions, pool.solutions_hash, solution)
    if isnothing(existing_sol_id)
        return nothing
    end
    
    # When there are non-robust cuts, Coluna has not enough information to identify that two
    # columns are identical. The columns may be mapped into the same original variables but
    # be internally different, meaning that the coefficients of non-robust cuts to be added
    # in the future may differ. This is why we need to check custom data.
    custom_data1 = get(pool.custom_data, existing_sol_id, nothing)
    custom_data2 = solution.custom_data
    if same_custom_data(custom_data1, custom_data2)
        return existing_sol_id
    end
    return nothing
end

function push_in_pool!(pool::Pool, solution, sol_id, cost)
    var_ids, vals = _sol_repr_for_pool(solution)
    DynamicSparseArrays.addrow!(pool.solutions, sol_id, var_ids, vals)
    pool.costs[sol_id] = cost
    if !isnothing(solution.custom_data)
        pool.custom_data[sol_id] = solution.custom_data
    end
    ColunaBase.savesolid!(pool.solutions_hash, sol_id, solution)
    return true
end



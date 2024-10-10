abstract type AbstractPool end

############################################################################################
# Primal Solution Pool
############################################################################################

struct Pool <: AbstractPool
    solutions::DynamicSparseArrays.DynamicSparseMatrix{VarId, VarId, Float64}
    solutions_hash::ColunaBase.HashTable{VarId, VarId}
    costs::Dict{VarId, Float64}
    custom_data::Dict{VarId, BD.AbstractCustomVarData}
end

function Pool()
    return Pool(
        DynamicSparseArrays.dynamicsparse(VarId, VarId, Float64; fill_mode = false),
        ColunaBase.HashTable{VarId, VarId}(),
        Dict{VarId, Float64}(),
        Dict{VarId, BD.AbstractCustomVarData}(),
    )
end

# Returns nothing if there is no identical solutions in pool; the id of the
# identical solution otherwise.
function _get_same_sol_in_pool(solutions, hashtable, sol)
    sols_with_same_members = ColunaBase.getsolids(hashtable, sol)
    for existing_sol_id in sols_with_same_members
        existing_sol = @view solutions[existing_sol_id, :]
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
        if getduty(var_id) <= DwSpSetupVar || getduty(var_id) <= DwSpPricingVar ||
           getduty(var_id) <= MasterRepPricingVar || getduty(var_id) <= MasterRepPricingSetupVar
            push!(var_ids, var_id)
            push!(vals, val)
        end
    end
    return var_ids, vals
end

_same_active_bounds(pool::Pool, existing_sol_id, solution::PrimalSolution) = true

"""
    same_custom_data(custom_data1, custom_data2) -> Bool

Returns `true`if the custom data are the same, false otherwise.
"""
same_custom_data(custom_data1, custom_data2) = custom_data1 == custom_data2

function get_from_pool(pool::AbstractPool, solution)
    existing_sol_id = _get_same_sol_in_pool(pool.solutions, pool.solutions_hash, solution)
    if isnothing(existing_sol_id)
        return nothing
    end

    # If it's a pool of dual solution, we must check if the active bounds are the same.
    if !isnothing(existing_sol_id) && !_same_active_bounds(pool, existing_sol_id, solution)
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

function push_in_pool!(pool::Pool, solution::PrimalSolution, sol_id, cost)
    var_ids, vals = _sol_repr_for_pool(solution)
    @show var_ids
    DynamicSparseArrays.addrow!(pool.solutions, sol_id, var_ids, vals)
    pool.costs[sol_id] = cost
    if !isnothing(solution.custom_data)
        pool.custom_data[sol_id] = solution.custom_data
    end
    ColunaBase.savesolid!(pool.solutions_hash, sol_id, solution)
    return true
end

############################################################################################
# Dual Solution Pool
############################################################################################

struct DualSolutionPool <: AbstractPool
    solutions::DynamicSparseArrays.DynamicSparseMatrix{ConstrId, ConstrId, Float64}
    solutions_hash::ColunaBase.HashTable{ConstrId, ConstrId}
    solutions_active_bounds::Dict{ConstrId, Dict{VarId, Tuple{Float64, ActiveBound}}}
    costs::Dict{ConstrId, Float64}
    custom_data::Dict{ConstrId, BD.AbstractCustomConstrData}
end

function DualSolutionPool()
    return DualSolutionPool(
        DynamicSparseArrays.dynamicsparse(ConstrId, ConstrId, Float64; fill_mode = false),
        ColunaBase.HashTable{ConstrId, ConstrId}(),
        Dict{ConstrId, Tuple{ActiveBound, Float64}}(),
        Dict{ConstrId, Float64}(),
        Dict{ConstrId, BD.AbstractCustomConstrData}(),
    )
end

function _same_active_bounds(pool::DualSolutionPool, existing_sol_id, solution::DualSolution)
    existing_active_bounds = pool.solutions_active_bounds[existing_sol_id]

    existing_var_ids = keys(existing_active_bounds)
    var_ids = keys(get_var_redcosts(solution))

    if length(union(existing_var_ids, var_ids)) != length(var_ids)
        return false
    end

    for (varid, (val, bnd)) in get_var_redcosts(solution)
        if !isnothing(get(existing_active_bounds, varid, nothing))
            if existing_active_bounds[varid][1] != val || existing_active_bounds[varid][2] != bnd
                return false
            end
        else
            return false
        end
    end
    return true
end

function _sol_repr_for_pool(dual_sol::DualSolution)
    constr_ids = ConstrId[]
    vals = Float64[]
    for (constr_id, val) in dual_sol
        if getduty(constr_id) <= BendSpSepVar
            push!(constr_ids, constr_id)
            push!(vals, val)
        end
    end
    return constr_ids, vals
end

function push_in_pool!(pool::DualSolutionPool, solution::DualSolution, sol_id, cost)
    constr_ids, vals = _sol_repr_for_pool(solution)
    DynamicSparseArrays.addrow!(pool.solutions, sol_id, constr_ids, vals)
    pool.costs[sol_id] = cost
    pool.solutions_active_bounds[sol_id] = get_var_redcosts(solution)
    if !isnothing(solution.custom_data)
        pool.custom_data[sol_id] = solution.custom_data
    end
    ColunaBase.savesolid!(pool.solutions_hash, sol_id, solution)
    return true
end
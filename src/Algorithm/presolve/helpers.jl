"""
Temporary data structure where we store a representation of the formulation that we presolve.
"""
struct PresolveFormRepr
    nb_vars::Int
    nb_constrs::Int
    coef_matrix::SparseMatrixCSC{Float64,Int64}
    rhs::Vector{Float64} # on constraints
    sense::Vector{ConstrSense} # on constraints
    lbs::Vector{Float64} # on variables
    ubs::Vector{Float64} # on variables
end

function PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs)
    length(lbs) == length(ubs) || throw(ArgumentError("Inconsistent sizes of bounds and coef_matrix."))
    length(rhs) == length(sense) || throw(ArgumentError("Inconsistent sizes of rhs and coef_matrix."))
    nb_vars = length(lbs)
    nb_constrs = length(rhs)
    return PresolveFormRepr(
        nb_vars, nb_constrs, coef_matrix, rhs, sense, lbs, ubs
    )
end

function _act_contrib((a, l, u))
    if a > 0
        return l*a
    elseif a < 0
        return u*a
    end
    return 0.0
end

# Expensive operation because the sparse matrix is col major and this operation is row major.
function row_min_activity(form::PresolveFormRepr, row::Int)
    return mapreduce(_act_contrib, +, Iterators.zip(
        form.coef_matrix[row,:], form.lbs, form.ubs
    ), init = 0.0)
end

# Expensive operation because the sparse matrix is col major and this operation is row major.
function row_max_activity(form::PresolveFormRepr, row::Int)
    return mapreduce(_act_contrib, +, Iterators.zip(
        form.coef_matrix[row,:], form.ubs, form.lbs
    ), init = 0.0)
end

function row_max_slack(form::PresolveFormRepr, row::Int)
    min_act = row_min_activity(form, row)
    return form.rhs[row] - min_act
end

function row_min_slack(form::PresolveFormRepr, row::Int)
    max_act = row_max_activity(form, row)
    return form.rhs[row] - max_act
end

function _unbounded_row(sense::ConstrSense, rhs::Real)
    return rhs > 0 && isinf(rhs) && sense == Less || rhs < 0 && isinf(rhs) && sense == Greater
end

function _row_bounded_by_var_bounds(sense::ConstrSense, min_slack::Real, max_slack::Real, ϵ::Real)
    return sense == Less && min_slack >= -ϵ ||
           sense == Greater && max_slack <= ϵ ||
           sense == Equal && max_slack <= ϵ && min_slack >= -ϵ
end

function _infeasible_row(sense::ConstrSense, min_slack::Real, max_slack::Real, ϵ::Real)
    return (sense == Greater || sense == Equal) && min_slack > ϵ ||
           (sense == Less || sense == Equal) && max_slack < -ϵ
end

function _var_lb_from_row(sense::ConstrSense, min_slack::Real, max_slack::Real, var_coef_in_row::Real, var_lb::Real, var_ub::Real)
    if sense == Equal || sense == Greater && var_coef_in_row > 0 || sense == Less && var_coef_in_row < 0
        return (min_slack + _act_contrib((var_coef_in_row, var_ub, var_lb))) / var_coef_in_row
    end
    return -Inf
end

function _var_ub_from_row(sense::ConstrSense, min_slack::Real, max_slack::Real, var_coef_in_row::Real, var_lb::Real, var_ub::Real)
    if sense == Equal || sense == Less && var_coef_in_row > 0 || sense == Greater && var_coef_in_row < 0
        return (max_slack + _act_contrib((var_coef_in_row, var_lb, var_ub))) / var_coef_in_row
    end
    return Inf
end

function rows_to_deactivate!(form::PresolveFormRepr)
    # Compute slacks of each constraints
    rows_to_deactivate = Int[]
    min_slacks = Float64[row_min_slack(form, row) for row in 1:form.nb_constrs] # Expensive!
    max_slacks = Float64[row_max_slack(form, row) for row in 1:form.nb_constrs] # Expensive!

    for row in 1:form.nb_constrs
        sense = form.sense[row]
        rhs = form.rhs[row]
        if _infeasible_row(sense, min_slacks[row], max_slacks[row], 1e-6)
            error("Infeasible.")
        end
        if _unbounded_row(sense, rhs) || _row_bounded_by_var_bounds(sense, min_slacks[row], max_slacks[row], 1e-6)
            push!(rows_to_deactivate, row)
        end
    end
    return rows_to_deactivate
end

function bounds_tightening(form::PresolveFormRepr)
    length(ignore_rows) == form.nb_constrs || throw(ArgumentError("Inconsistent sizes of ignore_rows and nb of constraints."))

    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}()

    min_slacks = Float64[row_min_slack(form, row) for row in 1:form.nb_constrs] # Expensive!
    max_slacks = Float64[row_max_slack(form, row) for row in 1:form.nb_constrs] # Expensive!

    for col in 1:form.nb_cols
        var_lb = form.lbs[col]
        var_ub = form.ubs[col]
        tighter_lb = false
        tighter_ub = false
        for row in 1:form.nb_rows
            min_slack = min_slacks[row]
            max_slack = max_slacks[row]
            var_coef_in_row = form.coef_matrix[row, col]
            sense = form.sense[row]
    
            var_lb_from_row = _var_lb_from_row(sense, min_slack, max_slack, var_coef_in_row, var_lb, var_ub)
            if var_lb_from_row > var_lb
                var_lb = var_lb_from_row
                tighter_lb = true
            end

            var_ub_from_row = _var_ub_from_row(sense, min_slack, max_slack, var_coef_in_row, var_lb, var_ub)
            if var_ub_from_row < var_ub
                var_ub = var_ub_from_row
                tighter_ub = true
            end
        end

        if tighter_lb || tighter_ub
            push!(tightened_bounds, col => (var_lb, tighter_lb, var_ub, tighter_ub))
        end
    end
    return tightened_bounds
end

function _fix_var(lb::Real, ub::Real, ϵ::Real)
    return abs(lb - ub) <= ϵ
end

function vars_to_fix(nb_cols::Int, tightened_bound::Vector{Tuple{Float64, Bool, Float64, Bool}})
    vars_to_fix = Int[]
    for col in 1:nb_cols
        var_lb, _, var_ub, _ = tightened_bound[col]
        if _fix_var(var_lb, var_ub, 1e-6)
            push!(vars_to_fix, col)
        end
    end
    return vars_to_fix
end

function _check_if_vars_can_be_fixed(vars_to_fix::Vector{Int}, lbs::Vector{Float64}, ubs::Vector{Float64})
    for col in vars_to_fix
        lb = lbs[col]
        ub = ubs[col]
        if !_fix_var(lb, ub, 1e-6)
            throw(ArgumentError("Cannot fix variable $col."))
        end
    end
    return true
end

function PresolveFormRepr(
    form::PresolveFormRepr,
    rows_to_deactivate::Vector{Int},
    vars_to_fix::Vector{Int},
    tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}}
)
    nb_cols = form.nb_vars
    nb_rows = form.nb_constrs
    coef_matrix = form.coef_matrix
    rhs = form.rhs
    sense = form.sense
    lbs = form.lbs
    ubs = form.ubs

    col_mask = ones(Bool, nb_cols)
    col_mask[vars_to_fix] .= false
    row_mask = ones(Bool, nb_rows)
    row_mask[rows_to_deactivate] .= false

    # Deactivate rows
    new_coef_matrix = coef_matrix[row_mask, col_mask]

    new_rhs = rhs[row_mask]
    new_sense = sense[row_mask]

    # Tighten Bounds
    for (col, (lb, tighter_lb, ub, tighter_ub)) in tightened_bounds
        if tighter_lb
            lbs[col] = lb
        end
        if tighter_ub
            ubs[col] = ub
        end
    end

    # Fix variables
    # Make sure we can fix the variable.
    _check_if_vars_can_be_fixed(vars_to_fix, lbs, ubs)
    
    # Update rhs
    new_rhs = new_rhs - coef_matrix[row_mask, vars_to_fix] * lbs[vars_to_fix]
    new_lbs = lbs[col_mask]
    new_ubs = ubs[col_mask]

    return PresolveFormRepr(new_coef_matrix, new_rhs, new_sense, new_lbs, new_ubs)
end
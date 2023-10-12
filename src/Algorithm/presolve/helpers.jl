const PRECISION_DIGITS = 6 # floating point numbers have between 6 and 9 significant digits

"""
Temporary data structure where we store a representation of the formulation that we presolve.
"""
mutable struct PresolveFormRepr
    nb_vars::Int
    nb_constrs::Int
    col_major_coef_matrix::SparseMatrixCSC{Float64,Int64} # col major
    row_major_coef_matrix::SparseMatrixCSC{Float64,Int64} # row major
    rhs::Vector{Float64} # on constraints
    sense::Vector{ConstrSense} # on constraints
    lbs::Vector{Float64} # on variables
    ubs::Vector{Float64} # on variables
    partial_solution::Vector{Float64} # on variables
    lower_multiplicity::Float64
    upper_multiplicity::Float64
end

function PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, lm, um)
    length(lbs) == length(ubs) || throw(ArgumentError("Inconsistent sizes of bounds and coef_matrix."))
    length(rhs) == length(sense) || throw(ArgumentError("Inconsistent sizes of rhs and coef_matrix."))
    nb_vars = length(lbs)
    nb_constrs = length(rhs)
    @assert reduce(&, map(lb -> !isnan(lb), lbs))
    @assert reduce(&, map(ub -> !isnan(ub), ubs))
    return PresolveFormRepr(
        nb_vars, nb_constrs, coef_matrix, transpose(coef_matrix), rhs, sense, lbs, ubs, partial_solution, lm, um
    )
end

_lb_prec(lb) = floor(round(lb, sigdigits = PRECISION_DIGITS + 1), sigdigits = PRECISION_DIGITS)
_ub_prec(ub) = ceil(round(ub, sigdigits = PRECISION_DIGITS + 1), sigdigits = PRECISION_DIGITS)

function _act_contrib(a, l, u)
    if a > 0
        return l*a
    elseif a < 0
        return u*a
    end
    return 0.0
end

function row_min_activity(form::PresolveFormRepr, row::Int, except_col::Function = _ -> false)
    activity = 0.0
    A = form.row_major_coef_matrix
    cols = rowvals(A)
    vals = nonzeros(A)
    for i in nzrange(A, row)
        col = cols[i]
        val = vals[i]
        l = form.lbs[col]
        u = form.ubs[col]
        if !except_col(col)
            activity += _act_contrib(val, l, u)
        end
    end
    return activity
end

function row_max_activity(form::PresolveFormRepr, row::Int, except_col::Function = _ -> false)
    activity = 0.0
    A = form.row_major_coef_matrix
    cols = rowvals(A)
    vals = nonzeros(A)
    for i in nzrange(A, row)
        col = cols[i]
        val = vals[i]
        l = form.lbs[col]
        u = form.ubs[col]
        if !except_col(col)
            activity += _act_contrib(val, u, l)
        end
    end
    return activity
end

function row_max_slack(form::PresolveFormRepr, row::Int, except_col::Function = _ -> false)
    act = row_min_activity(form, row, except_col)
    return form.rhs[row] - act
end

function row_min_slack(form::PresolveFormRepr, row::Int, except_col::Function = _ -> false)
    act = row_max_activity(form, row, except_col)
    return form.rhs[row] - act
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

function _var_lb_from_row(sense::ConstrSense, min_slack::Real, max_slack::Real, var_coef_in_row::Real)
    if (sense == Equal || sense == Greater) && var_coef_in_row > 0
        return min_slack / var_coef_in_row
    elseif (sense == Less || sense == Equal) && var_coef_in_row < 0 
        return max_slack / var_coef_in_row
    end
    return -Inf
end

function _var_ub_from_row(sense::ConstrSense, min_slack::Real, max_slack::Real, var_coef_in_row::Real)
    if (sense == Greater || sense == Equal) && var_coef_in_row < 0
        return min_slack / var_coef_in_row
    elseif  (sense == Equal || sense == Less) && var_coef_in_row > 0
        return max_slack / var_coef_in_row
    end
    return Inf
end

function rows_to_deactivate(form::PresolveFormRepr)
    # Compute slacks of each constraints
    rows_to_deactivate = Int[]
    min_slacks = Float64[row_min_slack(form, row) for row in 1:form.nb_constrs]
    max_slacks = Float64[row_max_slack(form, row) for row in 1:form.nb_constrs]

    for row in 1:form.nb_constrs
        sense = form.sense[row]
        rhs = form.rhs[row]
        if _infeasible_row(sense, min_slacks[row], max_slacks[row], 1e-6)
            error("Infeasible row $row.")
        end
        if _unbounded_row(sense, rhs) || _row_bounded_by_var_bounds(sense, min_slacks[row], max_slacks[row], 1e-6)
            push!(rows_to_deactivate, row)
        end
    end
    return rows_to_deactivate
end

function bounds_tightening(form::PresolveFormRepr)
    #length(ignore_rows) == form.nb_constrs || throw(ArgumentError("Inconsistent sizes of ignore_rows and nb of constraints."))
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}()

    for col in 1:form.nb_vars
        var_lb = form.lbs[col]
        var_ub = form.ubs[col]
        tighter_lb = false
        tighter_ub = false
        for row in 1:form.nb_constrs
            min_slack = row_min_slack(form, row, i -> i == col)
            max_slack = row_max_slack(form, row, i -> i == col)
            var_coef_in_row = form.col_major_coef_matrix[row, col]
            sense = form.sense[row]

            var_lb_from_row = _var_lb_from_row(sense, min_slack, max_slack, var_coef_in_row)
            @assert !isnan(var_lb)
            @assert !isnan(var_lb_from_row)
            if var_lb_from_row > var_lb
                var_lb = min(var_ub, var_lb_from_row)
                tighter_lb = true
            end

            var_ub_from_row = _var_ub_from_row(sense, min_slack, max_slack, var_coef_in_row)
            @assert !isnan(var_ub)
            @assert !isnan(var_ub_from_row)
            if var_ub_from_row < var_ub
                var_ub = max(var_lb, var_ub_from_row)
                tighter_ub = true
            end
        end

        if tighter_lb || tighter_ub
            push!(tightened_bounds, col => (_lb_prec(var_lb), tighter_lb, _ub_prec(var_ub), tighter_ub))
        end
    end
    return tightened_bounds
end

function _fix_var(lb::Real, ub::Real, ϵ::Real)
    return abs(lb - ub) <= ϵ
end

function vars_to_fix(form::PresolveFormRepr, tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}})
    vars_to_fix = Dict{Int, Float64}()
    for (col, tb) in tightened_bounds
        var_lb, _, var_ub, _ = tb
        @assert !isnan(var_lb)
        @assert !isnan(var_ub)
        if _fix_var(var_lb, var_ub, 1e-6)
            vars_to_fix[col] = var_lb
        end
    end
    for col in 1:form.nb_vars
        if !haskey(tightened_bounds, col) && _fix_var(form.lbs[col], form.ubs[col], 1e-6)
            vars_to_fix[col] = form.lbs[col]
        end
    end
    return vars_to_fix
end

function _check_if_vars_can_be_fixed(vars_to_fix::Dict{Int,Float64}, lbs::Vector{Float64}, ubs::Vector{Float64})
    for (col, val) in vars_to_fix
        lb = lbs[col]
        ub = ubs[col]
        if !_fix_var(lb, ub, 1e-6) || !_fix_var(lb, val, 1e-6) || !_fix_var(val, ub, 1e-6)
            throw(ArgumentError("Cannot fix variable $col (lb = $lb, ub = $ub, val = $val)."))
        end
    end
    return true
end

function find_uninvolved_vars(col_major_coef_matrix)
    uninvolved_vars = Int[]
    vals = nonzeros(col_major_coef_matrix)
    for j in 1:size(col_major_coef_matrix, 2)
        uninvolved = true
        for i in nzrange(col_major_coef_matrix, j)
            if abs(vals[i]) > 1e-6
                uninvolved = false
                break
            end
        end
        if uninvolved
            push!(uninvolved_vars, j)
        end
    end
    return uninvolved_vars
end

function tighten_bounds_presolve_form_repr(form::PresolveFormRepr, tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}}, lm, um)
    coef_matrix = form.col_major_coef_matrix
    rhs = form.rhs
    sense = form.sense
    lbs = form.lbs
    ubs = form.ubs
    partial_sol = form.partial_solution

    # Tighten bounds
    for (col, (lb, tighter_lb, ub, tighter_ub)) in tightened_bounds
        @assert !isnan(lb)
        @assert !isnan(ub)
        if tighter_lb
            lbs[col] = lb
        end
        if tighter_ub
            ubs[col] = ub
        end
    end

    row_mask = ones(Bool, form.nb_constrs)
    col_mask = ones(Bool, form.nb_vars)

    return PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, lm, um),
        row_mask,
        col_mask
end

function partial_sol_update(form::PresolveFormRepr, lm, um)
    coef_matrix = form.col_major_coef_matrix
    rhs = form.rhs
    sense = form.sense
    lbs = form.lbs
    ubs = form.ubs

    new_partial_sol = zeros(Float64, length(form.partial_solution))
    for (i, (lb, ub)) in  enumerate(Iterators.zip(form.lbs, form.ubs))
        @assert !isnan(lb)
        @assert !isnan(ub)
        if lb > ub
            error("Infeasible.")
        end
        if lb > 0.0
            @assert !isinf(lb)
            new_partial_sol[i] += lb
        elseif ub < 0.0 && !isinf(ub)
            @assert !isinf(ub)
            new_partial_sol[i] += ub
        end
    end

    # Update rhs
    new_rhs = rhs - coef_matrix * new_partial_sol

    # Update bounds
    new_lbs = lbs - new_partial_sol
    new_ubs = ubs - new_partial_sol

    # Update partial_sol
    partial_sol = form.partial_solution + new_partial_sol

    row_mask = ones(Bool, form.nb_constrs)
    col_mask = ones(Bool, form.nb_vars)

    return PresolveFormRepr(coef_matrix, new_rhs, sense, new_lbs, new_ubs, partial_sol, lm, um),
        row_mask,
        col_mask
end

function shrink_presolve_form_repr(form::PresolveFormRepr, rows_to_deactivate::Vector{Int}, lm, um)
    nb_cols = form.nb_vars
    nb_rows = form.nb_constrs
    coef_matrix = form.col_major_coef_matrix
    rhs = form.rhs
    sense = form.sense
    lbs = form.lbs
    ubs = form.ubs
    partial_sol = form.partial_solution

    # Update partial solution
    fixed_col_mask = zeros(Bool, nb_cols)
    nb_fixed_vars = 0
    for (i, (lb, ub)) in  enumerate(Iterators.zip(form.lbs, form.ubs))
        @assert !isnan(lb)
        @assert !isnan(ub)
        if abs(ub) <= Coluna.TOL && abs(lb) <= Coluna.TOL
            fixed_col_mask[i] = true
            nb_fixed_vars += 1
        end
    end

    col_mask = .!fixed_col_mask
    nb_cols -= nb_fixed_vars
    row_mask = ones(Bool, nb_rows)
    row_mask[rows_to_deactivate] .= false

    return PresolveFormRepr(
        coef_matrix[row_mask, col_mask], 
        rhs[row_mask], 
        sense[row_mask], 
        lbs[col_mask], 
        ubs[col_mask], 
        partial_sol[col_mask], 
        lm, 
        um
    ), row_mask, col_mask
end

function PresolveFormRepr(
    presolve_form_repr::PresolveFormRepr,
    rows_to_deactivate::Vector{Int},
    tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}},
    lm,
    um;
    tighten_bounds = true,
    partial_sol = true,
    shrink = true,
)
    row_mask = ones(Bool, presolve_form_repr.nb_constrs)
    col_mask = ones(Bool, presolve_form_repr.nb_vars)
    if tighten_bounds
        presolve_form_repr, row_mask, col_mask = tighten_bounds_presolve_form_repr(
            presolve_form_repr, tightened_bounds, lm, um
        )
    end
    if partial_sol
        presolve_form_repr, row_mask, col_mask = partial_sol_update(presolve_form_repr, lm, um)
    end
    if shrink
        presolve_form_repr, row_mask, col_mask = shrink_presolve_form_repr(
            presolve_form_repr, rows_to_deactivate, lm, um
        )
    end
    return presolve_form_repr, row_mask, col_mask
end


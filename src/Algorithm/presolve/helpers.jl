"""
Temporary data structure where we store a representation of the formulation that we presolve.
"""
struct PresolveFormRepr
    coef_matrix::SparseMatrixCSC{Float64,Int64}
    rhs::Vector{Float64} # on constraints
    sense::Vector{ConstrSense} # on constraints
    lbs::Vector{Float64} # on variables
    ubs::Vector{Float64} # on variables
end

struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
end

function _act_contrib((a, l, u))
    if a > 0
        return l*a
    elseif a < 0
        return u*a
    end
    return 0.0
end

function row_min_activity(form::PresolveFormRepr, row::Int)
    return mapreduce(_act_contrib, +, Iterators.zip(
        form.coef_matrix[row,:], form.lbs, form.ubs
    ), init = 0.0)
end

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

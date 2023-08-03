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

function row_min_activity(form::PresolveFormRepr, row::Int64)
    return mapreduce(_act_contrib, +, Iterators.zip(
        form.coef_matrix[row,:], form.lbs, form.ubs
    ), init = 0.0)
end

function row_max_activity(form::PresolveFormRepr, row::Int64)
    return mapreduce(_act_contrib, +, Iterators.zip(
        form.coef_matrix[row,:], form.ubs, form.lbs
    ), init = 0.0)
end

function row_max_slack(form::PresolveFormRepr, row::Int64)
    min_act = row_min_activity(form, row)
    return form.rhs[row] - min_act
end

function row_min_slack(form::PresolveFormRepr, row::Int64)
    max_act = row_max_activity(form, row)
    return form.rhs[row] - max_act
end

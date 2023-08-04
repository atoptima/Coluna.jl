"""
TODO
"""
abstract type PresolveStep end

struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
end

"""
Remove fixed variables from a formulation and updates constraints right-hand-side in 
consequence.

See section 4.1 of Presolve Reductions in MIP by Atcherberg et al. 2016
"""
struct RemovalOfFixedVariables <: PresolveStep 
    ϵ::Float64 # feasibility tolerance
end

_fix_var(lb, ub, ϵ) = lb == ub || (lb + ϵ >= ub && ub - ϵ <= lb)

_infeasible_var(lb, ub, ϵ) = lb > ub

function _vars_to_fix(form, ϵ)
    vars_to_fix = Dict{VarId,Float64}()
    problem_infeasible = false

    for (form, (var_id, var)) in filter_vars(active_and_explicit, form)
        isfixed(form, var) && continue # We ignore variable that have been already fixed.
        lb = getcurlb(form, var)
        ub = getcurub(form, var)
        if _fix_var(lb, ub, ϵ)
            vars_to_fix[var_id] = round(lb/ϵ) * ϵ
        end
        if _infeasible_var(lb, ub, ϵ)
            problem_infeasible = true
            break
        end
    end
    return vars_to_fix, problem_infeasible
end

function treat!(form, ::RemovalOfFixedVariables)
    ϵ = 1e-6
    vars_to_fix, problem_infeasible = _vars_to_fix(form, ϵ)
    if problem_infeasible
        return false
    end
    for (var_id, value) in vars_to_fix
        fix!(form, var_id, value)
    end
    return true
end

"""
TODO
"""
@with_kw struct PresolveAlgorithm <: AlgoAPI.AbstractAlgorithm
    ϵ::Float64 = 1e-6
    steps = PresolveStep[RemovalOfFixedVariables]
end

function run!(algo::PresolveAlgorithm, ::Env, reform::Reformulation, _)
    for step in steps
        treat!(reform, step())
    end
    return
end

# TODO

# function _min_activity_calc(form, (var_id, coeff))
#     bound = if coeff < 0
#         getcurub(form, var_id)
#     elseif coeff > 0
#         getcurlb(form, var_id)
#     else
#         0.0 # unreachable line
#     end
#     return bound * coeff
# end

# function _max_activity_calc(form, (var_id, coeff))
#     bound = if coeff > 0
#         getcurlb(form, var_id)
#     elseif coeff < 0
#         getcurub(form, var_id)
#     else
#         0.0 # unreachable line
#     end
#     return bound * coeff
# end

# function _activity(form, constr_id, keep_var, var_activity_calc)
#     constr_members = @view getcoefmatrix(form)[constr_id, :]
#     return mapreduce(
#         var_activity_calc, 
#         +,
#         filter_collection(keep_var, form, constr_members);
#         init = 0.0
#     )
# end

# min_activity(
#     form, 
#     constr_id::ConstrId,
#     keep_var = active_and_explicit
# ) = _activity(form, constr_id, keep_var, _min_activity_calc)

# max_activity(
#     form, 
#     constr_id::ConstrId,
#     keep_var = active_and_explicit
# ) = _activity(form, constr_id, keep_var, _max_activity_calc)

# ############################################################################################

# struct IndividualConstraintCleanUp end

# _discard_constr(::Val{Less}, min_act, max_act, rhs, ϵ) =
#     rhs > 0 && isinf(rhs) || max_act <= rhs + ϵ

# _discard_constr(::Val{Greater}, min_act, max_act, rhs, ϵ) =
#     rhs < 0 && isinf(rhs) || min_act >= rhs - ϵ

# _discard_constr(::Val{Equal}, min_act, max_act, rhs, ϵ) =
#     min_act >= rhs - ϵ && max_act <= rhs + ϵ

# _infeasible_constr(::Val{Less}, min_act, max_act, rhs, ϵ) = min_act > rhs + ϵ
# _infeasible_constr(::Val{Greater}, min_act, max_act, rhs, ϵ) = max_act < rhs - ϵ
# _infeasible_constr(::Val{Equal}, min_act, max_act, rhs, ϵ) = 
#     min_act > rhs + ϵ || max_act < rhs - ϵ

# function _constrs_to_discard(form, ϵ)
#     constrs_to_discard = Set{ConstrId}()
#     problem_infeasible = false

#     for (constr_id, constr) in filter_constrs(
#         e -> combine(&, e, active_and_explicit, e -> duty(e) != MasterConvexityConstr),
#         form
#     )
#         sense = getcursense(form, constr)
#         min_act = min_activity(form, constr_id)
#         max_act = max_activity(form, constr_id)
#         rhs = getcurrhs(form, constr)
#         if _discard_constr(Val(sense), min_act, max_act, rhs, ϵ)
#             push!(constrs_to_discard, constr_id)
#         end
#         if _infeasible_constr(Val(sense), min_act, max_act, rhs, ϵ)
#             problem_infeasible = true
#             break
#         end
#     end
#     return constrs_to_discard, problem_infeasible
# end

# function treat!(form, ::IndividualConstraintCleanUp)
#     ϵ = 1e-6
#     constrs_to_discard, problem_infeasible = _constrs_to_discard(form, ϵ)
#     if problem_infeasible
#         return false
#     end

#     return true
# end

############################################################################################

@enum(TerminationStatus, OPTIMAL, TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, EMPTY_RESULT, NOT_YET_DETERMINED)
@enum(FeasibilityStatus, FEASIBLE, INFEASIBLE, UNKNOWN_FEASIBILITY)

function convert_status(moi_status::MOI.TerminationStatusCode)
    moi_status == MOI.OPTIMAL && return OPTIMAL
    moi_status == MOI.TIME_LIMIT && return TIME_LIMIT
    moi_status == MOI.NODE_LIMIT && return NODE_LIMIT
    moi_status == MOI.OTHER_LIMIT && return OTHER_LIMIT
    return NOT_YET_DETERMINED
end

function convert_status(coluna_status::TerminationStatus)
    coluna_status == OPTIMAL && return MOI.OPTIMAL
    coluna_status == TIME_LIMIT && return MOI.TIME_LIMIT
    coluna_status == NODE_LIMIT && return MOI.NODE_LIMIT
    coluna_status == OTHER_LIMIT && return MOI.OTHER_LIMIT
    return MOI.OTHER_LIMIT
end

### START : TO BE DELETED
#### Old Optimization Result (usefull only to return the result of the call to
### a solver through MOI). Will be removed very soon
mutable struct MoiResult{F<:AbstractFormulation,S<:Coluna.AbstractSense}
    termination_status::TerminationStatus
    feasibility_status::FeasibilityStatus
    primal_bound::PrimalBound{S}
    dual_bound::DualBound{S}
    primal_sols::Vector{PrimalSolution{F}}
    dual_sols::Vector{DualSolution{F}}
end

function MoiResult(model::M) where {M<:Coluna.Containers.AbstractModel}
    S = getobjsense(model)
    return MoiResult{M,S}(
        NOT_YET_DETERMINED, UNKNOWN_FEASIBILITY, PrimalBound(model),
        DualBound(model),
        PrimalSolution{M}[], DualSolution{M}[]
    )
end

function MoiResult(
    model::M, ts::TerminationStatus, fs::FeasibilityStatus; pb = nothing,
    db = nothing, primal_sols = nothing, dual_sols = nothing
) where {M<:Coluna.Containers.AbstractModel}
    S = getobjsense(model)
    return OptimizationResult{M,S}(
        ts, fs,
        pb === nothing ? PrimalBound(model) : pb,
        db === nothing ? DualBound(model) : db,
        primal_sols === nothing ? PrimalSolution{M}[] : primal_sols,
        dual_sols === nothing ? DualSolution{M}[] : dual_sols
    )
end

getterminationstatus(res::MoiResult) = res.termination_status
getfeasibilitystatus(res::MoiResult) = res.feasibility_status
isfeasible(res::MoiResult) = res.feasibility_status == FEASIBLE
getprimalbound(res::MoiResult) = res.primal_bound
getdualbound(res::MoiResult) = res.dual_bound
getprimalsols(res::MoiResult) = res.primal_sols
getdualsols(res::MoiResult) = res.dual_sols
nbprimalsols(res::MoiResult) = length(res.primal_sols)
nbdualsols(res::MoiResult) = length(res.dual_sols)

# For documentation : Only unsafe methods must be used to retrieve best
# solutions in the core of Coluna.
unsafe_getbestprimalsol(res::MoiResult) = res.primal_sols[1]
unsafe_getbestdualsol(res::MoiResult) = res.dual_sols[1]
getbestprimalsol(res::MoiResult) = get(res.primal_sols, 1, nothing)
getbestdualsol(res::MoiResult) = get(res.dual_sols, 1, nothing)

setprimalbound!(res::MoiResult, b::PrimalBound) = res.primal_bound = b
setdualbound!(res::MoiResult, b::DualBound) = res.dual_bound = b
setterminationstatus!(res::MoiResult, status::TerminationStatus) = res.termination_status = status
setfeasibilitystatus!(res::MoiResult, status::FeasibilityStatus) = res.feasibility_status = status
Containers.gap(res::MoiResult) = gap(getprimalbound(res), getdualbound(res))

function add_primal_sol!(res::MoiResult{M,S}, solution::PrimalSolution{M}) where {M,S}
    push!(res.primal_sols, solution)
    pb = PrimalBound{S}(getvalue(solution))
    if isbetter(pb, getprimalbound(res))
        setprimalbound!(res, pb)
    end
    sort!(res.primal_sols; by = x->valueinminsense(PrimalBound{S}(getvalue(x))))
    return
end

function add_dual_sol!(res::MoiResult{M,S}, solution::DualSolution{M}) where {M,S}
    push!(res.dual_sols, solution)
    db = DualBound{S}(getvalue(solution))
    if isbetter(db, getdualbound(res))
        setdualbound!(res, db)
    end
    #sort!(res.dual_sols; by = x->valueinminsense(DualBound{S}(getvalue(x)))))
    return
end

function determine_statuses(res::MoiResult, fully_explored::Bool)
    gap_is_zero = gap(res) <= 0.00001
    found_sols = length(getprimalsols(res)) >= 1
    # We assume that gap cannot be zero if no solution was found
    gap_is_zero && @assert found_sols
    found_sols && setfeasibilitystatus!(res, FEASIBLE)
    gap_is_zero && setterminationstatus!(res, OPTIMAL)
    if !found_sols # Implies that gap is not zero
        setterminationstatus!(res, EMPTY_RESULT)
        # Determine if we can prove that is was infeasible
        if fully_explored
            setfeasibilitystatus!(res, INFEASIBLE)
        else
            setfeasibilitystatus!(res, UNKNOWN_FEASIBILITY)
        end
    elseif !gap_is_zero
        setterminationstatus!(res, OTHER_LIMIT)
    end
    return
end

### END : TO BE DELETED

mutable struct OptimizationResult{F<:AbstractFormulation,S<:Coluna.AbstractSense}
    termination_status::TerminationStatus
    feasibility_status::FeasibilityStatus
    incumbents::ObjValues{S}
    ip_primal_sols::Union{Nothing, Vector{PrimalSolution{F}}}
    lp_primal_sols::Union{Nothing, Vector{PrimalSolution{F}}}
    lp_dual_sols::Union{Nothing, Vector{DualSolution{F}}}
end

"""
    OptimizationResult{M,S}
Structure to be returned by all Coluna `optimize!` methods.

    OptimizationResult(model)

Builds an empty OptimizationResult.
"""
function OptimizationResult(model::M) where {M<:Coluna.Containers.AbstractModel}
    S = getobjsense(model)
    return OptimizationResult{M,S}(
        NOT_YET_DETERMINED, UNKNOWN_FEASIBILITY, ObjValues(model), 
        nothing, nothing, nothing
    )
end

function OptimizationResult(
    form::F;
    feasibility_status::FeasibilityStatus = UNKNOWN_FEASIBILITY,
    termination_status::TerminationStatus = NOT_YET_DETERMINED,
    ip_primal_bound = nothing,
    ip_dual_bound = nothing,
    lp_primal_bound = nothing,
    lp_dual_bound = nothing
) where {F <: AbstractFormulation}
    incumbents = ObjValues(
        form;
        ip_primal_bound = ip_primal_bound,
        ip_dual_bound = ip_dual_bound,
        lp_primal_bound = lp_primal_bound,
        lp_dual_bound = lp_dual_bound
    )
    S = getobjsense(form)
    result = OptimizationResult{F,S}(
        termination_status, feasibility_status, incumbents,
        nothing, nothing, nothing
    )
    return result
end

# TODO delete
function OptimizationResult(
    form::F, incumbents::Incumbents
) where {F}
    return OptimizationResult(
            form, 
            feasibility_status = UNKNOWN_FEASIBILITY, 
            termination_status = NOT_YET_DETERMINED,
            ip_primal_bound = get_ip_primal_bound(incumbents),
            ip_dual_bound = get_ip_dual_bound(incumbents)
    )
end
# end TODO

function OptimizationResult(
    form::AbstractFormulation, or::OptimizationResult
)
    newor = OptimizationResult(
        form,
        feasibility_status = getfeasibilitystatus(or),
        termination_status = getterminationstatus(or),
        ip_primal_bound = get_ip_primal_bound(or),
        ip_dual_bound = get_ip_dual_bound(or),
        lp_primal_bound = get_lp_primal_bound(or),
        lp_dual_bound = get_lp_dual_bound(or)
    )
    if or.ip_primal_sols !== nothing
        newor.ip_primal_sols = copy(or.ip_primal_sols)
    end
    if or.lp_primal_sols !== nothing
        newor.lp_primal_sols = copy(or.lp_primal_sols)
    end
    if or.lp_primal_sols !== nothing
        newor.lp_dual_sols = copy(or.lp_primal_sols)
    end
    return newor
end

getterminationstatus(res::OptimizationResult) = res.termination_status
getfeasibilitystatus(res::OptimizationResult) = res.feasibility_status

setterminationstatus!(res::OptimizationResult, status::TerminationStatus) = res.termination_status = status
setfeasibilitystatus!(res::OptimizationResult, status::FeasibilityStatus) = res.feasibility_status = status

isfeasible(res::OptimizationResult) = res.feasibility_status == FEASIBLE

get_ip_primal_bound(res::OptimizationResult) = get_ip_primal_bound(res.incumbents)
get_lp_primal_bound(res::OptimizationResult) = get_lp_primal_bound(res.incumbents)
get_ip_dual_bound(res::OptimizationResult) = get_ip_dual_bound(res.incumbents)
get_lp_dual_bound(res::OptimizationResult) = get_lp_dual_bound(res.incumbents)

ip_gap(res::OptimizationResult) = ip_gap(res.incumbents)

set_ip_primal_bound!(res::OptimizationResult, val) = set_ip_primal_bound!(res.incumbents, val)
set_lp_primal_bound!(res::OptimizationResult, val) = set_lp_primal_bound!(res.incumbents, val)
set_ip_dual_bound!(res::OptimizationResult, val) = set_ip_dual_bound!(res.incumbents, val)
set_lp_dual_bound!(res::OptimizationResult, val) = set_lp_dual_bound!(res.incumbents, val)

update_ip_primal_bound!(res::OptimizationResult, val) = update_ip_primal_bound!(res.incumbents, val)
update_ip_dual_bound!(res::OptimizationResult, val) = update_ip_dual_bound!(res.incumbents, val)
update_lp_primal_bound!(res::OptimizationResult, val) = update_lp_primal_bound!(res.incumbents, val)
update_lp_dual_bound!(res::OptimizationResult, val) = update_lp_dual_bound!(res.incumbents, val)

function nb_ip_primal_sols(res::OptimizationResult)
    return res.ip_primal_sols === nothing ? 0 : length(res.ip_primal_sols)
end

function nb_lp_primal_sols(res::OptimizationResult)
    return res.lp_primal_sols === nothing ? 0 : length(res.lp_primal_sols)
end

function nb_lp_dual_sols(res::OptimizationResult)
    return res.lp_dual_sols === nothing ? 0 : length(res.lp_dual_sols)
end

function get_ip_primal_sols(res::OptimizationResult)
    return res.ip_primal_sols
end

function get_best_ip_primal_sol(res::OptimizationResult)
    nb_ip_primal_sols(res) == 0 && return nothing
    return get_ip_primal_sols(res)[1]
end

function get_lp_primal_sols(res::OptimizationResult)
    return res.lp_primal_sols
end

function get_best_lp_primal_sol(res::OptimizationResult)
    nb_lp_primal_sols(res) == 0 && return nothing
    return get_lp_primal_sols(res)[1]
end

function get_lp_dual_sols(res::OptimizationResult)
    return res.lp_dual_sols
end

function get_best_lp_dual_sol(res::OptimizationResult)
    nb_lp_dual_sols(res) == 0 && return nothing
    return get_lp_dual_sols(res)[1]
end

# TODO : create set_ip_primal_sol if length list = 1
function add_ip_primal_sol!(res::OptimizationResult{F,S}, solution::PrimalSolution{F}, force = false) where {F,S}
    if res.ip_primal_sols === nothing
        res.ip_primal_sols = PrimalSolution{F}[]
    end
    pb = PrimalBound{S}(getvalue(solution))
    inc_sol = force ? true : update_ip_primal_bound!(res.incumbents, pb)
    if inc_sol && length(res.ip_primal_sols) > 0
        res.ip_primal_sols[1] = solution
    elseif length(res.ip_primal_sols) == 0
        push!(res.ip_primal_sols, solution)
    end
    #sort!(res.ip_primal_sols; by = x -> valueinminsense(PrimalBound{S}(getvalue(x))))
    return
end

function add_lp_primal_sol!(res::OptimizationResult{F,S}, solution::PrimalSolution{F}, force = false) where {F,S}
    if res.lp_primal_sols === nothing
        res.lp_primal_sols = PrimalSolution{F}[]
    end
    pb = PrimalBound{S}(getvalue(solution))
    inc_sol = force ? true : update_lp_primal_bound!(res.incumbents, pb)
    if inc_sol && length(res.lp_primal_sols) > 0
        res.lp_primal_sols[1] = solution
    elseif length(res.lp_primal_sols) == 0
        push!(res.lp_primal_sols, solution)
    end
    #sort!(res.lp_primal_sols; by = x -> valueinminsense(PrimalBound{S}(getvalue(x))))
    return
end

function add_lp_dual_sol!(res::OptimizationResult{F,S}, solution::DualSolution{F}, force = false) where {F,S}
    if res.lp_dual_sols === nothing
        res.lp_dual_sols = DualSolution{F}[]
    end
    db = DualBound{S}(getvalue(solution))
    inc_sol = force ? true : update_lp_dual_bound!(res.incumbents, db)
    if inc_sol && length(res.lp_dual_sols) > 0
        res.lp_dual_sols[1] = solution
    elseif length(res.lp_dual_sols) == 0
        push!(res.lp_dual_sols, solution)
    end
    #sort!(res.lp_dual_sols; by = x -> valueinminsense(PrimalBound{S}(getvalue(x))))
    return
end

function Base.print(io::IO, form::AbstractFormulation, res::OptimizationResult)
    println(io, "┌ Optimization result ")
    println(io, "│ Termination status: ", res.termination_status)
    println(io, "│ Feasibility status: ", res.feasibility_status)
    println(io, "| Incumbents: ", res.incumbents)
    n = nb_ip_primal_sols(res)
    println(io, "| IP Primal solutions (",n,")")
    if n > 0
        for sol in res.ip_primal_sols
            print(io, form, sol)
        end
    end
    n = nb_lp_primal_sols(res)
    println(io, "| LP Primal solutions (",n,"):")
    if n > 0
        for sol in res.lp_primal_sols
            print(io, form, sol)
        end
    end
    n = nb_lp_dual_sols(res)
    println(io, "| LP Dual solutions (",n,"):")
    if n > 0
        for sol in res.lp_dual_sols
            print(io, form, sol)
        end
    end
    println(io, "└")
    return
end
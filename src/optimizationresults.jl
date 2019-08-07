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

"""
    OptimizationResult{S}

Structure to be returned by all Coluna `optimize!` methods.
"""
mutable struct OptimizationResult{S<:AbstractObjSense}
    termination_status::TerminationStatus
    feasibility_status::FeasibilityStatus
    primal_bound::PrimalBound{S}
    dual_bound::DualBound{S}
    primal_sols::Vector{PrimalSolution{S}}
    dual_sols::Vector{DualSolution{S}}
end

"""
    OptimizationResult{S}()

Builds an empty OptimizationResult.
"""
OptimizationResult{S}() where {S} = OptimizationResult{S}(
    NOT_YET_DETERMINED, UNKNOWN_FEASIBILITY, PrimalBound{S}(),
    DualBound{S}(), PrimalSolution{S}[], DualSolution{S}[]
)

getterminationstatus(res::OptimizationResult) = res.termination_status
getfeasibilitystatus(res::OptimizationResult) = res.feasibility_status
isfeasible(res::OptimizationResult) = res.feasibility_status == FEASIBLE
getprimalbound(res::OptimizationResult) = res.primal_bound
getdualbound(res::OptimizationResult) = res.dual_bound
getprimalsols(res::OptimizationResult) = res.primal_sols
getdualsols(res::OptimizationResult) = res.dual_sols
nbprimalsols(res::OptimizationResult) = length(res.primal_sols)
nbdualsols(res::OptimizationResult) = length(res.dual_sols)
getbestprimalsol(res::OptimizationResult) = res.primal_sols[1]
getbestdualsol(res::OptimizationResult) = res.dual_sols[1]
setprimalbound!(res::OptimizationResult, b::PrimalBound) = res.primal_bound = b
setdualbound!(res::OptimizationResult, b::DualBound) = res.dual_bound = b
setterminationstatus!(res::OptimizationResult, status::TerminationStatus) = res.termination_status = status
setfeasibilitystatus!(res::OptimizationResult, status::FeasibilityStatus) = res.feasibility_status = status
relativegap(res::OptimizationResult) = relativegap(getprimalbound(res), getdualbound(res))

function add_primal_sol!(res::OptimizationResult, solution::AbstractSolution)
    push!(res.primal_sols, solution)
    if isbetter(getbound(solution), getprimalbound(res))
        setprimalbound!(res, getbound(solution))
    end
    sort!(res.primal_sols; by = x->valueinminsense(getbound(x)), rev = true)
    return
end

function determine_statuses(res::OptimizationResult, fully_explored::Bool)
    gap_is_zero = relativegap(res) <= 0.00001
    found_sols = length(getprimalsols(res)) >= 1
    # We assume that relativegap cannot be zero if no solution was found
    gap_is_zero && @assert found_sols
    found_sols && setfeasibilitystatus!(res, FEASIBLE)
    gap_is_zero && setterminationstatus!(res, OPTIMAL)
    if !found_sols # Implies that relativegap is not zero
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

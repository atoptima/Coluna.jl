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
    OptimizationResult{M,S}

    Structure to be returned by all Coluna `optimize!` methods.
"""
# TO DO : Optimization result should include information about both IP and LP solutions
mutable struct OptimizationResult{M<:Coluna.Containers.AbstractModel,S<:Coluna.AbstractSense}
    termination_status::TerminationStatus
    feasibility_status::FeasibilityStatus
    primal_bound::PrimalBound{S}
    dual_bound::DualBound{S}
    primal_sols::Vector{PrimalSolution{M}}
    dual_sols::Vector{DualSolution{M}}
end

"""
    OptimizationResult(model)

Builds an empty OptimizationResult.
"""
function OptimizationResult(model::M) where {M<:Coluna.Containers.AbstractModel}
    S = getobjsense(model)
    return OptimizationResult{M,S}(
        NOT_YET_DETERMINED, UNKNOWN_FEASIBILITY, PrimalBound(model),
        DualBound(model), PrimalSolution{M}[], DualSolution{M}[]
    )
end

function OptimizationResult(
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

getterminationstatus(res::OptimizationResult) = res.termination_status
getfeasibilitystatus(res::OptimizationResult) = res.feasibility_status
isfeasible(res::OptimizationResult) = res.feasibility_status == FEASIBLE
getprimalbound(res::OptimizationResult) = res.primal_bound
getdualbound(res::OptimizationResult) = res.dual_bound
getprimalsols(res::OptimizationResult) = res.primal_sols
getdualsols(res::OptimizationResult) = res.dual_sols
nbprimalsols(res::OptimizationResult) = length(res.primal_sols)
nbdualsols(res::OptimizationResult) = length(res.dual_sols)

# For documentation : Only unsafe methods must be used to retrieve best
# solutions in the core of Coluna.
unsafe_getbestprimalsol(res::OptimizationResult) = res.primal_sols[1]
unsafe_getbestdualsol(res::OptimizationResult) = res.dual_sols[1]
getbestprimalsol(res::OptimizationResult) = get(res.primal_sols, 1, nothing)
getbestdualsol(res::OptimizationResult) = get(res.dual_sols, 1, nothing)

setprimalbound!(res::OptimizationResult, b::PrimalBound) = res.primal_bound = b
setdualbound!(res::OptimizationResult, b::DualBound) = res.dual_bound = b
setterminationstatus!(res::OptimizationResult, status::TerminationStatus) = res.termination_status = status
setfeasibilitystatus!(res::OptimizationResult, status::FeasibilityStatus) = res.feasibility_status = status
Containers.gap(res::OptimizationResult) = gap(getprimalbound(res), getdualbound(res))

function add_primal_sol!(res::OptimizationResult{M,S}, solution::PrimalSolution{M}) where {M,S}
    push!(res.primal_sols, solution)
    pb = PrimalBound{S}(getvalue(solution))
    if isbetter(pb, getprimalbound(res))
        setprimalbound!(res, pb)
    end
    sort!(res.primal_sols; by = x->valueinminsense(PrimalBound{S}(getvalue(x))))
    return
end

function determine_statuses(res::OptimizationResult, fully_explored::Bool)
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

function Base.print(io::IO, form::AbstractFormulation, res::OptimizationResult)
    println(io, "┌ Optimization result ")
    println(io, "│ Termination status : ", res.termination_status)
    println(io, "│ Feasibility status : ", res.feasibility_status)
    println(io, "| Primal solutions : ")
    for sol in res.primal_sols
        print(io, form, sol)
    end
    println(io, "| Dual solutions : ")
    for sol in res.dual_sols
        print(io, form, sol)
    end
    println(io, "└")
    return
end
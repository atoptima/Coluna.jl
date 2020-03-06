# ## ObjValues
# mutable struct ObjValues{S}
#     lp_primal_bound::PrimalBound{S}
#     lp_dual_bound::DualBound{S}
#     ip_primal_bound::PrimalBound{S}
#     ip_dual_bound::DualBound{S}
# end

# """
#     ObjValues(sense)

# TODO : Returns `Incumbents` for an objective function with sense `sense`.
# Given a mixed-integer program,  `Incumbents` contains the best primal solution
# to the program, the best primal solution to the linear relaxation of the 
# program, the best  dual solution to the linear relaxation of the program, 
# and the best dual bound to the program.
# """
# function ObjValues(form::AbstractFormulation)
#     Se = getobjsense(form)
#     return ObjValues{Se}(
#         PrimalBound{Se}(),
#         DualBound{Se}(),
#         PrimalBound{Se}(),
#         DualBound{Se}()
#      )
# end

# getsense(::ObjValues{S}) where {S} = S

# # # Getters solutions
# # "Return the best primal solution to the mixed-integer program."
# # get_ip_primal_sol(i::Incumbents) = i.ip_primal_sol

# # "Return the best dual solution to the linear program."
# # get_lp_dual_sol(i::Incumbents) = i.lp_dual_sol

# # "Return the best primal solution to the linear program."
# # get_lp_primal_sol(i::Incumbents) = i.lp_primal_sol

# # Getters bounds
# "Return the best primal bound of the mixed-integer program."
# get_ip_primal_bound(i::ObjValues) = i.ip_primal_bound

# "Return the best dual bound of the mixed-integer program."
# get_ip_dual_bound(i::ObjValues) = i.ip_dual_bound

# "Return the best primal bound of the linear program."
# get_lp_primal_bound(i::ObjValues) = i.lp_primal_bound # getbound(i.lp_primal_sol)

# "Return the best dual bound of the linear program."
# get_lp_dual_bound(i::ObjValues) = i.lp_dual_bound

# # Gaps
# """
# Return the gap between the best primal and dual bounds of the integer program.
# Should not be used to check convergence
# """
# ip_gap(i::ObjValues) = gap(get_ip_primal_bound(i), get_ip_dual_bound(i))

# "Return the gap between the best primal and dual bounds of the linear program."
# lp_gap(i::ObjValues) = gap(get_lp_primal_bound(i), get_lp_dual_bound(i))

# ip_ratio(i::ObjValues) = get_ip_primal_bound(i) / get_ip_dual_bound(i)

# lp_ratio(i::ObjValues) = get_lp_primal_bound(i) / get_lp_dual_bound(i)

# # Setters
# # Methods to set IP primal sol.
# # """
# # Update the best primal solution to the mixed-integer program if the new one is
# # better than the current one according to the objective sense.
# # """
# # function update_ip_primal_sol!(
# #     inc::Incumbents{S}, sol::PrimalSolution{S}
# # ) where {S}
# #     newbound = getbound(sol)
# #     if isbetter(newbound, getbound(inc.ip_primal_sol))
# #         inc.ip_primal_bound = newbound
# #         inc.ip_primal_sol = sol
# #         return true
# #     end
# #     return false
# # end
# # update_ip_primal_sol!(inc::Incumbents, ::Nothing) = false

# # Methods to set IP primal bound.
# """
# Update the primal bound of the mixed-integer program if the new one is better
# than the current one according to the objective sense.
# """
# function update_ip_primal_bound!(
#     inc::ObjValues{S}, bound::PrimalBound{S}
# ) where {S}
#     if isbetter(bound, get_ip_primal_bound(inc))
#         inc.ip_primal_bound = bound
#         return true
#     end
#     return false
# end

# "Set the current primal bound of the mixed-integer program."
# function set_ip_primal_bound!(
#     inc::ObjValues{S}, bound::PrimalBound{S}
# ) where {S}
#     inc.ip_primal_bound = bound
#     return 
# end

# # Methods to set IP dual bound.
# """
# Update the dual bound of the mixed-integer program if the new one is better than
# the current one according to the objective sense.
# """
# function update_ip_dual_bound!(
#     inc::ObjValues{S}, bound::DualBound{S}
# ) where {S}
#     if isbetter(bound, get_ip_dual_bound(inc))
#         inc.ip_dual_bound = bound
#         return true
#     end
#     return false
# end

# "Set the current dual bound of the mixed-integer program."
# function set_ip_dual_bound!(inc::ObjValues{S}, bound::DualBound{S}) where {S}
#     inc.ip_dual_bound = bound
#     return 
# end

# # Methods to set LP primal solution.
# # """
# # Update the best primal solution to the linear program if the new one is better
# # than the current one according to the objective sense.
# # """
# # function update_lp_primal_sol!(
# #     inc::Incumbents{S}, sol::PrimalSolution{S}
# # ) where {S}
# #     newbound = getbound(sol)
# #     if isbetter(newbound, getbound(inc.lp_primal_sol))
# #         inc.lp_primal_bound = newbound
# #         inc.lp_primal_sol = sol
# #         return true
# #     end
# #     return false
# # end
# # update_lp_primal_sol!(inc::Incumbents, ::Nothing) = false

# # Methods to set LP primal bound.
# """
# Update the primal bound of the linear program if the new one is better than the
# current one according to the objective sense.
# """
# function update_lp_primal_bound!(
#     inc::ObjValues{S}, bound::PrimalBound{S}
# ) where {S}
#    if isbetter(bound, get_lp_primal_bound(inc))
#         inc.lp_primal_bound = bound
#         return true
#     end
#     return false
# end

# "Set the primal bound of the linear program"
# function set_lp_primal_bound!(
#     inc::ObjValues{S}, bound::PrimalBound{S}
# ) where {S}
#     inc.lp_primal_bound = bound
#     return 
# end

# # Methods to set LP dual sol.
# """
# Update the dual bound of the linear program if the new one is better than the 
# current one according to the objective sense.
# """
# function update_lp_dual_bound!(
#     inc::ObjValues{S}, bound::DualBound{S}
# ) where {S}
#     if isbetter(bound, get_lp_dual_bound(inc))
#         inc.lp_dual_bound = bound
#         return true
#     end
#     return false
# end

# "Set the dual bound of the linear program."
# function set_lp_dual_bound!(
#     inc::ObjValues{S}, bound::DualBound{S}
# ) where {S}
#     inc.lp_dual_bound = bound
#     return 
# end

# # Methods to set LP dual bound.
# # """
# # Update the dual solution to the linear program if the new one is better than the
# # current one according to the objective sense.
# # """
# # function update_lp_dual_sol!(inc::Incumbents{S}, sol::DualSolution{S}) where {S}
# #     newbound = getbound(sol) 
# #     if isbetter(newbound , getbound(inc.lp_dual_sol))
# #         inc.lp_dual_bound = newbound 
# #         inc.lp_dual_sol = sol
# #         return true
# #     end
# #     return false
# # end
# # update_lp_dual_sol!(inc::Incumbents, ::Nothing) = false

# "Update the fields of `dest` that are worse than those of `src`."
# function update!(dest::ObjValues{S}, src::ObjValues{S}) where {S}
#     update_ip_dual_bound!(dest, get_ip_dual_bound(src))
#     update_ip_primal_bound!(dest, get_ip_primal_bound(src))
#     update_lp_dual_bound!(dest, get_lp_dual_bound(src))
#     update_lp_primal_bound!(dest, get_lp_primal_bound(src))
#     # update_ip_primal_sol!(dest, get_ip_primal_sol(src))
#     # update_lp_primal_sol!(dest, get_lp_primal_sol(src))
#     # update_lp_dual_sol!(dest, get_lp_dual_sol(src))
#     return
# end

# function Base.show(io::IO, i::ObjValues{S}) where {S}
#     println(io, "ObjValues{", S, "}:")
#     println(io, "ip_primal_bound : ", i.ip_primal_bound)
#     println(io, "ip_dual_bound : ", i.ip_dual_bound)
#     println(io, "lp_primal_bound : ", i.lp_primal_bound)
#     println(io, "lp_dual_bound : ", i.lp_dual_bound)
#     # print(io, "ip_primal_sol : ", i.ip_primal_sol)
#     # print(io, "lp_primal_sol : ", i.lp_primal_sol)
#     # print(io, "lp_dual_sol : ", i.lp_dual_sol)
# end


# ## Solutions

# # Constructors for Primal & Dual Solutions
# function PrimalBound(form::AbstractFormulation)
#     Se = getobjsense(form)
#     return Coluna.Containers.Bound{Primal,Se}()
# end

# function PrimalBound(form::AbstractFormulation, val::Float64)
#     Se = getobjsense(form)
#     return Coluna.Containers.Bound{Primal,Se}(val)
# end

# function PrimalSolution(
#     form::F, decisions::Vector{De}, vals::Vector{Va}, val::Float64
# ) where {F<:AbstractFormulation,De,Va}
#     return Coluna.Containers.Solution{F,De,Va}(form, decisions, vals, val)
# end

# function DualBound(form::AbstractFormulation)
#     Se = getobjsense(form)
#     return Coluna.Containers.Bound{Dual,Se}()
# end

# function DualBound(form::AbstractFormulation, val::Float64)
#     Se = getobjsense(form)
#     return Coluna.Containers.Bound{Dual,Se}(val)
# end

# function DualSolution(
#     form::F, decisions::Vector{De}, vals::Vector{Va}, val::Float64
# ) where {F<:AbstractFormulation,De,Va}
#     return Coluna.Containers.Solution{F,De,Va}(form, decisions, vals, val)
# end

# valueinminsense(b::PrimalBound{MinSense}) = b.value
# valueinminsense(b::DualBound{MinSense}) = b.value
# valueinminsense(b::PrimalBound{MaxSense}) = -b.value
# valueinminsense(b::DualBound{MaxSense}) = -b.value

# # TODO : check that the type of the variable is integer
# function Base.isinteger(sol::Coluna.Containers.Solution)
#     for (vc_id, val) in sol
#         !isinteger(val) && return false
#     end
#     return true
# end

# isfractional(sol::Coluna.Containers.Solution) = !Base.isinteger(sol)

# function contains(form::AbstractFormulation, sol::PrimalSolution, duty::Duty{Variable})
#     for (varid, val) in sol
#         getduty(varid) <= duty && return true
#     end
#     return false
# end

# function contains(form::AbstractFormulation, sol::DualSolution, duty::Duty{Constraint})
#     for (constrid, val) in sol
#         getduty(constrid) <= duty && return true
#     end
#     return false
# end

# function Base.print(io::IO, form::AbstractFormulation, sol::Coluna.Containers.Solution)
#     println(io, "Solution:")
#     for (id, val) in sol
#         println(io, getname(form, id), " = ", val)
#     end
#     return
# end


# ## OptimizationResult
# @enum(TerminationStatus, OPTIMAL, TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, EMPTY_RESULT, NOT_YET_DETERMINED)
# @enum(FeasibilityStatus, FEASIBLE, INFEASIBLE, UNKNOWN_FEASIBILITY)

# function convert_status(moi_status::MOI.TerminationStatusCode)
#     moi_status == MOI.OPTIMAL && return OPTIMAL
#     moi_status == MOI.TIME_LIMIT && return TIME_LIMIT
#     moi_status == MOI.NODE_LIMIT && return NODE_LIMIT
#     moi_status == MOI.OTHER_LIMIT && return OTHER_LIMIT
#     return NOT_YET_DETERMINED
# end

# function convert_status(coluna_status::TerminationStatus)
#     coluna_status == OPTIMAL && return MOI.OPTIMAL
#     coluna_status == TIME_LIMIT && return MOI.TIME_LIMIT
#     coluna_status == NODE_LIMIT && return MOI.NODE_LIMIT
#     coluna_status == OTHER_LIMIT && return MOI.OTHER_LIMIT
#     return MOI.OTHER_LIMIT
# end

# """
#     OptimizationResult{S}

#     Structure to be returned by all Coluna `optimize!` methods.
# """
# # TO DO : Optimization result should include information about both IP and LP solutions
# mutable struct OptimizationResult{S<:Coluna.Containers.AbstractSense, M}
#     termination_status::TerminationStatus
#     feasibility_status::FeasibilityStatus
#     ip_primal_sols::Union{Vector{PrimalBound{M}}, Nothing}
#     lp_primal_sols::Union{Vector{PrimalBound{M}}, Nothing}
#     lp_dual_sols::Union{Vector{PrimalBound{M}}, Nothing}
#     incumbent::ObjValues{S}
# end


# """
#     OptimizationResult{S}()

# Builds an empty OptimizationResult.
# """
# OptimizationResult{S}() where {S} = OptimizationResult{S}(
#     NOT_YET_DETERMINED, UNKNOWN_FEASIBILITY, PrimalBound{S}(),
#     DualBound{S}(), PrimalSolution{S}[], DualSolution{S}[]
# )


# getterminationstatus(res::OptimizationResult) = res.termination_status
# getfeasibilitystatus(res::OptimizationResult) = res.feasibility_status
# isfeasible(res::OptimizationResult) = res.feasibility_status == FEASIBLE
# getprimalbound(res::OptimizationResult) = res.primal_bound
# getdualbound(res::OptimizationResult) = res.dual_bound
# getprimalsols(res::OptimizationResult) = res.primal_sols
# getdualsols(res::OptimizationResult) = res.dual_sols
# nbprimalsols(res::OptimizationResult) = length(res.primal_sols)
# nbdualsols(res::OptimizationResult) = length(res.dual_sols)

# # For documentation : Only unsafe methods must be used to retrieve best
# # solutions in the core of Coluna.
# unsafe_getbestprimalsol(res::OptimizationResult) = res.primal_sols[1]
# unsafe_getbestdualsol(res::OptimizationResult) = res.dual_sols[1]
# getbestprimalsol(res::OptimizationResult) = get(res.primal_sols, 1, nothing)
# getbestdualsol(res::OptimizationResult) = get(res.dual_sols, 1, nothing)

# setprimalbound!(res::OptimizationResult, b::PrimalBound) = res.primal_bound = b
# setdualbound!(res::OptimizationResult, b::DualBound) = res.dual_bound = b
# setterminationstatus!(res::OptimizationResult, status::TerminationStatus) = res.termination_status = status
# setfeasibilitystatus!(res::OptimizationResult, status::FeasibilityStatus) = res.feasibility_status = status
# Containers.gap(res::OptimizationResult) = gap(getprimalbound(res), getdualbound(res))

# function add_primal_sol!(res::OptimizationResult, solution::Solution)
#     push!(res.primal_sols, solution)
#     if isbetter(getbound(solution), getprimalbound(res))
#         setprimalbound!(res, getbound(solution))
#     end
#     sort!(res.primal_sols; by = x->valueinminsense(getbound(x)))
#     return
# end

# function determine_statuses(res::OptimizationResult, fully_explored::Bool)
#     gap_is_zero = gap(res) <= 0.00001
#     found_sols = length(getprimalsols(res)) >= 1
#     # We assume that gap cannot be zero if no solution was found
#     gap_is_zero && @assert found_sols
#     found_sols && setfeasibilitystatus!(res, FEASIBLE)
#     gap_is_zero && setterminationstatus!(res, OPTIMAL)
#     if !found_sols # Implies that gap is not zero
#         setterminationstatus!(res, EMPTY_RESULT)
#         # Determine if we can prove that is was infeasible
#         if fully_explored
#             setfeasibilitystatus!(res, INFEASIBLE)
#         else
#             setfeasibilitystatus!(res, UNKNOWN_FEASIBILITY)
#         end
#     elseif !gap_is_zero
#         setterminationstatus!(res, OTHER_LIMIT)
#     end
#     return
# end

# function Base.print(io::IO, form::AbstractFormulation, res::OptimizationResult)
#     println(io, "┌ Optimization result ")
#     println(io, "│ Termination status : ", res.termination_status)
#     println(io, "│ Feasibility status : ", res.feasibility_status)
#     println(io, "| Primal solutions : ")
#     for sol in res.primal_sols
#         print(io, form, sol)
#     end
#     println(io, "| Dual solutions : ")
#     for sol in res.dual_sols
#         print(io, form, sol)
#     end
#     println(io, "└")
#     return
# end
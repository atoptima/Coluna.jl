mutable struct OptimizationState{F<:AbstractFormulation}
    termination_status::TerminationStatus
    incumbents::MathProg.ObjValues
    max_length_ip_primal_sols::Int
    max_length_lp_primal_sols::Int
    max_length_lp_dual_sols::Int
    insert_function_ip_primal_sols::Function
    insert_function_lp_primal_sols::Function
    insert_function_lp_dual_sols::Function
    ip_primal_sols::Vector{PrimalSolution{F}}
    lp_primal_sols::Vector{PrimalSolution{F}}
    lp_dual_sols::Vector{DualSolution{F}}
end

function bestbound!(solutions::Vector{Sol}, max_len::Int, new_sol::Sol) where {Sol<:AbstractSolution}
    push!(solutions, new_sol)
    sort!(solutions, rev = true)
    while length(solutions) > max_len
        pop!(solutions)
    end
    return
end

function set!(solutions::Vector{Sol}, ::Int, new_sol::Sol) where {Sol<:AbstractSolution}
    empty!(solutions)
    push!(solutions, new_sol)
    return
end

"""
    OptimizationState(
        form; 
        termination_status = OPTIMIZE_NOT_CALLED,
        ip_primal_bound = nothing, 
        ip_dual_bound = nothing, 
        lp_primal_bound = nothing, 
        lp_dual_bound = nothing,
        max_length_ip_primal_sols = 1, 
        max_length_lp_primal_sols = 1,
        max_length_lp_dual_sols = 1,
        insert_function_ip_primal_sols = bestbound!, 
        insert_function_lp_primal_sols = bestbound!, 
        insert_function_lp_dual_sols = bestbound!
    )

A convenient structure to maintain and return solutions and bounds of a formulation
`form` during an optimization process. The termination status is `OPTIMIZE_NOT_CALLED`
by default. You can define the initial incumbent bounds using `ip_primal_bound`,
`ip_dual_bound`, `lp_primal_bound`, and `lp_primal_bound` keyword arguments. Incumbent
bounds are set to infinite (according to formulation objective sense) by default.
You can store three types of solutions `ip_primal_sols`, `lp_primal_sols`, and `lp_dual_sols`.
These solutions are stored in three lists. Keywords `max_length_ip_primal_sols`,
`max_length_lp_primal_sols`, and `max_length_lp_dual_sols` let you define the maximum
size of the lists. Keywords `insert_function_ip_primal_sols`, `insert_function_lp_primal_sols`,
and `insert_function_lp_dual_sols` let you provide a function to define the way
you want to insert a new solution in each list. By default, lists are sorted by
best bound.

You can also create an `OptimizationState` from another one : 

    OptimizationState(
        form, source_state, copy_ip_primal_sol, copy_lp_primal_sol
    )

It copies the termination status, all the bounds of `source_state`.
If copies the best IP primal solution when `copy_ip_primal_sol` equals `true` and
the best LP primal solution when `copy_lp_primal_sol` equals `true`.
"""
function OptimizationState(
    form::F;
    termination_status::TerminationStatus = OPTIMIZE_NOT_CALLED,
    ip_primal_bound = nothing,
    ip_dual_bound = nothing,
    lp_primal_bound = nothing,
    lp_dual_bound = nothing,
    max_length_ip_primal_sols = 1,
    max_length_lp_primal_sols = 1,
    max_length_lp_dual_sols = 1,
    insert_function_ip_primal_sols = bestbound!,
    insert_function_lp_primal_sols = bestbound!,
    insert_function_lp_dual_sols = bestbound!,
    global_primal_bound_handler = nothing
) where {F <: AbstractFormulation}
    if !isnothing(global_primal_bound_handler)
        if !isnothing(ip_primal_bound)
            @warn "Value of `ip_primal_bound` will be replaced by the value of the best primal bound stored in `global_primal_bound_manager``."
        end
        ip_primal_bound = get_global_primal_bound(global_primal_bound_handler)
    end
    incumbents = MathProg.ObjValues(
        form;
        ip_primal_bound = ip_primal_bound,
        ip_dual_bound = ip_dual_bound,
        lp_primal_bound = lp_primal_bound,
        lp_dual_bound = lp_dual_bound
    )
    state = OptimizationState{F}(
        termination_status, 
        incumbents,
        max_length_ip_primal_sols,
        max_length_lp_primal_sols,
        max_length_lp_dual_sols,
        insert_function_ip_primal_sols,
        insert_function_lp_primal_sols,
        insert_function_lp_dual_sols,
        PrimalSolution{F}[], PrimalSolution{F}[], DualSolution{F}[]
    )
    return state
end

function OptimizationState(
    form::AbstractFormulation, source_state::OptimizationState, 
    copy_ip_primal_sol::Bool, copy_lp_primal_sol::Bool
)
    state = OptimizationState(
        form,
        termination_status = getterminationstatus(source_state),
        ip_primal_bound = get_ip_primal_bound(source_state),
        lp_primal_bound = PrimalBound(form),
        ip_dual_bound = get_ip_dual_bound(source_state),
        lp_dual_bound = get_lp_dual_bound(source_state)
    )
 
    best_ip_primal_sol = get_best_ip_primal_sol(source_state)

    if best_ip_primal_sol !== nothing
        set_ip_primal_sol!(state, best_ip_primal_sol)
    end

    best_lp_primal_sol = get_best_lp_primal_sol(source_state)
    if best_lp_primal_sol !== nothing
        set_lp_primal_sol!(state, best_lp_primal_sol)
    end

    return state
end

getterminationstatus(state::OptimizationState) = state.termination_status
setterminationstatus!(state::OptimizationState, status::TerminationStatus) = state.termination_status = status


"Return the best IP primal bound."
get_ip_primal_bound(state::OptimizationState) = state.incumbents.ip_primal_bound

"Return the best LP primal bound."
get_lp_primal_bound(state::OptimizationState) = state.incumbents.lp_primal_bound

"Return the best IP dual bound."
get_ip_dual_bound(state::OptimizationState) = state.incumbents.ip_dual_bound

"Return the best LP dual bound."
get_lp_dual_bound(state::OptimizationState) = state.incumbents.lp_dual_bound

"""
Update the primal bound of the mixed-integer program if the new one is better
than the current one according to the objective sense.
"""
update_ip_primal_bound!(state::OptimizationState, bound) = MathProg._update_ip_primal_bound!(state.incumbents, bound)

"""
Update the dual bound of the mixed-integer program if the new one is better than
the current one according to the objective sense.
"""
update_ip_dual_bound!(state::OptimizationState, bound) = MathProg._update_ip_dual_bound!(state.incumbents, bound)

"""
Update the primal bound of the linear program if the new one is better than the
current one according to the objective sense.
"""
update_lp_primal_bound!(state::OptimizationState, bound) = MathProg._update_lp_primal_bound!(state.incumbents, bound)

"""
Update the dual bound of the linear program if the new one is better than the 
current one according to the objective sense.
"""
update_lp_dual_bound!(state::OptimizationState, bound) = MathProg._update_lp_dual_bound!(state.incumbents, bound)

"Set the best IP primal bound."
set_ip_primal_bound!(state::OptimizationState, bound) = state.incumbents.ip_primal_bound = bound

"Set the best LP primal bound."
set_lp_primal_bound!(state::OptimizationState, bound) = state.incumbents.lp_primal_bound = bound

"Set the best IP dual bound."
set_ip_dual_bound!(state::OptimizationState, bound) = state.incumbents.ip_dual_bound = bound

"Set the best LP dual bound."
set_lp_dual_bound!(state::OptimizationState, bound) = state.incumbents.lp_dual_bound = bound

"""
Return the gap between the best primal and dual bounds of the integer program.
Should not be used to check convergence
"""
ip_gap(state::OptimizationState) = MathProg._ip_gap(state.incumbents)

"Return the gap between the best primal and dual bounds of the linear program."
lp_gap(state::OptimizationState) = MathProg._lp_gap(state.incumbents)

"""
    ip_gap_closed(optstate; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL)

Return true if the gap between the best primal and dual bounds of the integer program is closed
given optimality tolerances.
"""
ip_gap_closed(state::OptimizationState; kw...) = MathProg._ip_gap_closed(state.incumbents; kw...)

"""
    lp_gap_closed(optstate; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL)

Return true if the gap between the best primal and dual bounds of the linear program is closed 
given optimality tolerances.
"""
lp_gap_closed(state::OptimizationState; kw...) = MathProg._lp_gap_closed(state.incumbents; kw...)

"Return all IP primal solutions."
get_ip_primal_sols(state::OptimizationState) = state.ip_primal_sols


"Return the best IP primal solution if it exists; `nothing` otherwise."
function get_best_ip_primal_sol(state::OptimizationState)
    length(state.ip_primal_sols) == 0 && return nothing
    return state.ip_primal_sols[1]
end

"Return all LP primal solutions."
get_lp_primal_sols(state::OptimizationState) = state.lp_primal_sols

"Return the best LP primal solution if it exists; `nothing` otherwise."
function get_best_lp_primal_sol(state::OptimizationState)
    length(state.lp_primal_sols) == 0 && return nothing
    return state.lp_primal_sols[1]
end

"Return all LP dual solutions."
get_lp_dual_sols(state::OptimizationState) = state.lp_dual_sols

"Return the best LP dual solution if it exists; `nothing` otherwise."
function get_best_lp_dual_sol(state::OptimizationState)
    length(state.lp_dual_sols) == 0 && return nothing
    return state.lp_dual_sols[1]
end

# TODO : refactoring ?
function update!(dest_state::OptimizationState, orig_state::OptimizationState)
    setterminationstatus!(dest_state, getterminationstatus(orig_state))
    add_ip_primal_sols!(dest_state, get_ip_primal_sols(orig_state)...)
    update_ip_dual_bound!(dest_state, get_ip_dual_bound(orig_state))
    update_lp_dual_bound!(dest_state, get_lp_dual_bound(orig_state))
    set_lp_primal_bound!(dest_state, get_lp_primal_bound(orig_state))

    best_lp_primal_sol = get_best_lp_primal_sol(orig_state) 
    if !isnothing(best_lp_primal_sol)
        set_lp_primal_sol!(dest_state, best_lp_primal_sol)
    end     

    best_lp_dual_sol = get_best_lp_dual_sol(orig_state)
    if !isnothing(best_lp_dual_sol)
        set_lp_dual_sol!(dest_state, best_lp_dual_sol)
    end
    return
end

"""
    update_ip_primal_sol!(optstate, sol)

Add the solution `sol` in the solutions list of `optstate` if and only if the 
value of the solution is better than the incumbent. The solution is inserted in the list
by the method defined in `insert_function_ip_primal_sols` field of `OptimizationState`.
If the maximum length of the list is reached, the solution located at the end of the list
is removed.

Similar methods : 

    update_lp_primal_sol!(optstate, sol)
    update_lp_dual_sol!(optstate, sol)
"""
function update_ip_primal_sol!(state::OptimizationState{F}, sol::PrimalSolution{F}) where {F}
    state.max_length_ip_primal_sols == 0 && return
    b = ColunaBase.Bound(state.incumbents.min, true, getvalue(sol))
    if update_ip_primal_bound!(state, b)
        state.insert_function_ip_primal_sols(state.ip_primal_sols, state.max_length_ip_primal_sols, sol)
    end
    return
end

"""
    add_ip_primal_sol!(optstate, sol)
    add_ip_primal_sols!(optstate, sols...)

Add the solution `sol` at the end of the solution list of `opstate`, sort the solution list,
remove the worst solution if the solution list size is exceded, and update the incumbent bound if 
the solution is better.

Similar methods :

    add_lp_primal_sol!(optstate, sol)
    add_lp_dual_sol!(optstate, sol)
"""
function add_ip_primal_sol!(state::OptimizationState{F}, sol::PrimalSolution{F}) where {F}
    state.max_length_ip_primal_sols == 0 && return
    state.insert_function_ip_primal_sols(state.ip_primal_sols, state.max_length_ip_primal_sols, sol)
    pb = ColunaBase.Bound(state.incumbents.min, true, getvalue(sol))
    update_ip_primal_bound!(state, pb)
    return
end

function add_ip_primal_sols!(state::OptimizationState, sols...)
    for sol in sols
        add_ip_primal_sol!(state, sol)
    end
    return
end

"""
    set_ip_primal_sol!(optstate, sol)

Empties the list of solutions and add solution `sol` in the list.
The incumbent bound is not updated even if the value of the solution is better.

Similar methods :

    set_lp_primal_sol!(optstate, sol)
    set_lp_dual_sol!(optstate, sol)
"""
function set_ip_primal_sol!(state::OptimizationState{F}, sol::PrimalSolution{F}) where {F}
    state.max_length_ip_primal_sols == 0 && return
    set!(state.ip_primal_sols, state.max_length_ip_primal_sols, sol)
    return
end

"""
    empty_ip_primal_sols!(optstate)

Remove all IP primal solutions from `optstate`.

Similar methods :

    empty_lp_primal_sols!(optstate)
    empty_lp_dual_sols!(optstate)
"""
empty_ip_primal_sols!(state::OptimizationState) = empty!(state.ip_primal_sols)

"Similar to [`update_ip_primal_sol!`](@ref)."
function update_lp_primal_sol!(state::OptimizationState{F}, sol::PrimalSolution{F}) where {F}
    state.max_length_lp_primal_sols == 0 && return
    pb = ColunaBase.Bound(state.incumbents.min, true, getvalue(sol))
    if update_lp_primal_bound!(state, pb)
        state.insert_function_lp_primal_sols(state.lp_primal_sols, state.max_length_lp_primal_sols, sol)
    end
    return
end

"Similar to [`add_ip_primal_sol!`](@ref)."
function add_lp_primal_sol!(state::OptimizationState{F}, sol::PrimalSolution{F}) where {F}
    state.max_length_lp_primal_sols == 0 && return
    state.insert_function_lp_primal_sols(state.lp_primal_sols, state.max_length_lp_primal_sols, sol)
    pb = ColunaBase.Bound(state.incumbents.min, true, getvalue(sol))
    update_lp_primal_bound!(state, pb)
    return
end

"Similar to [`set_ip_primal_sol!`](@ref)."
function set_lp_primal_sol!(state::OptimizationState{F}, sol::PrimalSolution{F}) where {F}
    state.max_length_lp_primal_sols == 0 && return
    set!(state.lp_primal_sols, state.max_length_lp_primal_sols, sol)
    return
end

"Similar to [`empty_ip_primal_sols!`](@ref)."
empty_lp_primal_sols!(state::OptimizationState) = empty!(state.lp_primal_sols)

"Similar to [`update_ip_primal_sol!`](@ref)."
function update_lp_dual_sol!(state::OptimizationState{F}, sol::DualSolution{F}) where {F}
    state.max_length_lp_dual_sols == 0 && return
    db = ColunaBase.Bound(state.incumbents.min, false, getvalue(sol))
    if update_lp_dual_bound!(state, db)
        state.insert_function_lp_dual_sols(state.lp_dual_sols, state.max_length_lp_dual_sols, sol)
    end
    return
end

"Similar to [`add_ip_primal_sol!`](@ref)."
function add_lp_dual_sol!(state::OptimizationState{F}, sol::DualSolution{F}) where {F}
    state.max_length_lp_dual_sols == 0 && return
    state.insert_function_lp_dual_sols(state.lp_dual_sols, state.max_length_lp_dual_sols, sol)
    db = ColunaBase.Bound(state.incumbents.min, false, getvalue(sol))
    update_lp_dual_bound!(state, db)
    return
end

"Similar to [`set_ip_primal_sol!`](@ref)."
function set_lp_dual_sol!(state::OptimizationState{F}, sol::DualSolution{F}) where {F}
    state.max_length_lp_dual_sols == 0 && return
    set!(state.lp_dual_sols, state.max_length_lp_dual_sols, sol)
    return
end

"Similar to [`empty_ip_primal_sols!`](@ref)."
empty_lp_dual_sols!(state::OptimizationState) = empty!(state.lp_dual_sols)

function Base.print(io::IO, form::AbstractFormulation, optstate::OptimizationState)
    println(io, "┌ Optimization state ")
    println(io, "│ Termination status: ", optstate.termination_status)
    println(io, "| Incumbents: ", optstate.incumbents)
    n = length(optstate.ip_primal_sols)
    println(io, "| IP Primal solutions (",n,")")
    if n > 0
        for sol in optstate.ip_primal_sols
            print(io, form, sol)
        end
    end
    n = length(optstate.lp_primal_sols)
    println(io, "| LP Primal solutions (",n,"):")
    if n > 0
        for sol in optstate.lp_primal_sols
            print(io, form, sol)
        end
    end
    n = length(optstate.lp_dual_sols)
    println(io, "| LP Dual solutions (",n,"):")
    if n > 0
        for sol in optstate.lp_dual_sols
            print(io, form, sol)
        end
    end
    println(io, "└")
    return
end
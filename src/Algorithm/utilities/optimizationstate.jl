mutable struct OptimizationResult{F<:AbstractFormulation,S<:Coluna.AbstractSense}
    termination_status::TerminationStatus
    feasibility_status::FeasibilityStatus
    incumbents::ObjValues{S}
    max_length_ip_primal_sols::Int
    max_length_lp_primal_sols::Int
    max_length_lp_dual_sols::Int
    insert_function_ip_primal_sols::Function
    insert_function_lp_primal_sols::Function
    insert_function_lp_dual_sols::Function
    ip_primal_sols::Union{Nothing, Vector{PrimalSolution{F}}}
    lp_primal_sols::Union{Nothing, Vector{PrimalSolution{F}}}
    lp_dual_sols::Union{Nothing, Vector{DualSolution{F}}}
end

_sort!(sols::Vector{PrimalSolution{F}}, f::Function) where {F} = sort!(sols, by = x -> f(PrimalBound(x.model, x.value)))
_sort!(sols::Vector{DualSolution{F}}, f::Function) where {F} = sort!(sols, by = x -> f(DualBound(x.model, x.value)))

function bestbound(solutions::Vector{Sol}, max_len::Int, new_sol::Sol) where {Sol<:Coluna.Containers.Solution}
    if length(solutions) < max_len
        push!(solutions, new_sol)
    else
        solutions[end] = new_sol
    end
    _sort!(solutions, MathProg.valueinminsense)
    return
end

function pushfirst(solutions::Vector{Sol}, max_len::Int, new_sol::Sol) where {Sol<:Coluna.Containers.Solution}
    pushfirst!(solutions, new_sol)
    if length(solutions) > max_len
        pop!(solutions)
    end
    return
end

"""
    OptimizationResult{M,S}
Structure to be returned by all Coluna `optimize!` methods.

    OptimizationResult(model)

Builds an empty OptimizationResult.
"""
function OptimizationResult(
    form::F;
    feasibility_status::FeasibilityStatus = UNKNOWN_FEASIBILITY,
    termination_status::TerminationStatus = NOT_YET_DETERMINED,
    ip_primal_bound = nothing,
    ip_dual_bound = nothing,
    lp_primal_bound = nothing,
    lp_dual_bound = nothing,
    max_length_ip_primal_sols = 1,
    max_length_lp_primal_sols = 1,
    max_length_lp_dual_sols = 1,
    insert_function_ip_primal_sols = bestbound,
    insert_function_lp_primal_sols = bestbound,
    insert_function_lp_dual_sols = bestbound
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
        termination_status, 
        feasibility_status, 
        incumbents,
        max_length_ip_primal_sols,
        max_length_lp_primal_sols,
        max_length_lp_dual_sols,
        insert_function_ip_primal_sols,
        insert_function_lp_primal_sols,
        insert_function_lp_dual_sols,
        nothing, nothing, nothing
    )
    return result
end

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

update_ip_primal_bound!(res::OptimizationResult, val) = update_ip_primal_bound!(res.incumbents, val)
update_ip_dual_bound!(res::OptimizationResult, val) = update_ip_dual_bound!(res.incumbents, val)
update_lp_primal_bound!(res::OptimizationResult, val) = update_lp_primal_bound!(res.incumbents, val)
update_lp_dual_bound!(res::OptimizationResult, val) = update_lp_dual_bound!(res.incumbents, val)

set_ip_primal_bound!(res::OptimizationResult, val) = set_ip_primal_bound!(res.incumbents, val)
set_lp_primal_bound!(res::OptimizationResult, val) = set_lp_primal_bound!(res.incumbents, val)
set_ip_dual_bound!(res::OptimizationResult, val) = set_ip_dual_bound!(res.incumbents, val)
set_lp_dual_bound!(res::OptimizationResult, val) = set_lp_dual_bound!(res.incumbents, val)

ip_gap(res::OptimizationResult) = ip_gap(res.incumbents)

function nb_ip_primal_sols(res::OptimizationResult)
    return res.ip_primal_sols === nothing ? 0 : length(res.ip_primal_sols)
end

function nb_lp_primal_sols(res::OptimizationResult)
    return res.lp_primal_sols === nothing ? 0 : length(res.lp_primal_sols)
end

function nb_lp_dual_sols(res::OptimizationResult)
    return res.lp_dual_sols === nothing ? 0 : length(res.lp_dual_sols)
end

get_ip_primal_sols(res::OptimizationResult) = res.ip_primal_sols

function get_best_ip_primal_sol(res::OptimizationResult)
    nb_ip_primal_sols(res) == 0 && return nothing
    return get_ip_primal_sols(res)[1]
end

get_lp_primal_sols(res::OptimizationResult) = res.lp_primal_sols

function get_best_lp_primal_sol(res::OptimizationResult)
    nb_lp_primal_sols(res) == 0 && return nothing
    return get_lp_primal_sols(res)[1]
end

get_lp_dual_sols(res::OptimizationResult) = res.lp_dual_sols

function get_best_lp_dual_sol(res::OptimizationResult)
    nb_lp_dual_sols(res) == 0 && return nothing
    return get_lp_dual_sols(res)[1]
end

"""
    update_ip_primal_sol!(optstate, sol)

Add the solution `sol` in the solutions list of `optstate` if and only if the 
value of the solution is better than the incumbent. The solution is inserted in the list
by the method defined in `insert_function_ip_primal_sols` field of `OptimizationResult`.
If the maximum length of the list is reached, the solution located at the end of the list
is removed.
"""
function update_ip_primal_sol! end

"""
    add_ip_primal_sol!(optstate, sol)

Add the solution `sol` in the solutions list of `opstate` and update the incumbent bound if 
the solution is better.
"""
function add_ip_primal_sol! end

"""
    set_ip_primal_sol!(optstate, sol)

Add the solution `sol` in the solutions list of `optstate`. The incumbent bound is not 
updated even if the value of the solution is better.
"""
function set_ip_primal_sol! end

# Macro to generate all methods update/add/set_ip/lp_primal/dual_sol!
macro gen_new_sol_method(expr)
    action_kw, sol_field, space_type = expr.args

    method_name = Symbol(string(action_kw,"_",sol_field,"_sol!"))
    max_len = Expr(:call, :getfield, :res, :(Symbol($(string("max_length_",sol_field,"_sols")))))
    bound_type = Expr(:curly, Symbol(string(space_type,"Bound")), :S)
    bound = Expr(:call, bound_type, :(getvalue(sol)))
    update_func = Symbol(string("update_",sol_field,"_bound!"))
    sol_type = Expr(:curly, Symbol(string(space_type,"Solution")), :F)
    insert_method_name = Expr(:call, :getfield, :res, :(Symbol($(string("insert_function_",sol_field,"_sols")))))
    field = Expr(:call, :getfield, :res, :(Symbol($(string(sol_field,"_sols")))))

    body = Expr(:call, insert_method_name, field, max_len, :sol)
    call_to_update = Expr(:call, update_func, :(res.incumbents), :b)
    define_array = Expr(:call, :setfield!, :res, :(Symbol($(string(sol_field,"_sols")))) , Expr(:ref, sol_type))

    if action_kw == :update
        body = quote
            b = $bound
            is_inc_sol = $call_to_update
            if is_inc_sol
                $body
            end
        end
    elseif action_kw == :add
        body = quote
            $body
            b = $bound
            $call_to_update
        end
    end
    code = quote
        function $method_name(res::OptimizationResult{F,S}, sol::$(sol_type)) where {F,S}
            $max_len == 0 && return
            if $field === nothing
                $define_array
            end
            $(body)
            return
        end
    end
    return esc(code)
end

@gen_new_sol_method update, ip_primal, Primal
@gen_new_sol_method add, ip_primal, Primal
@gen_new_sol_method set, ip_primal, Primal

@gen_new_sol_method update, lp_primal, Primal
@gen_new_sol_method add, lp_primal, Primal
@gen_new_sol_method set, lp_primal, Primal

@gen_new_sol_method update, lp_dual, Dual
@gen_new_sol_method add, lp_dual, Dual
@gen_new_sol_method set, lp_dual, Dual


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
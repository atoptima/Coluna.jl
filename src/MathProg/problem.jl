mutable struct Problem <: AbstractProblem
    initial_primal_bound::Union{Nothing, Float64}
    initial_dual_bound::Union{Nothing, Float64}
    original_formulation::Formulation
    re_formulation::Union{Nothing, Reformulation}
    default_optimizer_builder::Function
    initial_columns_callback::Union{Nothing, Function}
end

"""
    Problem(env)

Constructs an empty `Problem`.
"""
function Problem(env)
    original_formulation = create_formulation!(env, Original())
    return Problem(
        nothing, nothing, original_formulation, nothing,
        no_optimizer_builder, nothing
    )
end

set_original_formulation!(m::Problem, of::Formulation) = m.original_formulation = of
set_reformulation!(m::Problem, r::Reformulation) = m.re_formulation = r

get_original_formulation(m::Problem) = m.original_formulation
get_reformulation(m::Problem) = m.re_formulation

set_default_optimizer_builder!(p::Problem, default_opt_builder) = p.default_optimizer_builder = default_opt_builder

set_initial_primal_bound!(p::Problem, value::Real) = p.initial_primal_bound = value
set_initial_dual_bound!(p::Problem, value::Real) = p.initial_dual_bound = value

function get_initial_primal_bound(p::Problem)
    if isnothing(p.original_formulation)
        error("Cannot retrieve initial primal bound because the problem does not have original formulation.")
    end
    min = getobjsense(get_original_formulation(p)) == MinSense
    if !isnothing(p.initial_primal_bound)
        return ColunaBase.Bound(true, min, p.initial_primal_bound)
    end
    return ColunaBase.Bound(true, min)
end

function get_initial_dual_bound(p::Problem)
    if isnothing(p.original_formulation)
        error("Cannot retrieve initial dual bound because the problem does not have original formulation.")
    end
    min = getobjsense(get_original_formulation(p)) == MinSense
    if !isnothing(p.initial_dual_bound)
        return ColunaBase.Bound(false, min, p.initial_dual_bound)
    end
    return ColunaBase.Bound(false, min)
end

"""
If the original formulation is not reformulated, it means that the user did not
provide a way to decompose the model. In such a case, Coluna will call the
subsolver to optimize the original formulation.
"""
function get_optimization_target(p::Problem)
    if p.re_formulation === nothing
        return p.original_formulation
    end
    return p.re_formulation
end

function _register_initcols_callback!(problem::Problem, callback_function::Function)
    problem.initial_columns_callback = callback_function
    return
end
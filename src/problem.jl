struct Annotations
    vars_per_block::Dict{Int, Dict{Id{Variable},Variable}}
    constrs_per_block::Dict{Int, Dict{Id{Constraint},Constraint}}
    annotation_set::Set{BD.Annotation}
end
Annotations() = Annotations(
    Dict{Int, Dict{Id{Variable},Variable}}(),
    Dict{Int, Dict{Id{Constraint},Constraint}}(),
    Set{BD.Annotation}()
)

mutable struct Problem <: AbstractProblem
    name::String
    original_formulation::Union{Nothing, Formulation}
    re_formulation::Union{Nothing, Reformulation}
    form_counter::Counter
    timer_output::TimerOutputs.TimerOutput
    params::Params
    master_factory::Union{Nothing, JuMP.OptimizerFactory}
    pricing_factory::Union{Nothing, JuMP.OptimizerFactory}
    optimizer::Union{Nothing, MOI.AbstractOptimizer}
end

function Problem(params::Params, master_factory, pricing_factory)
    return Problem(
        "prob", nothing, nothing, Counter(-1), # 0 is for original form
        TimerOutputs.TimerOutput(),
        params, master_factory, pricing_factory, nothing
    )
end

function set_original_formulation!(m::Problem, of::Formulation)
    m.original_formulation = of
    return
end

function set_re_formulation!(m::Problem, r::Reformulation)
    m.re_formulation = r
    return
end

get_original_formulation(m::Problem) = m.original_formulation
get_re_formulation(m::Problem) = m.re_formulation

function load_problem_in_optimizer(prob::Problem)
    load_problem_in_optimizer(prob.re_formulation)
end

function initialize_moi_optimizer(prob::Problem)
    initialize_moi_optimizer(
        prob.re_formulation, prob.master_factory, prob.pricing_factory
    )
end

function _welcome_message()
    welcome = """
    Coluna
    Version 0.2 - https://github.com/atoptima/Coluna.jl
    """
    print(welcome)
end

function coluna_initialization(prob::Problem, annotations::Annotations)
    _welcome_message()
    _set_global_params(prob.params)
    reformulate!(prob, DantzigWolfeDecomposition)
    initialize_moi_optimizer(prob)
    load_problem_in_optimizer(prob)
    @info "Coluna initialized."
end

# # Behaves like optimize!(problem::Problem), but sets parameters before
# # function optimize!(problem::Reformulation)

function optimize!(prob::Problem, annotations::Annotations)
    coluna_initialization(prob, annotations)
    _globals_.initial_solve_time = time()
    @info _params_
    @timeit prob.timer_output "Solve problem" begin
        res = optimize!(prob.re_formulation)
    end
    # Stock the result in problem?
    println(prob.timer_output)
    return res
end

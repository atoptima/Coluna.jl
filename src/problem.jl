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

"""
    Problem

`Problem` is the most complex structure in Coluna.

Stores the original formulation `original_formulation` given by the user as well as the reformulated problem `re_formulation`.
"""
mutable struct Problem <: AbstractProblem
    original_formulation::Union{Nothing, Formulation}
    re_formulation::Union{Nothing, Reformulation}
    form_counter::Counter # 0 is for original form
    master_factory::Union{Nothing, JuMP.OptimizerFactory}
    pricing_factory::Union{Nothing, JuMP.OptimizerFactory}
end

"""
    Problem(params::Params, master_factory, pricing_factory)

Constructs an empty `Problem`.
"""
function Problem(master_factory, pricing_factory)
    return Problem(
        nothing, nothing, Counter(-1),
        master_factory, pricing_factory
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

function coluna_initialization(prob::Problem, annotations::Annotations,
                               params::Params)
    _welcome_message()
    _set_global_params(params)
    reformulate!(prob, annotations, DantzigWolfeDecomposition)
    relax_integrality!(prob.re_formulation.master)
    initialize_moi_optimizer(prob)
    @info "Coluna initialized."
end

# # Behaves like optimize!(problem::Problem), but sets parameters before
# # function optimize!(problem::Reformulation)

function optimize!(prob::Problem, annotations::Annotations, params::Params)
    coluna_initialization(prob, annotations, params)
    _globals_.initial_solve_time = time()
    @info _params_
    TO.@timeit to "Coluna" begin
        res = optimize!(prob.re_formulation)
    end
    println(to)
    return res
end

mutable struct Annotations
    tree::Union{BD.Tree, Nothing}
    vars_per_ann::Dict{BD.Annotation, Dict{Id{Variable},Variable}}
    constrs_per_ann::Dict{BD.Annotation, Dict{Id{Constraint},Constraint}}
    annotation_set::Set{BD.Annotation}
end

Annotations() = Annotations(
    nothing,
    Dict{BD.Annotation, Dict{Id{Variable},Variable}}(),
    Dict{BD.Annotation, Dict{Id{Constraint},Constraint}}(),
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
    default_optimizer_builder::Function
end

"""
    Problem(b::Function)

Constructs an empty `Problem`.
"""
Problem(b::Function) = Problem(nothing, nothing, Counter(-1), b)

set_original_formulation!(m::Problem, of::Formulation) = m.original_formulation = of
set_re_formulation!(m::Problem, r::Reformulation) = m.re_formulation = r

get_original_formulation(m::Problem) = m.original_formulation
get_re_formulation(m::Problem) = m.re_formulation

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
    reformulate!(prob, annotations, params.global_strategy)
    relax_integrality!(prob.re_formulation.master)
    @info "Coluna initialized."
end

# # Behaves like optimize!(problem::Problem), but sets parameters before
# # function optimize!(problem::Reformulation)

function optimize!(prob::Problem, annotations::Annotations, params::Params)
    coluna_initialization(prob, annotations, params)
    _globals_.initial_solve_time = time()
    @info _params_
    TO.@timeit _to "Coluna" begin
        opt_result = optimize!(prob.re_formulation)
    end
    println(_to)
    println("Terminated.")
    @show getbestprimalsol(opt_result)
    println("Primal bound: ", getprimalbound(opt_result))
    println("Dual bound: ", getdualbound(opt_result))
    return opt_result
end

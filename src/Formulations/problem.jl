mutable struct Annotations
    tree::Union{BD.Tree, Nothing}
    ann_per_var::Dict{Id{Variable}, BD.Annotation}
    ann_per_constr::Dict{Id{Constraint}, BD.Annotation}
    vars_per_ann::Dict{BD.Annotation, Dict{Id{Variable},Variable}}
    constrs_per_ann::Dict{BD.Annotation, Dict{Id{Constraint},Constraint}}
    ann_per_form::Dict{Int, BD.Annotation}
    annotation_set::Set{BD.Annotation}
end

Annotations() = Annotations(
    nothing,
    Dict{Id{Variable}, BD.Annotation}(), Dict{Id{Constraint}, BD.Annotation}(),
    Dict{BD.Annotation, Dict{Id{Variable},Variable}}(),
    Dict{BD.Annotation, Dict{Id{Constraint},Constraint}}(),
    Dict{Int, BD.Annotation}(),
    Set{BD.Annotation}()
)

function store!(annotations::Annotations, ann::BD.Annotation, var::Variable)
    push!(annotations.annotation_set, ann)
    annotations.ann_per_var[getid(var)] = ann
    if !haskey(annotations.vars_per_ann, ann)
        annotations.vars_per_ann[ann] = Dict{Id{Variable}, Variable}()
    end
    annotations.vars_per_ann[ann][getid(var)] = var
    return
end

function store!(annotations::Annotations, ann::BD.Annotation, constr::Constraint)
    push!(annotations.annotation_set, ann)
    annotations.ann_per_constr[getid(constr)] = ann
    if !haskey(annotations.constrs_per_ann, ann)
        annotations.constrs_per_ann[ann] = Dict{Id{Constraint}, Constraint}()
    end
    annotations.constrs_per_ann[ann][getid(constr)] = constr
    return
end

function store!(annotations::Annotations, form::AbstractFormulation, ann::BD.Annotation)
    form_uid = getuid(form)
    if haskey(annotations.ann_per_form, form_uid)
        error("Formulation with uid $form_uid already has annotation.")
    end
    annotations.ann_per_form[form_uid] = ann
    return
end

function Base.get(annotations::Annotations, form::AbstractFormulation)
    form_uid = getuid(form)
    if !haskey(annotations.ann_per_form, form_uid)
        error("Formulation with uid $form_uid does not have any annotation.")
    end
    return annotations.ann_per_form[form_uid]
end

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

# TODO : put Coluna initialization outside of Formulation submodule
function coluna_initialization(
    prob::Problem, annotations::Annotations, params::Params
)
    _welcome_message()
    _set_global_params(params)
    reformulate!(prob, annotations, params.global_strategy)
    relax_integrality!(prob.re_formulation.master)
    @info "Coluna initialized."
end


# TODO : should be outside
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
    TO.reset_timer!(_to)
    @logmsg LogLevel(1) "Terminated"
    @logmsg LogLevel(1) string("Primal bound: ", getprimalbound(opt_result))
    @logmsg LogLevel(1) string("Dual bound: ", getdualbound(opt_result))
    return opt_result
end

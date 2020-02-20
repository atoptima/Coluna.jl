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
Problem() = Problem(nothing, nothing, Counter(-1), no_optimizer_builder)

set_original_formulation!(m::Problem, of::Formulation) = m.original_formulation = of
set_re_formulation!(m::Problem, r::Reformulation) = m.re_formulation = r

get_original_formulation(m::Problem) = m.original_formulation
get_re_formulation(m::Problem) = m.re_formulation

set_default_optimizer_builder!(p::Problem, default_opt_builder) = p.default_optimizer_builder = default_opt_builder


## Annotations

mutable struct Annotations
    tree::Union{BD.Tree, Nothing}
    ann_per_var::Dict{VarId, BD.Annotation}
    ann_per_constr::Dict{ConstrId, BD.Annotation}
    vars_per_ann::Dict{BD.Annotation, Dict{VarId,Variable}}
    constrs_per_ann::Dict{BD.Annotation, Dict{ConstrId,Constraint}}
    ann_per_form::Dict{Int, BD.Annotation}
    annotation_set::Set{BD.Annotation}
end

Annotations() = Annotations(
    nothing,
    Dict{VarId, BD.Annotation}(), Dict{ConstrId, BD.Annotation}(),
    Dict{BD.Annotation, Dict{VarId,Variable}}(),
    Dict{BD.Annotation, Dict{ConstrId,Constraint}}(),
    Dict{Int, BD.Annotation}(),
    Set{BD.Annotation}()
)

function store!(annotations::Annotations, ann::BD.Annotation, var::Variable)
    push!(annotations.annotation_set, ann)
    annotations.ann_per_var[getid(var)] = ann
    if !haskey(annotations.vars_per_ann, ann)
        annotations.vars_per_ann[ann] = Dict{VarId, Variable}()
    end
    annotations.vars_per_ann[ann][getid(var)] = var
    return
end

function store!(annotations::Annotations, ann::BD.Annotation, constr::Constraint)
    push!(annotations.annotation_set, ann)
    annotations.ann_per_constr[getid(constr)] = ann
    if !haskey(annotations.constrs_per_ann, ann)
        annotations.constrs_per_ann[ann] = Dict{ConstrId, Constraint}()
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
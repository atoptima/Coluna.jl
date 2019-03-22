
function Reformulation(method::SolutionMethod)
    return Reformulation(method, nothing, nothing, Vector{AbstractFormulation}())
end

function Reformulation()
    return Reformulation(DirectMip)
end

function setmaster!(r::Reformulation, f)
    r.master = f
    return
end

function add_dw_pricing_sp!(r::Reformulation, f)
    push!(r.dw_pricing_subprs, f)
    return
end


function fill_annotations_set!(ann_set, varconstr_annotations)
    for (varconstr_id, varconstr_annotation) in varconstr_annotations
        push!(ann_set, varconstr_annotation)
    end
    return
end

function inverse(varconstr_annotations)
    varconstr_in_form = Dict{FormId, Vector{Int}}()
    for (varconstr_id, annotation) in varconstr_annotations
        if !haskey(varconstr_in_form, annotation.unique_id)
            varconstr_in_form[annotation.unique_id] = Int[]
        end
        push!(varconstr_in_form[annotation.unique_id], varconstr_id)
    end
    return varconstr_in_form
end

function build_dw_master!(annotation_id::Int,
                          formulation::Formulation,
                          vars_in_forms::Dict{BD.Annotation,VarId},
                          constrs_in_forms::Dict{BD.Annotation,ConstrId})
    return
end

function build_pricing_sp!(annotation_id::Int,
                           formulation::Formulation,
                           vars_in_forms::Dict{BD.Annotation,VarId},
                           constrs_in_forms::Dict{BD.Annotation,ConstrId})
    return
end

function reformulate!(m::Model, method::SolutionMethod)
    println("Do reformulation.")

    # Create formulations & reformulations
    ann_set = Set{BD.Annotation}()
    fill_annotations_set!(ann_set, m.var_annotations)
    fill_annotations_set!(ann_set, m.constr_annotations)

    # At the moment, BlockDecomposition supports only classic 
    # Dantzig-Wolfe decomposition.
    # TODO : improve all drafts as soon as BlockDecomposition returns a
    # decomposition-tree.

    vars_in_forms = inverse(m.var_annotations)
    constrs_in_forms = inverse(m.constr_annotations)
    @show vars_in_forms
    @show constrs_in_forms


    # DRAFT : to be improved
    reformulation = Reformulation(method)
    ann_sorted_by_uid = sort(collect(ann_set), by = ann -> ann.unique_id)
    formulations = Dict{Int, Formulation}()
    for annotation in ann_sorted_by_uid
        f = Formulation(m)
        formulations[annotation.unique_id] = f
        if annotation.problem == BD.Master
            setmaster!(reformulation, f)
            build_dw_master!(annotation.unique_id, f, vars_in_forms, constrs_in_forms)
        elseif annotation.problem == BD.Pricing
            add_dw_pricing_sp!(reformulation, f)
            build_dw_pricing_sp!(annotation.unique_id, f, vars_in_forms, constrs_in_forms)
        else
            error("Not supported yet.")
        end
    end
    # END_DRAFT


    # TODO : Register constraints and variables

end


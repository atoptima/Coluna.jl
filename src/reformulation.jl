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

function reformulation!(m::Model, vars_annotations, constrs_annotations)
    println("Do reformulation.")

    # Create formulations & reformulations
    ann_set = Set{BD.Annotation}()
    fill_annotations_set!(ann_set, vars_annotations)
    fill_annotations_set!(ann_set, constrs_annotations)

    # At the moment, BlockDecomposition supports only classic 
    # Dantzig-Wolfe decomposition.
    # TODO : improve all drafts as soon as BlockDecomposition returns a
    # decomposition-tree.

    # DRAFT : to be improved
    reformulation = Reformulation()
    ann_sorted_by_uid = sort(collect(ann_set), by = ann -> ann.unique_id)
    formulations = Dict{Int, Formulation}()
    for annotation in ann_sorted_by_uid
        f = Formulation(m)
        formulations[annotation.unique_id] = f
        if annotation.problem == BD.Master
            setmaster!(reformulation, f)
        elseif annotation.problem == BD.Pricing
            add_dw_pricing_sp!(reformulation, f)
        else
            error("Not supported yet.")
        end
    end
    # END_DRAFT

    vars_in_form = inverse(vars_annotations)
    constrs_in_form = inverse(constrs_annotations)

    @show vars_in_form
    @show constrs_in_form

    # TODO : Register constraints and variables

end
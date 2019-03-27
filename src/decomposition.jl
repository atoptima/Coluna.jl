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

function build_dw_master!(model::Model,
                          annotation_id::Int,
                          reformulation::Reformulation,
                          master_form::Formulation,
                          vars_in_form::Vector{VarId},
                          constrs_in_form::Vector{ConstrId})


    orig_form = get_original_formulation(model)

    
    # create convexity constraints
    
    @assert !isempty(reformulation.dw_pricing_subprs)
    for sp_form in reformulation.dw_pricing_subprs
        # create convexity constraint
        name = "convexity_sp_$(sp_form.uid)"
        sense = Equal
        rhs = 1.0
        kind = Core
        flag = Static
        duty = MastConvexityConstr
        conv_constr = Constraint(model, getuid(master_form), name, rhs, sense,kind,flag,duty)
        membership = VarMembership() 
        add!(master_form, conv_constr, membership)

        # create representative of sp setup var
        var_uids = getvar_uids(sp_form, PricingSpSetupVar)
        @assert length(var_uids) == 1
        for var_uid in var_uids
            var = getvar(sp_form, var_uid)
            @assert getduty(var) == PricingSpSetupVar
            var_clone = clone_in_formulation!(var, sp_form, master_form, MastRepPricingSpVar)
            membership = ConstrMembership()
            set!(membership,getuid(conv_constr), 1.0)
            add_constr_members_of_var!(master_form.memberships, var_uid, membership)
        end

        # create representative of sp var
        clone_in_formulation!(getvar_uids(sp_form, PricingSpVar), orig_form, master_form, MastRepPricingSpVar)
        
        
    end


    # copy of pure master variables
    clone_in_formulation!(vars_in_form, orig_form, master_form, PureMastVar)

    # copy of master constraints
    clone_in_formulation!(constrs_in_form, orig_form, master_form, MasterConstr)

    # TODO Detect and copy of pure master constraints

    
    
    
    return
end

function build_dw_pricing_sp!(m::Model,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::Vector{VarId},
                              constrs_in_form::Vector{ConstrId})
    
    orig_form = get_original_formulation(m)

    name = "PricingSetupVar_sp_$(sp_form.uid)"
    cost = 1.0
    lb = 1.0
    ub = 1.0
    kind = Binary
    flag = Implicit
    duty = PricingSpSetupVar
    sense = Positive
    setup_var = Variable(m, getuid(sp_form), name, cost, lb, ub, kind, flag, duty, sense)
    add!(sp_form, setup_var)


    clone_in_formulation!(vars_in_form, orig_form, sp_form, PricingSpVar)

    # distinguish PricingSpPureVar

    clone_in_formulation!(constrs_in_form, orig_form, sp_form, PricingSpPureConstr)

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


    reformulation = Reformulation(m, method)
    ann_sorted_by_uid = sort(collect(ann_set), by = ann -> ann.unique_id)
    formulations = Dict{Int, Formulation}()

    master_form = Formulation(m, m.master_factory())
    
    # Build pricing  subproblems
    master_annotation_id = -1
    for annotation in ann_sorted_by_uid

        if annotation.problem == BD.Master
            master_annotation_id = annotation.unique_id
            formulations[annotation.unique_id] = master_form

        elseif annotation.problem == BD.Pricing
            f = Formulation(m, master_form)
            formulations[annotation.unique_id] = f
            vars_in = Vector{VarId}()
            constrs_in = Vector{ConstrId}()
            if haskey(vars_in_forms, annotation.unique_id)
                vars_in =  vars_in_forms[annotation.unique_id]
            end
            if haskey(constrs_in_forms, annotation.unique_id)
                constrs_in = constrs_in_forms[annotation.unique_id]
            end
            add_dw_pricing_sp!(reformulation, f)
            build_dw_pricing_sp!(m, annotation.unique_id, f, vars_in, constrs_in)
        else 
            error("Not supported yet.")
        end
    end

    # Build Master
    @assert master_annotation_id != -1
    vars_in = Vector{VarId}()
    constrs_in = Vector{ConstrId}()
    if haskey(vars_in_forms, master_annotation_id)
        vars =  vars_in_forms[master_annotation_id]
    end
    if haskey(constrs_in_forms, master_annotation_id)
        constrs = constrs_in_forms[master_annotation_id]
    end
    setmaster!(reformulation, master_form)
    build_dw_master!(m, master_annotation_id, reformulation, master_form, vars_in, constrs_in)

    set_re_formulation!(m, reformulation)
    @show master_form
end


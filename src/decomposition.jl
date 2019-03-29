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
    reformulation.dw_pricing_sp_lb = Dict{FormId, ConstrId}()
    reformulation.dw_pricing_sp_ub = Dict{FormId, ConstrId}()
    
    # create convexity constraints
    
    @assert !isempty(reformulation.dw_pricing_subprs)
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)
        # create convexity constraint
        name = "sp_lb_$(sp_uid)"
        sense = Greater
        rhs = 1.0
        kind = Core
        flag = Static
        duty = MasterConvexityConstr
        lb_conv_constr = Constraint(duty, model, getuid(master_form), name, rhs, sense,kind,flag)
        reformulation.dw_pricing_sp_lb[sp_uid] = getuid(lb_conv_constr)
        membership = VarMembership() 
        add!(master_form, lb_conv_constr, membership)

        name = "sp_ub_$(sp_uid)"
        sense = Less
        ub_conv_constr = Constraint(duty, model, getuid(master_form), name, rhs, sense,kind,flag)
        reformulation.dw_pricing_sp_lb[sp_uid] = getuid(ub_conv_constr)
        membership = VarMembership() 
        add!(master_form, ub_conv_constr, membership)

        # create representative of sp setup var
        setup_vars_filter = Filter(sp_form.vars, x->(getduty(x) == PricingSpSetupVar),
                                   sp_form.vars.members)
        var_uids = get_nz_ids(setup_vars_filter)
        @assert length(var_uids) == 1
        for var_uid in var_uids
            var = getvar(sp_form, var_uid)
            @assert getduty(var) == PricingSpSetupVar
            var_clone = clone_in_formulation!(var, sp_form, master_form, Implicit, MastRepPricingSpVar)
            membership = ConstrMembership()
            set!(membership,getuid(lb_conv_constr), 1.0)
            set!(membership,getuid(ub_conv_constr), 1.0)
            add_constr_members_of_var!(master_form.memberships, var_uid, membership)
        end

        # create representative of sp var
        sp_vars_filter = Filter(sp_form.vars, x->(getduty(x) == PricingSpVar),
                                   sp_form.vars.members)
        clone_in_formulation!(get_nz_ids(sp_vars_filter), orig_form, master_form, Implicit, MastRepPricingSpVar)
        
    end

    # copy of pure master variables
    clone_in_formulation!(vars_in_form, orig_form, master_form, Static, PureMastVar)
    # copy of master constraints
    clone_in_formulation!(constrs_in_form, orig_form, master_form, Static, MasterConstr)

    local_art_var = true
    
    if (local_art_var)
        # artificial variables
        for constr_uid in constrs_in_form #  getconstraintuids(master_form)
            name = "loc_art_$(constr_uid)"
            cost = 1.0
            lb = 0.0
            ub = 1.0
            kind = Binary
            flag = Artificial
            sense = Positive
            art_var = Variable(MastArtVar, model, getuid(master_form), name, cost, lb, ub, kind, flag, sense)
            membership = ConstrMembership()
            membership.members[constr_uid] = 1.0
            add!(master_form, art_var, membership)
        end

    else
        # global artifical variables
        
        name = "glo⁺_art"
        cost = 1.0
        lb = 0.0
        ub = 1.0
        kind = Binary
        flag = Artificial
        sense = Positive
        pos_global_art_var = Variable(MastArtVar, model, getuid(master_form), name, cost, lb, ub, kind, flag, sense)
        membership = ConstrMembership()
        for constr_uid in getconstraintuids(master_form)
            membership.members[constr_uid] = 1.0
        end
        add!(master_form, pos_global_art_var, membership)

        name = "glo⁻_art"
        cost = 1.0
        lb = 0.0
        ub = 1.0
        kind = Binary
        flag = Artificial
        sense = Positive
        neg_global_art_var = Variable(MastArtVar, model, getuid(master_form), name, cost, lb, ub, kind, flag, sense)
        membership = ConstrMembership()
        for constr_uid in getconstraintuids(master_form)
            membership.members[constr_uid] = -1.0
        end
        add!(master_form, neg_global_art_var, membership)
    end

    return
end

function build_dw_pricing_sp!(m::Model,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::Vector{VarId},
                              constrs_in_form::Vector{ConstrId})
    
    orig_form = get_original_formulation(m)

    name = "PricingSetupVar_sp_$(sp_form.uid)"
    cost = 0.0
    lb = 1.0
    ub = 1.0
    kind = Binary
    flag = Implicit
    duty = PricingSpSetupVar
    sense = Positive
    setup_var = Variable(duty, m, getuid(sp_form), name, cost, lb, ub, kind, flag, sense)
    add!(sp_form, setup_var)


    clone_in_formulation!(vars_in_form, orig_form, sp_form, Static, PricingSpVar)

    # distinguish PricingSpPureVar

    clone_in_formulation!(constrs_in_form, orig_form, sp_form, Static, PricingSpPureConstr)

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

    master_form = Formulation(DwMaster, m, reformulation, m.master_factory())
    
    # Build pricing  subproblems
    master_annotation_id = -1
    for annotation in ann_sorted_by_uid

        if annotation.problem == BD.Master
            master_annotation_id = annotation.unique_id
            formulations[annotation.unique_id] = master_form

        elseif annotation.problem == BD.Pricing
            f = Formulation(DwSp, m, master_form, m.pricing_factory())
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
    vars = Vector{VarId}()
    constrs = Vector{ConstrId}()
    if haskey(vars_in_forms, master_annotation_id)
        vars =  vars_in_forms[master_annotation_id]
    end
    if haskey(constrs_in_forms, master_annotation_id)
        constrs = constrs_in_forms[master_annotation_id]
    end
    setmaster!(reformulation, master_form)
    build_dw_master!(m, master_annotation_id, reformulation, master_form, vars, constrs)

    set_re_formulation!(m, reformulation)

    println("\e[1;34m MASTER FORMULATION \e[00m")
    @show master_form
    println("\e[1;34m PRICING SP FORMULATIONS \e[00m")
    for p in reformulation.dw_pricing_subprs
        @show p
        println("\e[32m ---------------- \e[00m")
    end
    return
end


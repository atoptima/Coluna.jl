function fill_annotations_set!(ann_set, varconstr_annotations)
    for (varconstr_id, varconstr_annotation) in varconstr_annotations
        push!(ann_set, varconstr_annotation)
    end
    return
end

function inverse(varconstr_annotations)
    varconstr_in_form = Dict{FormId, Vector{Id}}()
    for (varconstr_id, annotation) in varconstr_annotations
        if !haskey(varconstr_in_form, annotation.unique_id)
            varconstr_in_form[annotation.unique_id] = Id[]
        end
        push!(varconstr_in_form[annotation.unique_id], varconstr_id)
    end
    return varconstr_in_form
end

function build_dw_master!(prob::Problem,
                          annotation_id::Int,
                          reformulation::Reformulation,
                          master_form::Formulation,
                          vars_in_form::Vector{Id},
                          constrs_in_form::Vector{Id})

    orig_form = get_original_formulation(prob)
    reformulation.dw_pricing_sp_lb = Dict{FormId, Id}()
    reformulation.dw_pricing_sp_ub = Dict{FormId, Id}()
    
    @assert !isempty(reformulation.dw_pricing_subprs)
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)

        # create convexity constraint
        name = "sp_lb_$(sp_uid)"
        sense = Greater
        rhs = 1.0
        kind = Core
        flag = Static
        duty = MasterConstr #MasterConvexityConstr
        lb_conv_constr = Constraint(getuid(master_form), name, rhs, sense, kind)
        membership = Membership(Variable) 
        ub_conv_constr_id = add!(master_form, lb_conv_constr, duty, membership)
        reformulation.dw_pricing_sp_lb[sp_uid] = ub_conv_constr_id

        name = "sp_ub_$(sp_uid)"
        sense = Less
        ub_conv_constr = Constraint(getuid(master_form), name, rhs, sense, kind)
        membership = Membership(Variable) 
        lb_conv_constr_id = add!(master_form, ub_conv_constr, duty, membership)
        reformulation.dw_pricing_sp_ub[sp_uid] = lb_conv_constr_id
   end

    # copy of pure master variables
    clone_in_formulation!(vars_in_form, orig_form, master_form, Static, PureMastVar)
    # copy of master constraints
    clone_in_formulation!(constrs_in_form, orig_form, master_form, Static, MasterConstr)

    local_art_var = true
    
    #if (local_art_var)
        # local artificial variables
        for constr_uid in constrs_in_form #  getconstr_ids(master_form)
            name = "loc_art_$(getuid(constr_uid))"
            cost = 10.0
            lb = 0.0
            ub = 1.0
            kind = Binary
            flag = Artificial
            sense = Positive
            art_var = Variable(getuid(master_form), name, cost, lb, ub, kind, flag, sense)
            membership = Membership(Constraint)
            membership.members[constr_uid] = 1.0
            add!(master_form, art_var, MastArtVar, membership)
        end

    #else
        # global artifical variables
        
        name = "glo⁺_art"
        cost = 100.0
        lb = 0.0
        ub = 1.0
        kind = Binary
        flag = Artificial
        sense = Positive
        pos_global_art_var = Variable(getuid(master_form), name, cost, lb, ub, kind, flag, sense)
        membership = Membership(Constraint)
        for constr_uid in getconstr_ids(master_form)
            membership.members[constr_uid] = 1.0
        end
        add!(master_form, pos_global_art_var, MastArtVar, membership)

        name = "glo⁻_art"
        cost = 100.0
        lb = 0.0
        ub = 1.0
        kind = Binary
        flag = Artificial
        sense = Positive
        neg_global_art_var = Variable(getuid(master_form), name, cost, lb, ub, kind, flag, sense)
        membership = Membership(Constraint)
        for constr_uid in getconstr_ids(master_form)
            membership.members[constr_uid] = -1.0
        end
        add!(master_form, neg_global_art_var, MastArtVar, membership)
    #end

    return
end

function build_dw_pricing_sp!(m::Problem,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::Vector{Id},
                              constrs_in_form::Vector{Id})
    
    orig_form = get_original_formulation(m)

    master_form = sp_form.parent_formulation

    reformulation = master_form.parent_formulation

    sp_uid = getuid(sp_form)

   ## Create Pure Pricing Sp Var & constr
    clone_in_formulation!(vars_in_form, orig_form, sp_form, Static, PricingSpVar)
    clone_in_formulation!(constrs_in_form, orig_form, sp_form, Static, PricingSpPureConstr)


    ## Create PricingSetupVar
    name = "PricingSetupVar_sp_$(sp_form.uid)"
    cost = 0.0
    lb = 1.0
    ub = 1.0
    kind = Binary
    flag = Static
    duty = PricingSpSetupVar
    sense = Positive
    setup_var = Variable(sp_uid, name, cost, lb, ub, kind, flag, sense)
    membership = Membership(Constraint)
    set!(membership, reformulation.dw_pricing_sp_lb[sp_uid], 1.0)
    set!(membership, reformulation.dw_pricing_sp_ub[sp_uid], 1.0)
    add!(sp_form, setup_var, duty, membership)
    @show setup_var

    # should be move in build dw master ?
    #clone_in_formulation!(setup_var, sp_form, master_form, Implicit, MastRepPricingSpVar)

    ## Create representative of sp var in master
    var_ids = getvar_ids(sp_form, PricingSpVar)
    @show var_ids
    clone_in_formulation!(var_ids, sp_form, master_form, Implicit, MastRepPricingSpVar)


    return
end

function reformulate!(m::Problem, method::SolutionMethod)
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


    # Create reformulation
    reformulation = Reformulation(m, method)
    set_re_formulation!(m, reformulation)

    # Create master formulation
    master_form = Formulation(DwMaster, m, reformulation, m.master_factory())
    setmaster!(reformulation, master_form)
    
    # Create pricing subproblem formulations
    ann_sorted_by_uid = sort(collect(ann_set), by = ann -> ann.unique_id)
    formulations = Dict{Int, Formulation}()
    master_annotation_id = -1
    for annotation in ann_sorted_by_uid
        if annotation.problem == BD.Master
            master_annotation_id = annotation.unique_id
            formulations[annotation.unique_id] = master_form

        elseif annotation.problem == BD.Pricing
            f = Formulation(DwSp, m, master_form, m.pricing_factory())
            formulations[annotation.unique_id] = f
            add_dw_pricing_sp!(reformulation, f)
        else 
            error("Not supported yet.")
        end
    end

    # Build Master
    @show master_annotation_id
    @assert master_annotation_id != -1
    vars = Vector{Id}()
    constrs = Vector{Id}()
    if haskey(vars_in_forms, master_annotation_id)
        vars =  vars_in_forms[master_annotation_id]
    end
    if haskey(constrs_in_forms, master_annotation_id)
        constrs = constrs_in_forms[master_annotation_id]
    end
    build_dw_master!(m, master_annotation_id, reformulation, master_form, vars, constrs)

    # Build Pricing Sp
    for annotation in ann_sorted_by_uid
        if  annotation.problem == BD.Pricing
            vars_in = Vector{Id}()
            constrs_in = Vector{Id}()
            if haskey(vars_in_forms, annotation.unique_id)
                vars_in =  vars_in_forms[annotation.unique_id]
            end
            if haskey(constrs_in_forms, annotation.unique_id)
                constrs_in = constrs_in_forms[annotation.unique_id]
            end
            println("> build sp $(annotation.unique_id)")
            build_dw_pricing_sp!(m, annotation.unique_id,
                                 formulations[annotation.unique_id],
                                 vars_in, constrs_in)
        end
    end
    

    println("\e[1;34m MASTER FORMULATION \e[00m")
    @show master_form
    println("\e[1;34m PRICING SP FORMULATIONS \e[00m")
    for p in reformulation.dw_pricing_subprs
        @show p
        println("\e[32m ---------------- \e[00m")
    end
    return
end


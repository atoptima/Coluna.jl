function initialize_local_art_vars(master::Formulation, constrs_in_form)
    for (id, constr) in constrs_in_form
        art_var = LocalArtVar(getuid(master), getuid(id))
        membership = ConstrMemberDict()
        membership.members[id] = 1.0
        add!(master, art_var, MastArtVar, membership)
    end
end

function initialize_global_art_vars(master::Formulation)
    global_pos = GlobalArtVar(getuid(master), Positive)
    global_neg = GlobalArtVar(getuid(master), Negative)
    pos_membership = ConstrMemberDict()
    neg_membership = ConstrMemberDict()
    for (id, constr) in getconstrs(master)
        if getsense(constr) == Greater
            pos_membership.members[id] = 1.0
        elseif getsense(constr) == Less
            neg_membership.members[id] = -1.0
        end
    end
    add!(master, global_pos, MastArtVar, pos_membership)
    add!(master, global_neg, MastArtVar, neg_membership)
end

function initialize_artificial_variables(master::Formulation, constrs_in_form)
    # if (_params_.art_vars_mode == Local)
        initialize_local_art_vars(master, constrs_in_form)
    # elseif (_params_.art_vars_mode == Global)
        initialize_global_art_vars(master)
    # end
end

function build_dw_master!(prob::Problem,
                          annotation_id::Int,
                          reformulation::Reformulation,
                          master_form::Formulation,
                          vars_in_form::VarDict,
                          constrs_in_form::ConstrDict)
                          # Commented for now, I dont think managers are usefull here
                          # vars_in_form::Manager{Id{VarState}, Variable},
                          # constrs_in_form::Manager{Id{ConstrState}, Constraint})

    orig_form = get_original_formulation(prob)
    reformulation.dw_pricing_sp_lb = Dict{FormId, Id}()
    reformulation.dw_pricing_sp_ub = Dict{FormId, Id}()

    @show "master vars " vars_in_form
    @show "master constrs " constrs_in_form

    # copy of pure master variables
    clone_in_formulation!(master_form, orig_form, vars_in_form, PureMastVar)
    # copy of master constraints
    clone_in_formulation!(master_form, orig_form, constrs_in_form, MasterConstr)

    @assert !isempty(reformulation.dw_pricing_subprs)
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)

        # create convexity constraint
        name = "sp_lb_$(sp_uid)"
        sense = Greater
        rhs = 1.0
        kind = Core
        duty = MasterConstr #MasterConvexityConstr
        lb_conv_constr = Constraint(getuid(master_form), name, rhs, sense, kind)
        membership = VarMemberDict()
        ub_conv_constr_id = add!(master_form, lb_conv_constr, duty, membership)
        reformulation.dw_pricing_sp_lb[sp_uid] = ub_conv_constr_id

        name = "sp_ub_$(sp_uid)"
        sense = Less
        ub_conv_constr = Constraint(getuid(master_form), name, rhs, sense, kind)
        membership = VarMemberDict()
        lb_conv_constr_id = add!(master_form, ub_conv_constr, duty, membership)
        reformulation.dw_pricing_sp_ub[sp_uid] = lb_conv_constr_id

        ## Create PricingSetupVar
        name = "PricingSetupVar_sp_$(sp_form.uid)"
        cost = 0.0
        lb = 1.0
        ub = 1.0
        kind = Continuous
        duty = PricingSpSetupVar
        sense = Positive
        setup_var = Variable(sp_uid, name, cost, lb, ub, kind,  sense)
        #membership = ConstrMemberDict()
        #membership[ub_conv_constr_id] = 1.0
        #membership[lb_conv_constr_id] = 1.0
        @show setup_var
        setup_var_id = add!(sp_form, setup_var, duty)
        setup_var_clone_id = clone_in_formulation!(master_form, setup_var_id, setup_var, MastRepPricingSpVar)
        set_constr_members_of_var!(master_form.memberships, setup_var_clone_id, ub_conv_constr_id, 1.0)
        set_constr_members_of_var!(master_form.memberships, setup_var_clone_id, lb_conv_constr_id, 1.0)

        vars = filter(_active_pricingSpVar_, getvars(sp_form))
        @show "Sp Var to add in master " vars
        clone_in_formulation!(master_form, sp_form, vars, MastRepPricingSpVar)
    end

    # clone_membership_in_formulation!(master_form, orig_form, vars_in_form)
    # clone_membership_in_formulation!(master_form, orig_form, constrs_in_form)
    clone_memberships!(master_form, orig_form)

    initialize_artificial_variables(master_form, constrs_in_form)

    @show master_form
    readline()

    return
end

function build_dw_pricing_sp!(prob::Problem,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::VarDict,
                              constrs_in_form::ConstrDict)
    # Commented for now, I dont think managers are usefull here
    # vars_in_form::Manager{Id{VarState}, Variable},
    # constrs_in_form::Manager{Id{ConstrState}, Constraint})
    
    orig_form = get_original_formulation(prob)

    master_form = sp_form.parent_formulation

    reformulation = master_form.parent_formulation

    sp_uid = getuid(sp_form)

    ## Create Pure Pricing Sp Var & constr
    clone_in_formulation!(sp_form, orig_form, vars_in_form, PricingSpVar)
    clone_in_formulation!(sp_form, orig_form, constrs_in_form, PricingSpPureConstr)
    clone_memberships!(sp_form, orig_form)

    # clone_in_formulation!(sp_form, orig_form, constrs_in_form, PricingSpPureConstr)


 
    # should be move in build dw master ?
    #clone_vc_in_formulation!(setup_var, sp_form, master_form, Implicit, MastRepPricingSpVar)

    ## BD.AnnotationCreate representative of sp var in master

    return
end

function reformulate!(prob::Problem, method::SolutionMethod)
    println("Do reformulation.")

    # Create formulations & reformulations

    
 
    # At the moment, BlockDecomposition supports only classic 
    # Dantzig-Wolfe decomposition.
    # TODO : improve all drafts as soon as BlockDecomposition returns a
    # decomposition-tree.

    vars_per_block = prob.vars_per_block #:: Dict{BD.Annotation, VarDict}
    constrs_per_block = prob.constrs_per_block #::Dict{BD.Annotation, ConstrDict}
    annotation_set = prob.annotation_set #::Set{BD.Annotation}()
    
    #@show vars_per_block
    #@show constrs_per_block
    
    # Create reformulation
    reformulation = Reformulation(prob, method)
    set_re_formulation!(prob, reformulation)

    # Create master formulation
    master_form = Formulation(DwMaster, prob, reformulation, prob.master_factory())
    setmaster!(reformulation, master_form)

    # Create pricing subproblem formulations
    ann_sorted_by_uid = sort(collect(annotation_set), by = ann -> ann.unique_id)
    @show ann_sorted_by_uid
    
    formulations = Dict{Int, Formulation}()
    master_unique_id = -1

    for annotation in ann_sorted_by_uid
        if annotation.problem == BD.Master
            master_unique_id = annotation.unique_id
            formulations[annotation.unique_id] = master_form
        elseif annotation.problem == BD.Pricing
            f = Formulation(DwSp, prob, master_form, prob.pricing_factory())
            formulations[annotation.unique_id] = f
            add_dw_pricing_sp!(reformulation, f)
        else 
            error(string("Subproblem type ", annotation.problem,
                         " not supported yet."))
        end
    end

    # Build Pricing Sp
    for annotation in ann_sorted_by_uid
        @show annotation
        if  annotation.problem == BD.Pricing
            vars = VarDict()
            if haskey(vars_per_block, annotation.unique_id)
                vars = vars_per_block[annotation.unique_id]
            end
            constrs = ConstrDict()
            if haskey(constrs_per_block, annotation.unique_id)
                constrs = constrs_per_block[annotation.unique_id]
            end
            println("> build sp $(annotation.unique_id)")
            build_dw_pricing_sp!(prob, annotation.unique_id,
                                 formulations[annotation.unique_id],
                                 vars, constrs)
        end
    end
    
 
    # Build Master
    @show master_unique_id
    vars = VarDict()
    if haskey(vars_per_block, master_unique_id)
        vars = vars_per_block[master_unique_id]
    end
    constrs = ConstrDict()
    if haskey(constrs_per_block, master_unique_id)
        constrs = constrs_per_block[master_unique_id]
    end
    build_dw_master!(prob, master_unique_id, reformulation,
                     master_form, vars, constrs)
   #end_clone(master_form)
    
    println("\e[1;34m MASTER FORMULATION \e[00m")
    @show master_form
    println("\e[1;34m PRICING SP FORMULATIONS \e[00m")
    for p in reformulation.dw_pricing_subprs
        #end_clone(p)
        @show p
        println("\e[32m ---------------- \e[00m")
    end

    return
end


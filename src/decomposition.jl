set_glob_art_var(f::Formulation, is_pos::Bool) = setvar!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var"),
    MasterArtVar; cost = (getobjsense(f) == MinSense ? 100000.0 : -100000.0),
    lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
)

function initialize_local_art_vars(master::Formulation,
                                   constrs_in_form)
    matrix = getcoefmatrix(master)
    for (constr_id, constr) in constrs_in_form
        v = setvar!(
            master, string("local_art_of_", getname(constr)),
            MasterArtVar;
            cost = (getobjsense(master) == MinSense ? 10000.0 : -10000.0),
            lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
        )
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(v)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(v)] = -1.0
        end
    end
    return
end

function initialize_global_art_vars(master::Formulation)
    global_pos = set_glob_art_var(master, true)
    global_neg = set_glob_art_var(master, false)
    matrix = getcoefmatrix(master)
    constrs = filter(_active_master_rep_orig_constr_, getconstrs(master))
    for (constr_id, constr) in constrs
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(global_pos)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(global_neg)] = -1.0
        end
    end
end

function initialize_artificial_variables(master::Formulation, constrs_in_form)
    # if (_params_.art_vars_mode == Local)
        initialize_local_art_vars(master, constrs_in_form)
    # elseif (_params_.art_vars_mode == Global)
        initialize_global_art_vars(master)
    # end
end

function find_vcs_in_block(uid::Int, annotations::Annotations)
    vars_per_block = annotations.vars_per_block 
    vars = VarDict()
    if haskey(vars_per_block, uid)
        vars = vars_per_block[uid]
    end
    constrs_per_block = annotations.constrs_per_block 
    constrs = ConstrDict()
    if haskey(constrs_per_block, uid)
        constrs = constrs_per_block[uid]
    end
    return vars, constrs
end

function build_dw_master!(prob::Problem,
                          annotation_id::Int,
                          reformulation::Reformulation,
                          master_form::Formulation,
                          vars_in_form::VarDict,
                          constrs_in_form::ConstrDict,
                          opt_builder::Function)

    orig_form = get_original_formulation(prob)
    reformulation.dw_pricing_sp_lb = Dict{FormId, Id}()
    reformulation.dw_pricing_sp_ub = Dict{FormId, Id}()
    convexity_constrs = ConstrDict()


    # copy of pure master variables
    clone_in_formulation!(master_form, orig_form, vars_in_form, MasterPureVar)

    mast_coefficient_matrix = getcoefmatrix(master_form)
    
    @assert !isempty(reformulation.dw_pricing_subprs)
    # add convexity constraints and setupvar 
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)
 
        # create convexity constraint
        name = "sp_lb_$(sp_uid)"
        sense = Greater
        rhs = 0.0
        kind = Core
        duty = MasterConvexityConstr  
        lb_conv_constr = setconstr!(master_form, name, duty;
                                     rhs = rhs, kind  = kind,
                                     sense = sense)
        reformulation.dw_pricing_sp_lb[sp_uid] = getid(lb_conv_constr)
        setincval!(getrecordeddata(lb_conv_constr), 100.0)
        setincval!(getcurdata(lb_conv_constr), 100.0)
        convexity_constrs[getid(lb_conv_constr)] = lb_conv_constr

        name = "sp_ub_$(sp_uid)"
        rhs = 1.0
        sense = Less
        ub_conv_constr = setconstr!(master_form, name, duty;
                                     rhs = rhs, kind = kind,
                                     sense = sense)
        reformulation.dw_pricing_sp_ub[sp_uid] = getid(ub_conv_constr)
        setincval!(getrecordeddata(ub_conv_constr), 100.0)
        setincval!(getcurdata(ub_conv_constr), 100.0)        
        convexity_constrs[getid(ub_conv_constr)] = ub_conv_constr

        ## add all Sp var in master
        vars = filter(_active_pricing_sp_var_, getvars(sp_form))
        is_explicit = false
        clone_in_formulation!(master_form, sp_form, vars, MasterRepPricingVar, is_explicit)

        ## Create PricingSetupVar
        name = "PricingSetupVar_sp_$(sp_form.uid)"
        cost = 0.0
        lb = 1.0
        ub = 1.0
        kind = Continuous
        duty = DwSpSetupVar
        sense = Positive
        is_explicit = true
        setup_var = setvar!(
            sp_form, name, duty; cost = cost, lb = lb, ub = ub, kind = kind,
            sense = sense, is_explicit = is_explicit
        )
        clone_in_formulation!(master_form, sp_form, setup_var, MasterRepPricingSetupVar, false)

        ## add setup var coef in convexity constraint
        matrix = getcoefmatrix(master_form)
        mast_coefficient_matrix[getid(lb_conv_constr),getid(setup_var)] = 1.0
        mast_coefficient_matrix[getid(ub_conv_constr),getid(setup_var)] = 1.0
    end

    # copy of master constraints
    clone_in_formulation!(master_form, orig_form, constrs_in_form, MasterMixedConstr)

    # add artificial var 
    initialize_artificial_variables(master_form, constrs_in_form)
    initialize_local_art_vars(master_form, convexity_constrs)
    initialize_optimizer!(master_form, opt_builder)
    return
end

function build_benders_master!()

end

function build_dw_pricing_sp!(prob::Problem,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::VarDict,
                              constrs_in_form::ConstrDict,
                              opt_builder::Function)

    orig_form = get_original_formulation(prob)
    master_form = sp_form.parent_formulation
    reformulation = master_form.parent_formulation
    ## Create Pure Pricing Sp Var & constr
    clone_in_formulation!(sp_form, orig_form, vars_in_form, DwSpPricingVar)
    clone_in_formulation!(sp_form, orig_form, constrs_in_form, DwSpPureConstr)
    initialize_optimizer!(sp_form, opt_builder)
    return
end

function build_benders_sep_sp!(prob::Problem,
                               annotation_id::Int,
                               sp_form::Formulation,
                               vars_in_form::VarDict,
                               constrs_in_form::ConstrDict)
    orig_form = get_original_formulation(prob)
    master_form = sp_form.parent_formulation
    reformulation = master_form.parent_formulation
    ## Create pure Sp benders vars & constr
    clone_in_formulation!(sp_form, orig_form, vars_in_form, BendersSepSpVar)
    clone_in_formulation!(sp_form, orig_form, constrs_in_form, BendersSepSpPureConstr)
end

function instanciatemaster!(prob::Problem, reform, ::Type{BD.Master}, ::Type{BD.DantzigWolfe})
    form = Formulation{DwMaster}(
        prob.form_counter; parent_formulation = reform,
        obj_sense = getobjsense(get_original_formulation(prob))
    )
    setmaster!(reform, form)
    return form
end

function instanciatemaster!(prob::Problem, reform, ::Type{BD.Master}, ::Type{BD.Benders})
    error("TODO.")
end

function createmaster!(form, prob::Problem, reform, ann, annotations, ::Type{BD.Master}, ::Type{BD.DantzigWolfe})
    vars, constrs = find_vcs_in_block(BD.getid(ann), annotations)
    opt_builder = prob.default_optimizer_builder
    if BD.getoptimizerbuilder(ann) != nothing
        opt_builder = BD.getoptimizerbuilder(ann)
    end
    build_dw_master!(prob, BD.getid(ann), reform, form, vars, constrs, opt_builder)
end

function createmaster!(form, prob::Problem, reform, ann, annotations, ::Type{BD.Master}, ::Type{BD.Benders})
    error("TODO")
end

function createsp!(prob::Problem, reform, mast, ann, annotations, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe})
    form = Formulation{DwSp}(
        prob.form_counter; parent_formulation = mast,
        obj_sense = getobjsense(mast)
    )
    add_dw_pricing_sp!(reform, form)

    vars, constrs = find_vcs_in_block(BD.getid(ann), annotations)
    opt_builder = prob.default_optimizer_builder
    if BD.getoptimizerbuilder(ann) != nothing
        opt_builder = BD.getoptimizerbuilder(ann)
    end
    build_dw_pricing_sp!(prob, BD.getid(ann), form, vars, constrs, opt_builder)
    return form
end

function createsp!(prob::Problem, reform, mast, ann, annotations, ::Type{BD.BendersSepSp}, ::Type{BD.Benders})
    error("TODO")
end

function registerformulations!(prob::Problem, annotations::Annotations, reform, 
                               parent, node::BD.Root)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    form = instanciatemaster!(prob, reform, form_type, dec_type)
    for (id, child) in BD.subproblems(node)
        registerformulations!(prob, annotations, reform, node, child)
    end
    createmaster!(form, prob, reform, ann, annotations, form_type, dec_type)
    return
end

function registerformulations!(prob::Problem, annotations::Annotations, reform, 
                               parent, node::BD.Leaf)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    mast = getmaster(reform)
    createsp!(prob, reform, mast, ann, annotations, form_type, dec_type)
    return
end

function reformulate!(prob::Problem, annotations::Annotations, 
                      strategy::GlobalStrategy)
    vars_per_block = annotations.vars_per_block 
    constrs_per_block = annotations.constrs_per_block
    annotation_set = annotations.annotation_set 
    decomposition_tree = annotations.tree

    root = BD.getroot(decomposition_tree)

    # Create reformulation
    reform = Reformulation(prob, strategy)
    set_re_formulation!(prob, reform)
    registerformulations!(prob, annotations, reform, reform, root)
end
set_glob_art_var(f::Formulation, is_pos::Bool) = setvar!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var"),
    MastArtVar; cost = 100000.0, lb = 0.0, ub = Inf,
    kind = Continuous, sense = Positive
)

function initialize_local_art_vars(master::Formulation,
                                   constrs_in_form)
    matrix = getcoefmatrix(master)
    for (constr_id, constr) in constrs_in_form
        v = setvar!(
            master, string("local_art_of_", getname(constr)),
            MastArtVar; cost = 10000.0, lb = 0.0, ub = Inf,
# cost = getincval(constr), lb = 0.0, ub = Inf,
            kind = Continuous, sense = Positive
        )
        matrix[constr_id, getid(v)] = 1.0
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

function find_vcs_in_block(uid::Int, vars_per_block::Dict{Int,VarDict},
                           constrs_per_block::Dict{Int,ConstrDict})
    vars = VarDict()
    if haskey(vars_per_block, uid)
        vars = vars_per_block[uid]
    end
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
                          constrs_in_form::ConstrDict)

    orig_form = get_original_formulation(prob)
    reformulation.dw_pricing_sp_lb = Dict{FormId, Id}()
    reformulation.dw_pricing_sp_ub = Dict{FormId, Id}()
    convexity_constrs = ConstrDict()
    # copy of pure master variables
    clone_in_formulation!(master_form, orig_form, vars_in_form, PureMastVar)

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
        duty = MasterConvexityConstr  #MasterConstr #MasterConvexityConstr
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
        clone_in_formulation!(master_form, sp_form, vars, MastRepPricingSpVar, is_explicit)

        ## Create PricingSetupVar
        name = "PricingSetupVar_sp_$(sp_form.uid)"
        cost = 0.0
        lb = 1.0
        ub = 1.0
        kind = Continuous
        duty = PricingSpSetupVar
        sense = Positive
        is_explicit = true
        setup_var = setvar!(
            sp_form, name, duty; cost = cost, lb = lb, ub = ub, kind = kind,
            sense = sense, is_explicit = is_explicit
        )
        clone_in_formulation!(master_form, sp_form, setup_var, MastRepPricingSetupSpVar, false)

        ## add setup var coef in convexity constraint
        matrix = getcoefmatrix(master_form)
        mast_coefficient_matrix[getid(lb_conv_constr),getid(setup_var)] = 1.0
        mast_coefficient_matrix[getid(ub_conv_constr),getid(setup_var)] = 1.0
    end

    # copy of master constraints
    clone_in_formulation!(master_form, orig_form, constrs_in_form, MasterConstr)

    # add artificial var 
    initialize_artificial_variables(master_form, constrs_in_form)
    initialize_local_art_vars(master_form, convexity_constrs)
    return
end

function build_dw_pricing_sp!(prob::Problem,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::VarDict,
                              constrs_in_form::ConstrDict)

    orig_form = get_original_formulation(prob)
    master_form = sp_form.parent_formulation
    reformulation = master_form.parent_formulation
    ## Create Pure Pricing Sp Var & constr
    clone_in_formulation!(sp_form, orig_form, vars_in_form, PricingSpVar)
    clone_in_formulation!(sp_form, orig_form, constrs_in_form, PricingSpPureConstr)
    return
end

function reformulate!(prob::Problem, annotations::Annotations,
                      strategy::GlobalStrategy)
    # This function must be cleaned.
    # subproblem formulations are modified in the function build_dw_master


    # Create formulations & reformulations

    
 
    # At the moment, BlockDecomposition supports only classic 
    # Dantzig-Wolfe decomposition.
    # TODO : improve all drafts as soon as BlockDecomposition returns a
    # decomposition-tree.

    vars_per_block = annotations.vars_per_block 
    constrs_per_block = annotations.constrs_per_block
    annotation_set = annotations.annotation_set 
  
    # Create reformulation
    reformulation = Reformulation(prob, strategy)
    set_re_formulation!(prob, reformulation)

    # Create master formulation
    master_form = Formulation{DwMaster}(
        prob.form_counter; parent_formulation = reformulation,
        moi_optimizer = prob.master_factory()
    )
    setmaster!(reformulation, master_form)

    # Create pricing subproblem formulations
    ann_sorted_by_uid = sort(collect(annotation_set), by = ann -> ann.unique_id)
    
    formulations = Dict{Int, Formulation}()
    master_unique_id = -1

    for annotation in ann_sorted_by_uid
        if BD.getformulation(annotation) == BD.Master
            master_unique_id = BD.getid(annotation)
            formulations[BD.getid(annotation)] = master_form
        elseif BD.getformulation(annotation) == BD.DwPricingSp
            f = Formulation{DwSp}(
                prob.form_counter; parent_formulation = master_form,
                moi_optimizer = prob.pricing_factory()
            )
            formulations[BD.getid(annotation)] = f
            add_dw_pricing_sp!(reformulation, f)
        else 
            error(string("Subproblem type ", BD.getformulation(annotation),
                         " not supported yet."))
        end
    end

    # Build Pricing Sp
    for annotation in ann_sorted_by_uid
        if BD.getformulation(annotation) == BD.DwPricingSp
            vars, constrs = find_vcs_in_block(
                BD.getid(annotation), vars_per_block, constrs_per_block
            )
            build_dw_pricing_sp!(prob, BD.getid(annotation),
                                 formulations[BD.getid(annotation)],
                                 vars, constrs)
        end
    end

    # Build Master
    vars, constrs = find_vcs_in_block(
        master_unique_id, vars_per_block, constrs_per_block
    )
    build_dw_master!(prob, master_unique_id, reformulation,
                     master_form, vars, constrs)

    @debug "\e[1;34m Master formulation \e[00m" master_form
    for sp_form in reformulation.dw_pricing_subprs
        @debug "\e[1;34m Pricing subproblems formulation \e[00m" sp_form
    end
    return
end


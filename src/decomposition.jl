set_glob_art_var(f::Formulation, is_pos::Bool) = setvar!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var"),
    MastArtVar; cost = (getobjsense(f) == MinSense ? 100000.0 : -100000.0),
    lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
)

function initialize_local_art_vars(master::Formulation,
                                   constrs_in_form)
    matrix = getcoefmatrix(master)
    for (constr_id, constr) in constrs_in_form
        v = setvar!(
            master, string("local_art_of_", getname(constr)),
            MastArtVar;
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

function find_vcs_in_block(uid::Int,
                           vars_per_block::Dict{Int,VarDict},
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

function build_master!(prob::Problem,
                       annotation_id::Int,
                       reformulation::Reformulation,
                       master_form::Formulation,
                       vars_in_form::VarDict,
                       constrs_in_form::ConstrDict)

    orig_form = get_original_formulation(prob)
    reformulation.dw_sp_lb_convexity_constr_id = Dict{FormId, Id}()
    reformulation.dw_sp_ub_convexity_constr_id = Dict{FormId, Id}()
    convexity_constrs = ConstrDict()
    # copy of pure master variables

    mast_form_uid = getuid(master_form)
    orig_coefficient_matrix = getcoefmatrix(orig_form)

    
    pure_mast_vars = VarDict()
    non_pure_mast_vars = VarDict()
    for id_var in vars_in_form
        constr_membership = orig_coefficient_matrix[:,id_var[1]]
        non_pure_constr_membership = filter(c->(getformuid(c) != mast_form_uid), constr_membership)
        if (length(non_pure_constr_membership) > 0)
            push!(non_pure_mast_vars, id_var)
        else
            push!(pure_mast_vars, id_var)
        end
    end
    clone_in_formulation!(master_form, orig_form, pure_mast_vars, MasterPureVar)
    clone_in_formulation!(master_form, orig_form, non_pure_mast_vars, BendersFirstStageVar)
    
    
    pure_mast_constrs = ConstrDict()
    non_pure_mast_constrs = ConstrDict()
    for id_constr in constrs_in_form
        var_membership = orig_coefficient_matrix[id_constr[1],:]
        non_pure_var_membership = filter(v->(getformuid(v) != mast_form_uid), var_membership)
        if (length(non_pure_var_membership) > 0)
            push!(non_pure_mast_constrs, id_constr)
        else
            push!(pure_mast_constrs, id_constr)
        end
    end
    clone_in_formulation!(master_form, orig_form, pure_mast_constrs, MasterPureConstr)
    clone_in_formulation!(master_form, orig_form, non_pure_mast_constrs, MasterConstr)

    mast_coefficient_matrix = getcoefmatrix(master_form)
    
    has_pricing_sp = length(reformulation.dw_pricing_subprs) > 0
    has_benders_sp = length(reformulation.benders_sep_subprs) > 0
    
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
        reformulation.dw_sp_lb_convexity_constr_id[sp_uid] = getid(lb_conv_constr)
        setincval!(getrecordeddata(lb_conv_constr), 100.0)
        setincval!(getcurdata(lb_conv_constr), 100.0)
        convexity_constrs[getid(lb_conv_constr)] = lb_conv_constr

        name = "sp_ub_$(sp_uid)"
        rhs = 1.0
        sense = Less
        ub_conv_constr = setconstr!(master_form, name, duty;
                                     rhs = rhs, kind = kind,
                                     sense = sense)
        reformulation.dw_sp_ub_convexity_constr_id[sp_uid] = getid(ub_conv_constr)
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

    # add SpArtVar and master SecondStageCostVar 
    for sp_form in reformulation.benders_sep_subprs
        sp_uid = getuid(sp_form)
 
        ## add all Sp var in master SecondStageCostConstr
        vars = filter(_active_benders_sp_var_, getvars(sp_form))
        second_stage_cost_exist = false

        ## Identify whether there is a second stage cost
        for var in vars
            cost = getperenecost(var)
            if cost > 0.000001
                second_stage_cost_exist = true
                break
            end
            if cost < - 0.000001
                second_stage_cost_exist = true
                break
            end
            
        end
        
        if (second_stage_cost_exist)
            # create SecondStageCostVar
            name = "cv_sp_$(sp_uid)"
            cost = 1.0
            lb = 0.0
            ub = 1.0
            kind = Continuous
            duty =  BendersSecondStageCostVar
            sense = Positive
            is_explicit = true
            second_stage_cost_var = setvar!(
                master_form, name, duty; cost = cost, lb = lb, ub = ub, kind = kind,
                sense = sense, is_explicit = is_explicit
            )
            clone_in_formulation!(sp_form, master_form, second_stage_cost_var, BendersSepRepSecondStageCostVar, false)


            # create SecondStageCostConstr
            name = "cc_sp_$(sp_uid)"
            duty =  BendersSepSecondStageCostConstr
            rhs = 0.0
            kind = Core
            sense = (getobjsense(orig_form) == MinSense ? Greater : Less)
            second_stage_cost_constr = setconstr!(sp_form, name, duty;
                                                  rhs = rhs, kind = kind,
                                                  sense = sense)
            mast_coefficient_matrix[getid(second_stage_cost_constr),getid(second_stage_cost_var)] = 1.0


            for var in vars
                cost = getperenecost(var)
                mast_coefficient_matrix[getid(second_stage_cost_constr),getid(var)] = - cost
                setperenecost!(var, 0.0)
                setcurcost!(var, 0.0)
                setcost!(sp_form, var, 0.0)
            end
            

        end


        pure_sp_constrs::ConstrDict()
        non_pure_sp_constrs::ConstrDict()
        sp_form_uid = getuid(sp_form)
        for constr in getconstrs(sp_form)
            var_membership = orig_coefficient_matrix[getid(constr),:]
            non_pure_var_membership = filter(id_v->(getformuid(id_v[1]) != sp_form_uid), var_membership)
            if (length(non_pure_var_membership) > 0)
                push!(non_pure_sp_constrs, constr)
            else
                push!(pure_sp_constrs, constr)
            end
        end
        clone_in_formulation!(sp_form, orig_form, pure_mast_constrs, BendersPureSepConstr)
        clone_in_formulation!(sp_form, orig_form, non_pure_mast_constrs, BendersFeasibilityTechnologicalConstr)          

        
        is_explicit = true
        clone_in_formulation!(sp_form, orig_form, vars, BendersSepVar, is_explicit)

     end

 
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

function build_benders_sep_sp!(prob::Problem,
                              annotation_id::Int,
                              sp_form::Formulation,
                              vars_in_form::VarDict,
                              constrs_in_form::ConstrDict)

    orig_form = get_original_formulation(prob)
    master_form = sp_form.parent_formulation
    reformulation = master_form.parent_formulation
    ## Create Pure Pricing Sp Var & constr
    clone_in_formulation!(sp_form, orig_form, vars_in_form, BendersSepSpVar)
    clone_in_formulation!(sp_form, orig_form, constrs_in_form, BendersSepSpPureConstr)
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
        obj_sense = getobjsense(get_original_formulation(prob)),
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
                obj_sense = getobjsense(master_form),
                moi_optimizer = prob.pricing_factory()
            )
            formulations[BD.getid(annotation)] = f
            add_dw_pricing_sp!(reformulation, f)
        elseif BD.getformulation(annotation) == BD.BendersSepSp
            f = Formulation{BsSp}(
                prob.form_counter; parent_formulation = master_form,
                moi_optimizer = prob.benders_sep_factory()
            )
            formulations[annotation.unique_id] = f
            add_benders_sep_sp!(reformulation, f)
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
        elseif BD.getformulation(annotation) == BD.BendersSepSp
            vars, constrs = find_vcs_in_block(
                annotation.unique_id, Spvars_per_block, constrs_per_block
            )
            build_benders_sep_sp!(prob, annotation.unique_id,
                                 formulations[annotation.unique_id],
                                 vars, constrs)
        end
    end

    # Build Master
    vars, constrs = find_vcs_in_block(
        master_unique_id, vars_per_block, constrs_per_block
    )
    build_master!(prob, master_unique_id, reformulation,
                     master_form, vars, constrs)

    @debug "\e[1;34m Master formulation \e[00m" master_form
    for sp_form in reformulation.dw_pricing_subprs
        @debug "\e[1;34m Pricing subproblems formulation \e[00m" sp_form
    end
    return
end


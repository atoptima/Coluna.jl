set_loc_art_var(f::Formulation, constr_id::ConstrId) = set_var!(
    f, string("local_art_", constr_id), MastArtVar; cost = 10.0,
    lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
)

set_glob_art_var(f::Formulation, is_pos::Bool) = set_var!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var_"),
    MastArtVar; cost = 1000.0, lb = 0.0, ub = Inf,
    kind = Continuous, sense = Positive
)

function initialize_local_art_vars(master::Formulation,
                                   constrs_in_form)
    matrix = get_coefficient_matrix(master)
    for (constr_id, constr) in constrs_in_form
        v = set_var!(
            master, string("local_art_", constr_id),
            MastArtVar; cost = get_inc_val(constr), lb = 0.0, ub = Inf,
            kind = Continuous, sense = Positive
        )
        matrix[constr_id, get_id(v)] = 1.0
    end
    return
end

function initialize_global_art_vars(master::Formulation)
    global_pos = set_glob_art_var(master, true)
    global_neg = set_glob_art_var(master, false)
    matrix = get_coefficient_matrix(master)
    constrs = filter(_active_masterRepOrigConstr_,get_constrs(master))
    for (constr_id, constr) in constrs
        if get_sense(get_cur_data(constr)) == Greater
            matrix[constr_id, get_id(global_pos)] = 1.0
        elseif get_sense(get_cur_data(constr)) == Less
            matrix[constr_id, get_id(global_neg)] = -1.0
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

    # copy of pure master variables
    clone_in_formulation!(master_form, orig_form, vars_in_form, PureMastVar)

    @assert !isempty(reformulation.dw_pricing_subprs)
    # add convexity constraints and setupvar 
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = get_uid(sp_form)
 
        # create convexity constraint
        name = "sp_lb_$(sp_uid)"
        sense = Greater
        rhs = 0.0
        kind = Core
        duty = MasterConvexityConstr  #MasterConstr #MasterConvexityConstr
        lb_conv_constr = set_constr!(master_form, name, duty;
                                     rhs = rhs, kind  = kind,
                                     sense = sense)
        reformulation.dw_pricing_sp_lb[sp_uid] = get_id(lb_conv_constr)
        # @show lb_conv_constr

        name = "sp_ub_$(sp_uid)"
        rhs = 1.0
        sense = Less
        ub_conv_constr = set_constr!(master_form, name, duty;
                                     rhs = rhs, kind = kind,
                                     sense = sense)
        reformulation.dw_pricing_sp_ub[sp_uid] = get_id(ub_conv_constr)
        # @show ub_conv_constr

        ## Create PricingSetupVar
        name = "PricingSetupVar_sp_$(sp_form.uid)"
        cost = 0.0
        lb = 1.0
        ub = 1.0
        kind = Continuous
        duty = PricingSpSetupVar
        sense = Positive
        is_explicit = true
        setup_var = set_var!(sp_form, name, duty; cost = cost,
                             lb = lb, ub = ub, kind = kind,
                             sense = sense, is_explicit = is_explicit)
        @show setup_var
        vars = filter(_active_pricingSpVar_, get_vars(sp_form))

        is_explicit = false
        clone_in_formulation!(master_form, sp_form, vars, MastRepPricingSpVar, is_explicit)
    end

    # copy of master constraints
    clone_in_formulation!(master_form, orig_form, constrs_in_form, MasterConstr)

    # add artificial var 
    initialize_artificial_variables(master_form, constrs_in_form)
    @show master_form
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
   # @show constrs_in_form
   # @show vars_in_form

   # @show sp_form.manager

    # for (constr_id, members) in rows(get_coefficient_matrix(sp_form))
    #     @show constr_id
    #     @show get_constr(sp_form, constr_id)
    # end



    @show sp_form
    return
end

function reformulate!(prob::Problem, method::SolutionMethod)
    println("Do reformulation.")

    # This function must be cleaned.
    # subproblem formulations are modified in the function build_dw_master


    # Create formulations & reformulations

    
 
    # At the moment, BlockDecomposition supports only classic 
    # Dantzig-Wolfe decomposition.
    # TODO : improve all drafts as soon as BlockDecomposition returns a
    # decomposition-tree.

    vars_per_block = prob.optimizer.annotations.vars_per_block 
    constrs_per_block = prob.optimizer.annotations.constrs_per_block
    annotation_set = prob.optimizer.annotations.annotation_set 
    
    #@show vars_per_block
    #@show constrs_per_block
    
    # Create reformulation
    reformulation = Reformulation(prob, method)
    set_re_formulation!(prob, reformulation)

    # Create master formulation
    master_form = Formulation{DwMaster}(
        prob.form_counter; parent_formulation = reformulation,
        moi_optimizer = prob.master_factory()
    )
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
            f = Formulation{DwSp}(
                prob.form_counter; parent_formulation = master_form,
                moi_optimizer = prob.pricing_factory()
            )
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
        if annotation.problem == BD.Pricing
            vars, constrs = find_vcs_in_block(
                annotation.unique_id, vars_per_block, constrs_per_block
            )
            println("> build sp $(annotation.unique_id)")
            build_dw_pricing_sp!(prob, annotation.unique_id,
                                 formulations[annotation.unique_id],
                                 vars, constrs)
        end
    end

    # Build Master
    @show master_unique_id
    vars, constrs = find_vcs_in_block(
        master_unique_id, vars_per_block, constrs_per_block
    )
    build_dw_master!(prob, master_unique_id, reformulation,
                     master_form, vars, constrs)

    println("\e[1;34m MASTER FORMULATION \e[00m")
    @show master_form
    println("\e[1;34m PRICING SP FORMULATIONS \e[00m")
    for p in reformulation.dw_pricing_subprs
         @show p
        println("\e[32m ---------------- \e[00m")
    end
    return
end


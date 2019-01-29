@hl mutable struct AlgToPreprocessNode <: AlgLike
    extended_problem::ExtendedProblem
    constr_in_stack::Dict{Constraint,Bool}
    stack::DS.Stack{Constraint}
    var_local_master_membership::Dict{Variable,Vector{Tuple{Constraint,Float}}}
    var_local_sp_membership::Dict{Variable,Vector{Tuple{Constraint,Float}}}
    nb_inf_sources_for_min_slack::Dict{Constraint,Int}
    nb_inf_sources_for_max_slack::Dict{Constraint,Int}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
end

function AlgToPreprocessNodeBuilder(extended_problem::ExtendedProblem)
    return (extended_problem, Dict{Constraint,Bool}(), DS.Stack{Constraint}(), 
            Dict{Variable,Vector{Tuple{Constraint,Float}}}(), Dict{Variable,Vector{Tuple{Constraint,Float}}}(),
            Dict{Constraint,Int}(), Dict{Constraint,Int}(), Constraint[], Variable[])
end

function run(alg::AlgToPreprocessNode, node::Node)
    reset(alg)
    if initialize(alg, node)
        return true
    end
    infeas = propagation(alg) 
    # print_preprocessing_list(alg)
    return infeas
end

function print_preprocessing_list(alg::AlgToPreprocessNode)
    println("vars preprocessed:")
    for var in alg.preprocessed_vars
        println("var $(var.vc_ref)")
    end
end

function add_to_preprocessing_list(alg::AlgToPreprocessNode, var::Variable)
    if !(var in alg.preprocessed_vars)
        push!(alg.preprocessed_vars, var)
    end
end

function add_to_preprocessing_list(alg::AlgToPreprocessNode, constr::Constraint)
    if !(constr in alg.preprocessed_constrs)
        push!(alg.preprocessed_constrs, constr)
    end
end

function add_to_stack(alg::AlgToPreprocessNode, constr::Constraint)
    if !alg.constr_in_stack[constr]
        push!(alg.stack, constr)
        alg.constr_in_stack[constr] = true
    end
end
      
function reset(alg::AlgToPreprocessNode)
    empty!(alg.constr_in_stack)
    empty!(alg.preprocessed_vars)
    empty!(alg.preprocessed_constrs)
    empty!(alg.var_local_master_membership)
    empty!(alg.var_local_sp_membership)
    empty!(alg.nb_inf_sources_for_min_slack)
    empty!(alg.nb_inf_sources_for_max_slack)
end

#in root node, we start propagation from all constraints
#if node is not root node, we start propagation only from local branching constrs
function initialize(alg::AlgToPreprocessNode, node::Node)

    constrs_to_stack = Constraint[]

    master = alg.extended_problem.master_problem
    for constr in master.constr_manager.active_static_list
        if !isa(constr, ConvexityConstr)
            initialize_constraint(alg, constr)
            if node.depth == 0
                push!(constrs_to_stack, constr)
            end
        end
    end

    for constr in master.constr_manager.active_dynamic_list
        initialize_constraint(alg, constr)
        if node.depth == 0
            push!(constrs_to_stack, constr)
        end
    end

    for subprob in alg.extended_problem.pricing_vect
        for constr in subprob.constr_manager.active_static_list
            initialize_constraint(alg, constr)
            if node.depth == 0
                push!(constrs_to_stack, constr)
            end
        end
    end

    if node.depth > 0
        for constr in node.local_branching_constraints
            initialize_constraint(alg, constr)
        end
        constrs_to_stack = node.local_branching_constraints
    end

    #adding constraints to stack
    for constr in constrs_to_stack
        if update_min_slack(alg, constr, false, 0.0) || update_max_slack(alg, constr, false, 0.0)
            return true
        end
    end

    return false
end

function initialize_constraint(alg::AlgToPreprocessNode, constr::Constraint)
    alg.constr_in_stack[constr] = false
    update_local_membership(alg, constr)
    alg.nb_inf_sources_for_min_slack[constr] = 0
    alg.nb_inf_sources_for_max_slack[constr] = 0
    compute_min_slack(alg, constr)
    compute_max_slack(alg, constr)
 #   print_constr(constr)
end

function update_local_membership(alg::AlgToPreprocessNode, constr::MasterConstr)
    for map in [constr.member_coef_map, constr.subprob_var_coef_map]
        for (var, coef) in map
            if !haskey(alg.var_local_master_membership, var)
                alg.var_local_master_membership[var] = [(constr, coef)]
            else
                push!(alg.var_local_master_membership[var], (constr, coef))
            end
        end
    end
end

function update_local_membership(alg::AlgToPreprocessNode, constr::Constraint)
    for (var, coef) in constr.member_coef_map
        if !haskey(alg.var_local_sp_membership, var)
            alg.var_local_sp_membership[var] = [(constr, coef)]
        else
            push!(alg.var_local_sp_membership[var], (constr, coef))
        end
    end
end
 
function print_constr(constr::Constraint)
    println("constr $(constr.vc_ref) $(typeof(constr)): master")
   for (var, coeff) in constr.member_coef_map
       println(var.vc_ref, " ", coeff, " ", var.flag)
   end
   if isa(constr, MasterConstr)
       println("constr $(constr.vc_ref): subprob")
       for (sp_var, coeff) in constr.subprob_var_coef_map
           println(sp_var.vc_ref, " ", coeff, " ", sp_var.flag, " ", sp_var.cur_lb, " ", sp_var.cur_ub, " ", sp_var.cur_global_lb, " ", sp_var.cur_global_ub)
       end
   end
   println("cur_min $(constr.cur_min_slack) cur_max $(constr.cur_max_slack)")
end

function compute_min_slack(alg::AlgToPreprocessNode, constr::Constraint)
    slack = constr.cost_rhs
    for (var, coef) in constr.member_coef_map
        if var.flag != 's'
            continue
        end
        if coef > 0
            if var.cur_ub == Inf
                alg.nb_inf_sources_for_min_slack[constr] += 1
            else
                slack -= coef*var.cur_ub
            end
        else
            if var.cur_lb == -Inf
                alg.nb_inf_sources_for_min_slack[constr] += 1
            else
                slack -= coef*var.cur_lb
            end
        end
    end
    constr.cur_min_slack = slack
end

function compute_max_slack(alg::AlgToPreprocessNode, constr::Constraint)
    slack = constr.cost_rhs
    for (var, coef) in constr.member_coef_map
        if var.flag != 's'
            continue
        end
        if coef > 0
            if var.cur_lb == -Inf
                alg.nb_inf_sources_for_max_slack[constr] += 1
            else
                slack -= coef*var.cur_lb
            end
        else
            if var.cur_ub == Inf
                alg.nb_inf_sources_for_max_slack[constr] += 1
            else
                slack -= coef*var.cur_ub
            end
        end
    end
    constr.cur_max_slack = slack
end

function compute_min_slack(alg::AlgToPreprocessNode, constr::MasterConstr)
    @callsuper compute_min_slack(alg, constr::Constraint)

    #subprob variables
    for (sp_var, coef) in constr.subprob_var_coef_map
        if coef < 0
            if sp_var.cur_global_lb == -Inf
                alg.nb_inf_sources_for_min_slack[constr] += 1
            else
                constr.cur_min_slack -= coef*sp_var.cur_global_lb
            end
        else
           if sp_var.cur_global_ub == Inf
                alg.nb_inf_sources_for_min_slack[constr] += 1
            else
                constr.cur_min_slack -= coef*sp_var.cur_global_ub
            end
        end
    end
end

function compute_max_slack(alg::AlgToPreprocessNode, constr::MasterConstr)
    @callsuper compute_max_slack(alg, constr::Constraint)

    #subprob variables
    for (sp_var, coef) in constr.subprob_var_coef_map
        if coef > 0
            if sp_var.cur_global_lb == -Inf
                alg.nb_inf_sources_for_max_slack[constr] += 1
            else
                constr.cur_max_slack -= coef*sp_var.cur_global_lb
            end
        else
           if sp_var.cur_global_ub == Inf
                alg.nb_inf_sources_for_max_slack[constr] += 1
            else
                constr.cur_max_slack -= coef*sp_var.cur_global_ub
            end
        end
    end
end

function update_max_slack(alg::AlgToPreprocessNode, constr::Constraint, var_was_inf_source::Bool, delta::Float)
    constr.cur_max_slack += delta
    if var_was_inf_source
        alg.nb_inf_sources_for_max_slack[constr] -= 1
    end

    nb_inf_sources = alg.nb_inf_sources_for_max_slack[constr]
    if nb_inf_sources == 0
        if constr.sense != 'G' && constr.cur_max_slack < 0
            return true
        elseif constr.sense != 'L' && constr.cur_max_slack <= 0
            add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if constr.sense != 'G'
            add_to_stack(alg, constr)
        end
    end
    return false
end

function update_min_slack(alg::AlgToPreprocessNode, constr::Constraint, var_was_inf_source::Bool, delta::Float)
    constr.cur_min_slack += delta
    if var_was_inf_source
        alg.nb_inf_sources_for_min_slack[constr] -= 1
    end

    nb_inf_sources = alg.nb_inf_sources_for_min_slack[constr]
    if nb_inf_sources == 0
        if constr.sense != 'L' && constr.cur_min_slack > 0
            return true
        elseif constr.sense != 'G' && constr.cur_min_slack >= 0
            add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if constr.sense != 'L'
            add_to_stack(alg, constr)
        end
    end
    return false
end

function update_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_lb::Float)
    if new_lb > var.cur_global_lb
        if new_lb > var.cur_global_ub
            return true
        end

        diff = var.cur_global_lb == -Inf ? -new_lb : var.cur_global_lb - new_lb
        for (constr, coef) in alg.var_local_master_membership[var]
            func = coef < 0 ? update_min_slack : update_max_slack
            if func(alg, constr, var.cur_global_lb == -Inf , diff*coef)
                return true
            end
        end
  #      println("updating global_lb of sp_var $(var.vc_ref) from $(var.cur_global_lb) to $(new_lb)")
        var.cur_global_lb = new_lb
    end
    return false
end

function update_lower_bound(alg::AlgToPreprocessNode, var::MasterVar, new_lb::Float)
    if new_lb > var.cur_lb
        if new_lb > var.cur_ub
            return true
        end

        diff = var.cur_lb == -Inf ? - new_lb : var.cur_lb - new_lb
        for (constr, coef) in alg.var_local_master_membership[var]
            func = coef < 0 ? update_min_slack : update_max_slack
            if func(alg, constr, var.cur_lb == -Inf, diff*coef)
                return true
            end
        end
   #     println("updating lb of m_var $(var.vc_ref) from $(var.cur_lb) to $(new_lb)")
        var.cur_lb = new_lb
        add_to_preprocessing_list(alg, var)
    end
    return false
end

function update_upper_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_ub::Float)
    if new_ub < var.cur_global_ub
        if new_ub < var.cur_global_lb
            return true
        end

        diff = var.cur_global_ub == Inf ? -new_ub : var.cur_global_ub - new_ub
        for (constr, coef) in alg.var_local_master_membership[var]
            func = coef > 0 ? update_min_slack : update_max_slack
            if func(alg, constr, var.cur_global_ub == Inf, diff*coef)
                return true
            end
        end
    #    println("updating global_ub of sp_var $(var.vc_ref) from $(var.cur_global_ub) to $(new_ub)")
        var.cur_global_ub = new_ub
    end
    return false
end

function update_upper_bound(alg::AlgToPreprocessNode, var::MasterVar, new_ub::Float)
    if new_ub < var.cur_ub
        if new_ub < var.cur_lb
            return true
        end

        diff = var.cur_ub == Inf ? -new_ub : var.cur_ub - new_ub
        for (constr, coef) in alg.var_local_master_membership[var]
            func = coef > 0 ? update_min_slack : update_max_slack
            if func(alg, constr, var.cur_ub == Inf, diff*coef)
                return true
            end
        end
     #   println("updating ub of m_var $(var.vc_ref) from $(var.cur_ub) to $(new_ub)")
        var.cur_ub = new_ub
        add_to_preprocessing_list(alg, var)
    end
    return false
end

function update_global_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_lb::Float)
    if update_lower_bound(alg, var, new_lb)
        return true
    end

    (sp_lb, sp_ub) = get_sp_convexity_bounds(alg.extended_problem, var.prob_ref)
    if update_local_lower_bound(alg, var, var.cur_global_lb - (sp_ub - 1)*var.cur_ub)
        return true
    end
    return false
end

function update_global_upper_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_ub::Float)
    if update_upper_bound(alg, var, new_ub)
        return true
    end

    (sp_lb, sp_ub) = get_sp_convexity_bounds(alg.extended_problem, var.prob_ref)
    if update_local_upper_bound(alg, var, var.cur_global_ub - (sp_lb -1)*var.cur_lb)
        return true
    end
    return false
end

function update_local_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_lb::Float)
    if new_lb > var.cur_lb
        if new_lb > var.cur_ub
            return true
        end

        diff = var.cur_lb == -Inf ? -new_lb : var.cur_lb - new_lb
        for (constr, coef) in alg.var_local_sp_membership[var]
            func = coef < 0 ? update_min_slack : update_max_slack
            if func(alg, constr, var.cur_lb == -Inf, diff*coef)
                return true
            end
        end
      #  println("updating local_lb of sp_var $(var.vc_ref) from $(var.cur_lb) to $(new_lb)")
        var.cur_lb = new_lb
        add_to_preprocessing_list(alg, var)

        (sp_lb, sp_ub) = get_sp_convexity_bounds(alg.extended_problem, var.prob_ref)
        if update_global_lower_bound(alg, var, var.cur_lb * sp_lb)
            return true
        end
        new_local_ub = var.cur_global_ub - (sp_lb - 1) * var.cur_lb
        if update_local_upper_bound(alg, var, new_local_ub)
            return true
        end
    end
    return false
end

function update_local_upper_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_ub::Float)
    if new_ub < var.cur_ub
        if new_ub < var.cur_lb
            return true
        end

        diff = var.cur_ub == Inf ? -new_ub : var.cur_ub - new_ub
        for (constr, coef) in alg.var_local_sp_membership[var]
            func = coef > 0 ? update_min_slack : update_max_slack
            if func(alg, constr, var.cur_ub == Inf, diff*coef)
                return true
            end
        end
       # println("updating local_ub of sp_var $(var.vc_ref) from $(var.cur_ub) to $(new_ub)")
        var.cur_ub = new_ub
        add_to_preprocessing_list(alg, var)

        (sp_lb, sp_ub) = get_sp_convexity_bounds(alg.extended_problem, var.prob_ref)
        if update_global_upper_bound(alg, var, var.cur_ub * sp_ub)
            return true
        end
        new_local_lb = var.cur_global_lb - (sp_ub - 1) * var.cur_ub
        if update_local_lower_bound(alg, var, new_local_lb)
            return true
        end
    end
    return false
end

function adjust_bound(var::Variable, bound::Float, is_upper::Bool)
    if var.vc_type != 'C'
        bound = is_upper ? floor(bound) : ceil(bound)
    end
    return bound
end

function compute_new_var_bound(alg::AlgToPreprocessNode, var::Variable, cur_lb::Float, 
                               cur_ub::Float, coef::Float, constr::Constraint)

    function compute_new_bound(nb_inf_sources::Int, slack::Float, var_contrib_to_slack::Float, 
                           inf_bound::Float)
        if nb_inf_sources == 0
            bound = (slack - var_contrib_to_slack)/coef
        elseif nb_inf_sources == 1 && isinf(var_contrib_to_slack)
            bound = slack/coef 
        else
            bound = inf_bound
        end
        return bound
    end

    if coef > 0 && constr.sense != 'G'
        is_ub = true
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_max_slack[constr], constr.cur_max_slack, 
                                    -coef*cur_lb, Inf))
    elseif coef > 0 && constr.sense != 'L'

        is_ub = false
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_min_slack[constr], constr.cur_min_slack, 
                                    -coef*cur_ub, -Inf))
    elseif coef < 0 && constr.sense != 'G'
        is_ub = false
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_max_slack[constr], constr.cur_max_slack, 
                                    -coef*cur_ub, -Inf))
    else
        is_ub = true
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_min_slack[constr], constr.cur_min_slack, 
                                     -coef*cur_lb, Inf))
    end
end

function analyze_constraint(alg::AlgToPreprocessNode, constr::Constraint)
    for (var, coef) in constr.member_coef_map
        (is_ub, bound) = compute_new_var_bound(alg, var, var.cur_lb, var.cur_ub, coef, constr) 
        if !isinf(bound)
            bound = adjust_bound(var, bound, is_ub)
            func = is_ub ? update_local_upper_bound : update_local_lower_bound
            if func(alg, var, bound)
                return true
            end
        end
    end
    return false
end

function analyze_constraint(alg::AlgToPreprocessNode, constr::MasterConstr)
    # master variables
    for (var, coef) in constr.member_coef_map
        #only static variables are considered
        if var.flag != 's'
            continue
        end

        (is_ub, bound) = compute_new_var_bound(alg, var, var.cur_lb, var.cur_ub, coef, constr) 
        if !isinf(bound)
            bound = adjust_bound(var, bound, is_ub)
            func = is_ub ? update_upper_bound : update_lower_bound
            if func(alg, var, bound)
                return true
            end
        end
    end
    # subprob variables
    for (sp_var, coef) in constr.subprob_var_coef_map
        (is_ub, bound) = compute_new_var_bound(alg, sp_var, sp_var.cur_global_lb, sp_var.cur_global_ub, coef, constr) 
        if !isinf(bound)
            bound = adjust_bound(sp_var, bound, is_ub)
            func = is_ub ? update_global_upper_bound : update_global_lower_bound
            if func(alg, sp_var, bound)
                return true
            end
        end
    end
    return false
end

function propagation(alg)

    while !isempty(alg.stack)

        constr = pop!(alg.stack)
        alg.constr_in_stack[constr] = false
        #println("constr $(constr.vc_ref) $(typeof(constr)) poped")
        if analyze_constraint(alg, constr)
            return true
        end
    end
    return false
end

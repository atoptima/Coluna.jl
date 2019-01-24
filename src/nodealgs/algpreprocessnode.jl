@hl mutable struct AlgToPreprocessNode <: AlgLike
    extended_problem::ExtendedProblem
    constr_in_stack::Dict{Int,Bool}
    stack::DS.Stack{Constraint}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
end

function AlgToPreprocessNodeBuilder(extended_problem::ExtendedProblem)
    return (extended_problem, Dict{Int,Bool}(), DS.Stack{Constraint}(), 
	    Constraint[], Variable[])
end

function run(alg::AlgToPreprocessNode, node::Node)
    reset(alg)
    compute_slacks(alg, node)
    if initialize(alg, node)
	return true
    end
    infeas = propagation(alg) 
    
    #println("preprocessed vars")
    #for var in alg.preprocessed_vars
#	println(var)
 #   end
  #  println("preprocessed constrs")
   # for constr in alg.preprocessed_constrs
#	println(constr)
 #   end
    return infeas
end

function add_to_preprocessing_list(alg, var::Variable)
    if !(var in alg.preprocessed_vars)
	push!(alg.preprocessed_vars, var)
    end
end

function add_to_preprocessing_list(alg, constr::Constraint)
    if !(constr in alg.preprocessed_constrs)
	push!(alg.preprocessed_constrs, constr)
    end
end

function reset(alg::AlgToPreprocessNode)
    empty!(alg.constr_in_stack)
    empty!(alg.preprocessed_vars)
    empty!(alg.preprocessed_constrs)
end

#in root node, we start propagation from all constraints
#if node is not root node, we start propagation only from local branching constrs
function initialize(alg::AlgToPreprocessNode, node::Node)

    constrs_to_stack = Constraint[]

    master = alg.extended_problem.master_problem
    for constr in master.constr_manager.active_static_list
	if isa(constr, ConvexityConstr)
	    continue
	end
        alg.constr_in_stack[constr.vc_ref] = false
	if node.depth == 0
	    push!(constrs_to_stack, constr)
	end
    end
    for constr in master.constr_manager.active_dynamic_list
        alg.constr_in_stack[constr.vc_ref] = false
	if node.depth == 0
	    push!(constrs_to_stack, constr)
	end
    end
    for subprob in alg.extended_problem.pricing_vect
        for constr in subprob.constr_manager.active_static_list
            alg.constr_in_stack[constr.vc_ref] = false
	    if node.depth == 0
		push!(constrs_to_stack, constr)
	    end
        end
    end

    if node.depth > 0
	constrs_to_stack = node.local_branching_constraints
    end

    #adding constraints to stack
    for constr in constrs_to_stack
	if update_min_slack(alg, constr, 0.0) || update_max_slack(alg, constr, 0.0)
	    return true
	end
    end

    return false
end

function compute_slacks(alg::AlgToPreprocessNode, node::Node)
    master = alg.extended_problem.master_problem
    for constr in master.constr_manager.active_static_list
        compute_min_slack(constr); compute_max_slack(constr)
    end
    for constr in master.constr_manager.active_dynamic_list
        compute_min_slack(constr); compute_max_slack(constr)
    end

    for subprob in alg.extended_problem.pricing_vect
        for constr in subprob.constr_manager.active_static_list
            compute_min_slack(constr); compute_max_slack(constr)
        end
    end
end

function compute_max_slack(constr::MasterConstr)
    slack = constr.cost_rhs
    for (sp_var, coeff) in constr.subprob_var_coef_map
	slack -= coeff > 0 ? coeff*sp_var.cur_global_lb : coeff*sp_var.cur_global_ub
    end
    for (var, coeff) in constr.member_coef_map
	if var.flag != 's' || occursin("art_glob", var.name)
	    continue
	end
        slack -= coeff > 0 ? coeff * var.cur_lb : coeff * var.cur_ub
    end
    constr.cur_max_slack = slack
end

function compute_min_slack(constr::MasterConstr)
    slack = constr.cost_rhs
    for (sp_var, coeff) in constr.subprob_var_coef_map
#	println(sp_var, " ", sp_var.flag, " ", coeff, " ", sp_var.cur_lb, " ", sp_var.cur_ub, " ", sp_var.cur_global_lb, " ", sp_var.cur_global_ub, " ", sp_var.name)
	slack -= coeff > 0 ? coeff*sp_var.cur_global_ub : coeff*sp_var.cur_global_lb
    end
    for (var, coeff) in constr.member_coef_map
	if var.flag != 's' || occursin("art_glob", var.name)
	    continue
	end
#	println(var, " ", var.flag, " ", coeff, " ", var.cur_lb, " ", var.cur_lb)
        slack -= coeff > 0 ? coeff*var.cur_ub : coeff*var.cur_lb
    end
 #   println("computed min_slack of master $(constr) is $(slack)")
    constr.cur_min_slack = slack
end

function compute_max_slack(constr::Constraint)
#    println("starting max_slack")
    slack = constr.cost_rhs
    for (var, coeff) in constr.member_coef_map
#	println(var, coeff)
        slack -= coeff > 0 ? coeff*var.cur_lb : coeff*var.cur_ub
    end
    constr.cur_max_slack = slack
 #   println("computed max_slack of master $(constr) is $(slack)")
end

function compute_min_slack(constr::Constraint)
    #println("starting min_slack")
    slack = constr.cost_rhs
    for (var, coeff) in constr.member_coef_map
#	println(var, coeff)
        slack -= coeff > 0 ? coeff*var.cur_ub : coeff*var.cur_lb
    end
    constr.cur_min_slack = slack
 #   println("computed min_slack of $(constr) is $(slack)")
end

function update_max_slack(alg::AlgToPreprocessNode, constr::Constraint, delta::Float)
    constr.cur_max_slack += delta
    if constr.sense != 'G' && constr.cur_max_slack < 0
        return true
    elseif constr.sense != 'L' && constr.cur_max_slack <= 0
	add_to_preprocessing_list(alg, constr)
    elseif constr.sense != 'G' && !alg.constr_in_stack[constr.vc_ref]
        push!(alg.stack, constr)
        alg.constr_in_stack[constr.vc_ref] = true
    end
    return false
end

function update_min_slack(alg::AlgToPreprocessNode, constr::Constraint, delta::Float)
#    println("updating min_slack of $(constr) from $(constr.cur_min_slack)"*
#	    " to $(constr.cur_min_slack + delta)")
    constr.cur_min_slack += delta
    if constr.sense != 'L' && constr.cur_min_slack > 0
        return true
    elseif constr.sense != 'G' && constr.cur_min_slack >= 0
	add_to_preprocessing_list(alg, constr)
    elseif constr.sense != 'L' && !alg.constr_in_stack[constr.vc_ref]
        push!(alg.stack, constr)
        alg.constr_in_stack[constr.vc_ref] = true
    end
    return false
end

function update_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar, new_lb::Float)
    if new_lb > var.cur_global_lb
        if new_lb > var.cur_global_ub
            return true
        end

        diff = var.cur_global_lb - new_lb
        for (constr, coef) in var.master_constr_coef_map
            func = coef < 0 ? update_min_slack : update_max_slack
            if func(alg, constr, diff*coef)
                return true
            end
        end
#	println("updating global_lb of sp_var $(var) from $(var.cur_global_lb) to $(new_lb)")
        var.cur_global_lb = new_lb
    end
    return false
end

function update_lower_bound(alg::AlgToPreprocessNode, var::MasterVar, new_lb::Float)
    if new_lb > var.cur_lb
        if new_lb > var.cur_ub
            return true
        end

        diff = var.cur_lb - new_lb
        for (constr, coef) in var.member_coef_map
            func = coef < 0 ? update_min_slack : update_max_slack
            if func(alg, constr, diff*coef)
                return true
            end
        end
	#println("updating lb of m_var $(var) from $(var.cur_lb) to $(new_lb)")
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

        diff = var.cur_global_ub - new_ub
        for (constr, coef) in var.master_constr_coef_map
            func = coef > 0 ? update_min_slack : update_max_slack
            if func(alg, constr, diff*coef)
                return true
            end
        end
	#println("updating global_ub of sp_var $(var) from $(var.cur_global_ub) to $(new_ub)")
        var.cur_global_ub = new_ub
    end
    return false
end

function update_upper_bound(alg::AlgToPreprocessNode, var::MasterVar, new_ub::Float)
    if new_ub < var.cur_ub
        if new_ub < var.cur_lb
            return true
        end

        diff = var.cur_ub - new_ub
        for (constr, coef) in var.member_coef_map
            func = coef > 0 ? update_min_slack : update_max_slack
            if func(alg, constr, diff*coef)
                return true
            end
        end
	#println("updating ub of m_var $(var) from $(var.cur_ub) to $(new_ub)")
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

	diff = var.cur_lb - new_lb
	for (constr, coef) in var.member_coef_map
	    func = coef < 0 ? update_min_slack : update_max_slack
	    if func(alg, constr, diff*coef)
		return true
	    end
	end
	#println("updating local_lb of sp_var $(var) from $(var.cur_lb) to $(new_lb)")
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

	diff = var.cur_ub - new_ub
	for (constr, coef) in var.member_coef_map
	    func = coef > 0 ? update_min_slack : update_max_slack
	    if func(alg, constr, diff*coef)
		return true
	    end
	end
	#println("updating local_ub of sp_var $(var) from $(var.cur_ub) to $(new_ub)")
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

function adjust_bound(var, bound, is_upper)
    if var.vc_type != 'C'
	bound = is_upper ? floor(bound) : ceil(bound)
    end
    return bound
end

function propagation(alg)

    while !isempty(alg.stack)

        constr = pop!(alg.stack)
        alg.constr_in_stack[constr.vc_ref] = false
#	println("constr $(constr) $(typeof(constr)) poped")

        #master constraint
        if isa(constr, MasterConstr)
            # master variables
	     #for (var, coef) in constr.subprob_var_coef_map
	#	println(var, coef)
	 #   end
            
           for (var, coef) in constr.member_coef_map
		#only static variables are considered
		if var.flag != 's' || occursin("art_glob", var.name)
		    continue
		end
                if coef > 0 && constr.sense != 'G'
                    func = update_upper_bound
                    bound = (constr.cur_max_slack + coef*var.cur_lb)/coef
                elseif coef > 0 && constr.sense != 'L'
                    func = update_lower_bound
                    bound = (constr.cur_min_slack + coef*var.cur_ub)/coef
                elseif coef < 0 && constr.sense != 'G'
                    func = update_lower_bound
                    bound = (constr.cur_max_slack + coef*var.cur_ub)/coef
                else
                    func = update_upper_bound
                    bound = (constr.cur_min_slack + coef*var.cur_lb)/coef
                end

		bound = adjust_bound(var, bound, func == update_upper_bound)
                if func(alg, var, bound)
                    return true
                end
            end

            # subprob variables
            for (sp_var, coef) in constr.subprob_var_coef_map
                if coef > 0 && constr.sense != 'G'
                    func = update_global_upper_bound
                    bound = (constr.cur_max_slack + coef*sp_var.cur_global_lb)/coef
                elseif coef > 0 && constr.sense != 'L'
                    func = update_global_lower_bound
                    bound = (constr.cur_min_slack + coef*sp_var.cur_global_ub)/coef
                elseif coef < 0 && constr.sense != 'G'
                    func = update_global_lower_bound
                    bound = (constr.cur_max_slack + coef*sp_var.cur_global_ub)/coef
                else
                    func = update_global_upper_bound
                    bound = (constr.cur_min_slack + coef*sp_var.cur_global_lb)/coef
                end

		bound = adjust_bound(sp_var, bound, func == update_global_upper_bound)
                if func(alg, sp_var, bound)
                    return true
                end
            end
        #subproblem constraint
        else
            for (var, coef) in constr.member_coef_map

                if coef > 0 && constr.sense != 'G'
                    func = update_local_upper_bound
                    bound = (constr.cur_max_slack + coef*var.cur_lb)/coef
                elseif coef > 0 && constr.sense != 'L'
                    func = update_local_lower_bound
                    bound = (constr.cur_min_slack + coef*var.cur_ub)/coef
                elseif coef < 0 && constr.sense != 'G'
                    func = update_local_lower_bound
                    bound = (constr.cur_max_slack + coef*var.cur_ub)/coef
                else
                    func = update_local_upper_bound
                    bound = (constr.cur_min_slack + coef*var.cur_lb)/coef
                end

		bound = adjust_bound(var, bound, func == update_local_upper_bound)
                if func(alg, var, bound)
                    return true
                end
            end
        end
    end
    return false
end

@hl mutable struct AlgToPreprocessNode <: AlgLike
    depth::Int
    extended_problem::ExtendedProblem
    constr_in_stack::Dict{Constraint,Bool}
    stack::DS.Stack{Constraint}
    var_local_master_membership::Dict{Variable,Vector{Tuple{Constraint,Float}}}
    var_local_sp_membership::Dict{Variable,Vector{Tuple{Constraint,Float}}}
    cur_min_slack::Dict{Constraint,Float}
    cur_max_slack::Dict{Constraint,Float}
    nb_inf_sources_for_min_slack::Dict{Constraint,Int}
    nb_inf_sources_for_max_slack::Dict{Constraint,Int}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
    cur_sp_bounds::Vector{Tuple{Int,Int}}
    printing::Bool
    local_partial_sol::Union{Nothing,PrimalSolution} 
end

function AlgToPreprocessNodeBuilder(depth::Int, 
                                    extended_problem::ExtendedProblem,
                                    local_partial_sol::Union{Nothing,PrimalSolution} = nothing)

    cur_sp_bounds = Vector{Tuple{Int,Int}}()
    for sp_ref in 1:length(extended_problem.pricing_vect)
        push!(cur_sp_bounds, get_sp_convexity_bounds(extended_problem, sp_ref))
    end
    return (depth, extended_problem, 
            Dict{Constraint,Bool}(), 
            DS.Stack{Constraint}(), 
            Dict{Variable,Vector{Tuple{Constraint,Float}}}(),
            Dict{Variable,Vector{Tuple{Constraint,Float}}}(),
            Dict{Constraint,Float}(),
            Dict{Constraint,Float}(), 
            Dict{Constraint,Int}(),
            Dict{Constraint,Int}(), 
            Constraint[], 
            Variable[],
            cur_sp_bounds,
            false,
            local_partial_sol)
end

function run(alg::AlgToPreprocessNode)

    if alg.printing && alg.local_partial_sol != nothing
        println("running preprocess with partial sol:")
        for (var, val) in alg.local_partial_sol.var_val_map
            println("var ", var.vc_ref, " with val=", val)
            for (sp_var, sp_var_val) in var.solution.var_val_map
                println("sp_var", sp_var.vc_ref, " val:", val)
            end
        end
    end

    reset(alg)
    compute_local_memberships(alg)

    if alg.local_partial_sol != nothing
        # Change sp bounds, global bounds of var and rhs of master constraints
        (vars_with_modified_bounds,
         constrs_with_modified_rhs) = fix_local_partial_solution(alg)
    else
        (vars_with_modified_bounds,
         constrs_with_modified_rhs) = Variable[], MasterConstr[]
    end
    # Compute slacks and add constraints to stack
    if initialize_constraints(alg, vars_with_modified_bounds, constrs_with_modified_rhs)
        return true
    end
    # Now we try to update local bounds of sp vars
    if alg.local_partial_sol != nothing
        for var in vars_with_modified_bounds
            if isa(var, SubprobVar)
                update_global_lower_bound(alg, var, var.cur_global_lb, false)
                update_global_upper_bound(alg, var, var.cur_global_ub, false)
            end
        end
    end
    infeas = propagation(alg) 
    if alg.printing
        print_preprocessing_list(alg)
    end
    if !infeas
        apply_preprocessing(alg)
        # if alg.local_partial_sol != nothing
            # glpk_prob = alg.extended_problem.master_problem.optimizer.optimizer.inner
            # GLPK.write_lp(glpk_prob, string("mip_d", 3,".lp")) 
            # exit()
        # end
    end
    return infeas
end

function change_sp_bounds(alg::AlgToPreprocessNode)
    sps_with_modified_bounds = []
    for (var, val) in alg.local_partial_sol.var_val_map
        if isa(var, MasterColumn)
            sp_ref = -1
            for (sp_var, sp_var_val) in var.solution.var_val_map
                sp_ref = sp_var.prob_ref
                break
            end
            @assert sp_ref != -1
            sp_prob = get_problem(alg.extended_problem, sp_ref)
 
            if alg.cur_sp_bounds[sp_ref][1] > 0
                alg.cur_sp_bounds[sp_ref] = (alg.cur_sp_bounds[sp_ref][1] - 1, alg.cur_sp_bounds[sp_ref][2])
                conv_lb_constr = alg.extended_problem.pricing_convexity_lbs[sp_prob]
                conv_lb_constr.cur_cost_rhs -= 1
                add_to_preprocessing_list(alg, conv_lb_constr)
            end

            alg.cur_sp_bounds[sp_ref] = (alg.cur_sp_bounds[sp_ref][1], alg.cur_sp_bounds[sp_ref][2] - 1)
            conv_ub_constr = alg.extended_problem.pricing_convexity_ubs[sp_prob]
            conv_ub_constr.cur_cost_rhs -= 1
            add_to_preprocessing_list(alg, conv_ub_constr)
            @assert alg.cur_sp_bounds[sp_ref][2] >= 0

            if !(sp_prob in sps_with_modified_bounds)
                push!(sps_with_modified_bounds, sp_prob)
            end
        end
    end
    return sps_with_modified_bounds
end

function project_local_partial_solution(local_partial_sol::PrimalSolution)
    user_vars_vals = Dict{Variable,Float}()
    for (var, val) in local_partial_sol.var_val_map
        if isa(var, MasterColumn)
            for (user_var, user_var_val) in var.solution.var_val_map
                if !haskey(user_vars_vals, user_var)
                    user_vars_vals[user_var] = user_var_val
                else
                    user_vars_vals[user_var] += user_var_val
                end
            end
        elseif isa(var, MasterVar)
            user_vars_vals[var] = val
        else
            error("subprob vars are not expected in a partial solution")
        end
    end
    return user_vars_vals
end

function fix_local_partial_solution(alg::AlgToPreprocessNode)

    sps_with_modified_bounds = change_sp_bounds(alg)
    user_vars_vals = project_local_partial_solution(alg.local_partial_sol)
   
    # Updating rhs of master constraints
    # master vars of partial_sol are ignored here 
    # because we only change their bounds
    constrs_with_modified_rhs = MasterConstr[]
    for (var, val) in user_vars_vals
        if isa(var, SubprobVar)
            for (constr, coef) in alg.var_local_master_membership[var]
                constr.cur_cost_rhs -= val*coef
                add_to_preprocessing_list(alg, constr)
            end
        end
    end

    # Changing global bounds of master variables
    # with non-zero values in the partial_sol
    vars_with_modified_bounds = Variable[]
    for (var, val) in user_vars_vals
        if isa(var, MasterVar)
            var.cur_lb = var.cur_ub = val
            push!(vars_with_modified_bounds, var)
            add_to_preprocessing_list(alg, var)
        end
    end
    
    # Changing global bounds of subprob variables
    for sp_prob in sps_with_modified_bounds
        (cur_sp_lb, cur_sp_ub) = alg.cur_sp_bounds[sp_prob.prob_ref]
        
        for var in sp_prob.var_manager.active_static_list
            var_val_in_local_sol = haskey(user_vars_vals, var) ? user_vars_vals[var] : 0.0
            bounds_changed = false

            new_global_lb = max(var.cur_global_lb - var_val_in_local_sol, 
                                    var.lower_bound*cur_sp_lb)
            if new_global_lb != var.cur_global_lb 
                bounds_changed = true
            end
            var.cur_global_lb = new_global_lb

            new_global_ub = min(var.cur_global_ub - var_val_in_local_sol,
                                       var.upper_bound*cur_sp_ub)
            if new_global_ub != var.cur_global_ub
                bounds_changed = true
            end
            var.cur_global_ub = new_global_ub
            
            if bounds_changed
                push!(vars_with_modified_bounds, var)
            end
        end
    end

    # for var in vars_with_modified_bounds
        # println("var $(var.vc_ref) modified bounds $(var.cur_global_lb) $(var.cur_global_lb)")
    # end
    return (vars_with_modified_bounds, constrs_with_modified_rhs)
end

function print_preprocessing_list(alg::AlgToPreprocessNode)
    println("vars preprocessed (changed bounds):")
    for var in alg.preprocessed_vars
        println("var $(var.vc_ref) $(var.cur_lb) $(var.cur_ub)")
    end
    println("constrs preprocessed (changed rhs):")
    for constr in alg.preprocessed_constrs
        println("constr $(constr.vc_ref) $(constr.cur_cost_rhs)")
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
    empty!(alg.cur_min_slack)
    empty!(alg.cur_max_slack)
    empty!(alg.nb_inf_sources_for_max_slack)
    empty!(alg.nb_inf_sources_for_min_slack)
end

function initialize_constraints(alg::AlgToPreprocessNode,
                                vars_with_modified_bounds::Vector{Variable},
                                constrs_with_modified_rhs::Vector{MasterConstr})
    # Contains the constraints to start propagation
    constrs_to_stack = Constraint[]

    # Static master constraints
    master = alg.extended_problem.master_problem
    for constr in master.constr_manager.active_static_list
        if !isa(constr, ConvexityConstr)
            initialize_constraint(alg, constr)
            if alg.depth == 0 
                push!(constrs_to_stack, constr)
            end
        end
    end

    # Dynamic master constraints
    for constr in master.constr_manager.active_dynamic_list
        initialize_constraint(alg, constr)
        if constr.depth_when_generated == alg.depth - 1
            push!(constrs_to_stack, constr)
        end
    end

    # Subproblem constraints
    for subprob in alg.extended_problem.pricing_vect
        for constr in subprob.constr_manager.active_static_list
            initialize_constraint(alg, constr)
            if alg.depth == 0
                push!(constrs_to_stack, constr)
            end
        end
    end

    # We add to the stack all constraints affected
    # by the fixing of the local partial sol
    for constr in constrs_with_modified_rhs
        if  !(constr in constrs_to_stack)
            push!(constrs_to_stack, constr)
        end
    end
    for var in vars_with_modified_bounds
        for (constr, coef) in alg.var_local_master_membership[var]
            if  !(constr in constrs_to_stack)
                push!(constrs_to_stack, constr)
            end
        end
        if isa(var, SubprobVar)
            for (constr, coef) in alg.var_local_sp_membership[var]
                if  !(constr in constrs_to_stack)
                    push!(constrs_to_stack, constr)
                end
            end
        end
    end

    # Adding constraints to stack
    for constr in constrs_to_stack
        if (update_min_slack(alg, constr, false, 0.0) 
            || update_max_slack(alg, constr, false, 0.0))
            return true
        end
    end

    return false
end

function initialize_constraint(alg::AlgToPreprocessNode, constr::Constraint)
    alg.constr_in_stack[constr] = false
    alg.nb_inf_sources_for_min_slack[constr] = 0
    alg.nb_inf_sources_for_max_slack[constr] = 0
    compute_min_slack(alg, constr)
    compute_max_slack(alg, constr)
    if alg.printing
        print_constr(alg, constr)
    end
end

function compute_local_memberships(alg::AlgToPreprocessNode)
    # Static master constraints
    master = alg.extended_problem.master_problem
    for constr in master.constr_manager.active_static_list
        if !isa(constr, ConvexityConstr)
            compute_local_membership(alg, constr)
        end
    end

    # Dynamic master constraints
    for constr in master.constr_manager.active_dynamic_list
        compute_local_membership(alg, constr)
    end

    # Subproblem constraints
    for subprob in alg.extended_problem.pricing_vect
        for constr in subprob.constr_manager.active_static_list
            compute_local_membership(alg, constr)
        end
    end
end

function compute_local_membership(alg::AlgToPreprocessNode, constr::MasterConstr)
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

function compute_local_membership(alg::AlgToPreprocessNode, constr::Constraint)
    for (var, coef) in constr.member_coef_map
        if !haskey(alg.var_local_sp_membership, var)
            alg.var_local_sp_membership[var] = [(constr, coef)]
        else
            push!(alg.var_local_sp_membership[var], (constr, coef))
        end
    end
end

function print_constr(alg::AlgToPreprocessNode, constr::Constraint)
    println("constr $(constr.vc_ref) $(typeof(constr)) $(constr.sense) $(constr.cost_rhs): vars:")
    for (var, coeff) in constr.member_coef_map
        println(var.vc_ref, " ", coeff, " ", var.flag)
    end
    if isa(constr, MasterConstr)
        println("constr $(constr.vc_ref): subprob vars:")
        for (sp_var, coeff) in constr.subprob_var_coef_map
            println(sp_var.vc_ref, " ", coeff, " ", sp_var.cur_cost_rhs, " ", sp_var.flag, " ",
                    sp_var.cur_lb, " ", sp_var.cur_ub, " ", 
                    sp_var.cur_global_lb, " ", sp_var.cur_global_ub)
        end
    end
    println("cur_min $(alg.cur_min_slack[constr])" *
            " cur_max $(alg.cur_max_slack[constr])")
end

function compute_min_slack(alg::AlgToPreprocessNode, constr::Constraint)
    slack = constr.cur_cost_rhs
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
    alg.cur_min_slack[constr] = slack
end

function compute_max_slack(alg::AlgToPreprocessNode, constr::Constraint)
    slack = constr.cur_cost_rhs
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
    alg.cur_max_slack[constr] = slack
end

function compute_min_slack(alg::AlgToPreprocessNode, constr::MasterConstr)
    @callsuper compute_min_slack(alg, constr::Constraint)

    # Subprob variables
    for (sp_var, coef) in constr.subprob_var_coef_map
        if coef < 0
            if sp_var.cur_global_lb == -Inf
                alg.nb_inf_sources_for_min_slack[constr] += 1
            else
                alg.cur_min_slack[constr] -= coef*sp_var.cur_global_lb
            end
        else
           if sp_var.cur_global_ub == Inf
                alg.nb_inf_sources_for_min_slack[constr] += 1
            else
                alg.cur_min_slack[constr] -= coef*sp_var.cur_global_ub
            end
        end
    end
end

function compute_max_slack(alg::AlgToPreprocessNode, constr::MasterConstr)
    @callsuper compute_max_slack(alg, constr::Constraint)

    # Subprob variables
    for (sp_var, coef) in constr.subprob_var_coef_map
        if coef > 0
            if sp_var.cur_global_lb == -Inf
                alg.nb_inf_sources_for_max_slack[constr] += 1
            else
                alg.cur_max_slack[constr] -= coef*sp_var.cur_global_lb
            end
        else
           if sp_var.cur_global_ub == Inf
                alg.nb_inf_sources_for_max_slack[constr] += 1
            else
                alg.cur_max_slack[constr] -= coef*sp_var.cur_global_ub
            end
        end
    end
end

function update_max_slack(alg::AlgToPreprocessNode, constr::Constraint, 
                          var_was_inf_source::Bool, delta::Float)
    alg.cur_max_slack[constr] += delta
    if var_was_inf_source
        alg.nb_inf_sources_for_max_slack[constr] -= 1
    end

    nb_inf_sources = alg.nb_inf_sources_for_max_slack[constr]
    if nb_inf_sources == 0
        if constr.sense != 'G' && alg.cur_max_slack[constr] < -0.0001
            return true
        elseif constr.sense == 'G' && alg.cur_max_slack[constr] <= -0.0001
            #add_to_preprocessing_list(alg, constr)
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

function update_min_slack(alg::AlgToPreprocessNode, constr::Constraint, 
                          var_was_inf_source::Bool, delta::Float)
    alg.cur_min_slack[constr] += delta
    if var_was_inf_source
        alg.nb_inf_sources_for_min_slack[constr] -= 1
    end

    nb_inf_sources = alg.nb_inf_sources_for_min_slack[constr]
    if nb_inf_sources == 0
        if constr.sense != 'L' && alg.cur_min_slack[constr] > 0.0001
            return true
        elseif constr.sense == 'L' && alg.cur_min_slack[constr] >= 0.0001
            #add_to_preprocessing_list(alg, constr)
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

function update_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar,
                            new_lb::Float, check_monotonicity::Bool = true)
    if new_lb > var.cur_global_lb || !check_monotonicity
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
        if alg.printing
            println("updating global_lb of sp_var $(var.name) $(var.vc_ref) from "*
                    "$(var.cur_global_lb) to $(new_lb)")
        end
        var.cur_global_lb = new_lb
    end
    return false
end

function update_lower_bound(alg::AlgToPreprocessNode, var::MasterVar,
                            new_lb::Float)
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
        if alg.printing
            println("updating lb of m_var $(var.name) $(var.vc_ref) from $(var.cur_lb)"*
                    " to $(new_lb)")
        end
        var.cur_lb = new_lb
        add_to_preprocessing_list(alg, var)
    end
    return false
end

function update_upper_bound(alg::AlgToPreprocessNode, var::SubprobVar, 
                            new_ub::Float, check_monotonicity::Bool = true)
    if new_ub < var.cur_global_ub || !check_monotonicity
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
        if alg.printing
            println("updating global_ub of sp_var m_var $(var.name) ($(var.vc_ref)) from" *
                    " $(var.cur_global_ub) to $(new_ub)")
        end
        var.cur_global_ub = new_ub
    end
    return false
end

function update_upper_bound(alg::AlgToPreprocessNode, var::MasterVar, 
                            new_ub::Float)
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
        if alg.printing
            println("updating ub of m_var $(var.name) ($(var.vc_ref)) from" *
                    " $(var.cur_ub) to $(new_ub)")
        end
        var.cur_ub = new_ub
        add_to_preprocessing_list(alg, var)
    end
    return false
end

function update_global_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar,
                                   new_lb::Float, check_monotonicity::Bool = true)
    if update_lower_bound(alg, var, new_lb, check_monotonicity)
        return true
    end

    (sp_lb, sp_ub) = alg.cur_sp_bounds[var.prob_ref]
    if update_local_lower_bound(alg, var, var.cur_global_lb - (max(sp_ub, 1) - 1)*var.cur_ub)
        return true
    end
    return false
end

function update_global_upper_bound(alg::AlgToPreprocessNode, var::SubprobVar,
                                   new_ub::Float, check_monotonicity::Bool = true)
    if update_upper_bound(alg, var, new_ub, check_monotonicity)
        return true
    end

    (sp_lb, sp_ub) = alg.cur_sp_bounds[var.prob_ref]
    if update_local_upper_bound(alg, var, var.cur_global_ub - (max(sp_lb, 1) -1)*var.cur_lb)
        return true
    end
    return false
end

function update_local_lower_bound(alg::AlgToPreprocessNode, var::SubprobVar,
                                  new_lb::Float)
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

        if alg.printing
            println("updating local_lb of sp_var $(var.vc_ref) from" * 
                    " $(var.cur_lb) to $(new_lb)")
        end
        var.cur_lb = new_lb
        add_to_preprocessing_list(alg, var)

        (sp_lb, sp_ub) = alg.cur_sp_bounds[var.prob_ref]
        if update_global_lower_bound(alg, var, var.cur_lb * sp_lb)
            return true
        end
        new_local_ub = var.cur_global_ub - (max(sp_lb, 1) - 1) * var.cur_lb
        if update_local_upper_bound(alg, var, new_local_ub)
            return true
        end
    end
    return false
end

function update_local_upper_bound(alg::AlgToPreprocessNode, var::SubprobVar,
                                  new_ub::Float)
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
        if alg.printing
            println("updating local_ub of sp_var $(var.vc_ref) from " * 
                    "$(var.cur_ub) to $(new_ub)")
        end
        var.cur_ub = new_ub
        add_to_preprocessing_list(alg, var)

        (sp_lb, sp_ub) = alg.cur_sp_bounds[var.prob_ref]
        if update_global_upper_bound(alg, var, var.cur_ub * sp_ub)
            return true
        end
        new_local_lb = var.cur_global_lb - (max(sp_ub, 1) - 1) * var.cur_ub
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

    function compute_new_bound(nb_inf_sources::Int, slack::Float, 
                               var_contrib_to_slack::Float, inf_bound::Float)
        if nb_inf_sources == 0
            bound = (slack - var_contrib_to_slack)/coef
        elseif nb_inf_sources == 1 && isinf(var_contrib_to_slack)
            bound = slack/coef 
        else
            bound = inf_bound
        end
        return bound
    end

    if coef > 0 && constr.sense == 'L'
        is_ub = true
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_max_slack[constr],
                                         alg.cur_max_slack[constr], -coef*cur_lb, Inf))
    elseif coef > 0 && constr.sense != 'L'
        is_ub = false
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_min_slack[constr], 
                                         alg.cur_min_slack[constr], -coef*cur_ub, -Inf))
    elseif coef < 0 && constr.sense != 'G'
        is_ub = false
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_max_slack[constr],
                                         alg.cur_max_slack[constr], -coef*cur_ub, -Inf))
    else
        is_ub = true
        return (is_ub, compute_new_bound(alg.nb_inf_sources_for_min_slack[constr], 
                                         alg.cur_min_slack[constr], -coef*cur_lb, Inf))
    end
end

function analyze_constraint(alg::AlgToPreprocessNode, constr::Constraint)
    for (var, coef) in constr.member_coef_map
        (is_ub, bound) = compute_new_var_bound(alg, var, var.cur_lb, var.cur_ub,
                                               coef, constr) 
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
    # Master variables
    for (var, coef) in constr.member_coef_map
        # Only static variables are considered
        if var.flag != 's'
            continue
        end

        (is_ub, bound) = compute_new_var_bound(alg, var, var.cur_lb,
                                               var.cur_ub, coef, constr) 
        if !isinf(bound)
            bound = adjust_bound(var, bound, is_ub)
            func = is_ub ? update_upper_bound : update_lower_bound
            if func(alg, var, bound)
                return true
            end
        end
    end
    # Subprob variables
    for (sp_var, coef) in constr.subprob_var_coef_map
        (is_ub, bound) = compute_new_var_bound(alg, sp_var, sp_var.cur_global_lb,
                                               sp_var.cur_global_ub, coef, constr) 
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

        if alg.printing
            println("constr $(constr.vc_ref) $(typeof(constr)) popped")
        end
        if analyze_constraint(alg, constr)
            return true
        end
    end
    return false
end

function find_infeasible_columns(master::CompactProblem,
                                 preproc_vars::Vector{Variable})
    infeas_cols = Variable[]
    
    for var in preproc_vars
        if !isa(var, SubprobVar)
            continue
        end
        lb, ub = var.cur_lb, var.cur_ub
        for master_col in master.var_manager.active_dynamic_list
            #skipping column if it is a solution to another subproblem
            sp_prob_ref = -1
            for (sp_var, val) in master_col.solution.var_val_map
                sp_prob_ref = var.prob_ref
                break
            end
            @assert sp_prob_ref != -1
            if sp_prob_ref != var.prob_ref
                continue
            end

            #detecting infeasibility
            if haskey(master_col.solution.var_val_map, var)
                value_in_col = master_col.solution.var_val_map[var]
            else
                value_in_col = 0.0
            end
            if !(lb - 0.0001 <= value_in_col <= ub + 0.0001)
                if !(master_col in infeas_cols)
                    #println("inf col ", value_in_col, " ", lb, " ", ub)
                    push!(infeas_cols, master_col)
                end
            end
        end
    end
    #println("preprocess info:", length(preproc_vars), " ", length(infeas_cols), " ", length(master.var_manager.active_dynamic_list))
    for master_col in infeas_cols
        update_var_status(master, master_col, Unsuitable)
    end
    return infeas_cols
end

function apply_preprocessing(alg::AlgToPreprocessNode)

    @timeit to(alg) "Preprocess" begin

        # if isempty(alg.preprocessed_vars) && isempty(alg.preprocessed_constrs)
        # return
    # end

    master = alg.extended_problem.master_problem
    infeas_cols = find_infeasible_columns(master, alg.preprocessed_vars)

    update_moi_optimizer(
        master.optimizer, master.is_relaxed,
        ProblemUpdate(Constraint[], Constraint[], infeas_cols, Variable[],
                      Variable[], Constraint[])
    )
    for var in alg.preprocessed_vars
        optimizer = get_problem(alg.extended_problem, var.prob_ref).optimizer
        enforce_current_bounds_in_optimizer(optimizer, var)
    end
    for constr in alg.preprocessed_constrs
        # This assumes that preprocessed constraints are only from master
        @assert constr isa MasterConstr
        update_constr_rhs_in_optimizer(master.optimizer, constr)
    end

    #adding the new column to the partial solution of the master
    if alg.local_partial_sol != nothing
        for (col, val) in alg.local_partial_sol.var_val_map
            if haskey(master.partial_solution.var_val_map, col)
                master.partial_solution.var_val_map[col] += val
            else
                master.partial_solution.var_val_map[col] = val
            end
            master.partial_solution.cost += val*col.cur_cost_rhs
        end
        update_optimizer_obj_constant(master.optimizer,
                                      master.partial_solution.cost)
            # glpk_prob = alg.extended_problem.master_problem.optimizer.optimizer.inner
            # println("fixed_sol_cost $(master.partial_solution.cost)")
             # GLPK.write_lp(glpk_prob, string("mip_di", 5,".lp")) 
 #             exit()
  
    end
end
end

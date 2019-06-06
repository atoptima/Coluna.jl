struct Preprocess <: AbstractAlgorithm end

mutable struct PreprocessData
    depth::Int
    reformulation::Reformulation # should handle reformulation & formulation
    constr_in_stack::Dict{ConstrId,Bool}
    stack::DS.Stack{Tuple{Constraint,Formulation}}
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
    cur_sp_bounds::Dict{FormId,Tuple{Int,Int}}
    local_partial_sol::Vector{Tuple{Variable, Int}}
    printing::Bool
end

function PreprocessData(depth::Int, reformulation::Reformulation)
     cur_sp_bounds = Dict{FormId,Tuple{Int,Int}}()
     master = getmaster(reformulation)
     for subprob in reformulation.dw_pricing_subprs
         conv_lb = getconstr(master, reformulation.dw_pricing_sp_lb[getuid(subprob)])
         conv_ub = getconstr(master, reformulation.dw_pricing_sp_ub[getuid(subprob)])
	 cur_sp_bounds[getuid(subprob)] = (getcurrhs(conv_lb), getcurrhs(conv_ub))
     end
     return PreprocessData(depth, 
	     reformulation, 
             Dict{ConstrId,Bool}(), 
             DS.Stack{Tuple{Constraint, Formulation}}(), 
             Dict{ConstrId,Float64}(),
             Dict{ConstrId,Float64}(), 
             Dict{ConstrId,Int}(),
             Dict{ConstrId,Int}(), 
             Constraint[], 
             Variable[],
             cur_sp_bounds,
	     Tuple{Variable,Int}[],
             false)
end

struct PreprocessRecord <: AbstractAlgorithmRecord
     infeasible::Bool
end

function prepare!(::Type{Preprocess}, form, node, strategy_rec, params)
    @logmsg LogLevel(0) "Prepare preprocess node"
    return
end

function run!(::Type{Preprocess}, formulation, node, strategy_rec, parameters)
    @logmsg LogLevel(0) "Run preprocess node"

    alg_data = PreprocessData(node.depth, formulation)
    master = getmaster(alg_data.reformulation)

    (vars_with_modified_bounds,
    constrs_with_modified_rhs) = fix_local_partial_solution(alg_data)

    if initialize_constraints(alg_data, constrs_with_modified_rhs)
       return PreprocessRecord(true) 
    end

    #Now we try to update local bounds of sp vars
    for var in vars_with_modified_bounds
       update_lower_bound(alg, var, master, getcurlb(var), false)
       update_upper_bound(alg, var, master, getcurub(var), false)
    end

    infeasible = propagation(alg_data) 
    return PreprocessRecord(infeasible) 
end

function change_sp_bounds(alg_data::PreprocessData)
   reformulation = alg_data.reformulation
   master = getmaster(reformulation)
   sps_with_modified_bounds = []

   for (var, val) in alg_data.local_partial_sol
      sp_form = nothing #TODO: how to get form from column?
      sp_form_id = getuid(sp_form)
      if alg_data.cur_sp_bounds[sp_form_id][1] > 0
         alg_data.cur_sp_bounds[sp_form_id] = (alg.cur_sp_bounds[sp_form_id][1] - 1, alg.cur_sp_bounds[sp_form_id][2])
         conv_lb_constr = getconstr(master, reformulation.dw_pricing_sp_lb[sp_form_id])
         #TODO: set new rhs. how??
      end

      alg.cur_sp_bounds[sp_form_id] = (alg.cur_sp_bounds[sp_form_id][1], alg.cur_sp_bounds[sp_form_id][2] - 1)
      conv_ub_constr = getconstr(master, reformulation.dw_pricing_sp_ub[sp_form_id])
      #TODO: set new rhs. how??
      @assert alg.cur_sp_bounds[sp_ref][2] >= 0

      if !(sp_prob in sps_with_modified_bounds)
         push!(sps_with_modified_bounds, sp_prob)
      end
   end
   return sps_with_modified_bounds
end

function project_local_partial_solution(alg_data::PreprocessData)
   user_vars_vals = Dict{VarId,Float64}()
   primal_sp_sols = getprimalspsolmatrix(getmaster(alg_data.reformulation))
   for (var, val) in alg_data.local_partial_sol
      for (user_var_id, user_var_val) in primal_sp_sols[:,getid(var.id)]
         if !haskey(user_vars_vals, user_var_id)
            user_vars_vals[user_var_id] = user_var_val
         else
            user_vars_vals[user_var_id] += user_var_val
         end
      end
   end
   return user_vars_vals
end

function fix_local_partial_solution(alg_data::PreprocessData)

    sps_with_modified_bounds = change_sp_bounds(alg_data)
    user_vars_vals = project_local_partial_solution(alg_data)

    # Updating rhs of master constraints
    # master vars of partial_sol are ignored here
    # because we only change their bounds
    master = getmaster(alg_data.reformulation)
    master_coef_matrix = getcoefmatrix(master)
    constrs_with_modified_rhs = Constraint[]
    for (var_id, val) in user_vars_vals
       for (constr_id, coef) in filter(_active_explicit_, master_coef_matrix[:, var_id])
           #constr.cur_cost_rhs -= val*coef
           #TODO:modify rhs
           push!(constrs_with_modified_rhs, getconstr(master, constr_id))
       end
    end

    # Changing global bounds of subprob variables
    vars_with_modified_bounds = Variable[]
    for sp_prob in sps_with_modified_bounds
        (cur_sp_lb, cur_sp_ub) = alg.cur_sp_bounds[getuid(sp_prob)]

	for (var_id, var) in filter(_active_pricing_sp_var_, getvars(sp_form))
            var_val_in_local_sol = haskey(user_vars_vals, var_id) ? user_vars_vals[var_id] : 0.0
            bounds_changed = false

	    clone_in_master = getvar(master, var_id)
            new_global_lb = max(getcurlb(clone_in_master) - var_val_in_local_sol,
                                    getcurlb(var)*cur_sp_lb)
            if new_global_lb != getcurlb(clone_in_master)
               setlb!(clone_in_master) = new_global_lb
               bounds_changed = true
            end

            new_global_ub = min(getcurub(clone_in_master) - var_val_in_local_sol,
                                       getcurub(var)*cur_sp_ub)
            if new_global_ub != getcurub(clone_in_master)
               setub!(clone_in_master) = new_global_ub
               bounds_changed = true
            end

            if bounds_changed
                push!(vars_with_modified_bounds, clone_in_master)
            end
        end
    end

    return (vars_with_modified_bounds, constrs_with_modified_rhs)
end


function initialize_constraints(alg_data::PreprocessData, constrs_with_modified_rhs::Vector{Constraint})
    # Contains the constraints to start propagation
    constrs_to_stack = Tuple{Constraint,Formulation}[]

    #master constraints
    master = getmaster(alg_data.reformulation)
    master_coef_matrix = getcoefmatrix(master)
    for (constr_id, constr) in filter(_active_explicit_, getconstrs(master))
        if getduty(constr) != MasterConvexityConstr
            initialize_constraint(alg_data, constr, master)
            push!(constrs_to_stack, (constr, master))
	end
    end

    #subproblem constraints
    for subprob in alg_data.reformulation.dw_pricing_subprs 
        for (constr_id, constr) in filter(_active_explicit_, getconstrs(subprob))
            initialize_constraint(alg_data, constr, subprob)
            push!(constrs_to_stack, (constr, subprob))
	end
    end
    
    # We add to the stack all constraints affected
    # by the fixing of the local partial sol
    for constr in constrs_with_modified_rhs
       if !((constr, master) in constrs_to_stack)
          push!(constrs_to_stack, (constr, master))
       end
    end

    # Adding constraints to stack
    for (constr, form) in constrs_to_stack
        if (update_min_slack(alg_data, constr, form, false, 0.0) 
            || update_max_slack(alg_data, constr, form, false, 0.0))
            return true
        end
    end

    return false
 end

function initialize_constraint(alg_data::PreprocessData, constr::Constraint, form::Formulation)
    alg_data.constr_in_stack[constr.id] = false
    alg_data.nb_inf_sources_for_min_slack[constr.id] = 0
    alg_data.nb_inf_sources_for_max_slack[constr.id] = 0     
    compute_min_slack(alg_data, constr, form)
    compute_max_slack(alg_data, constr, form)
#     if alg.printing
#         print_constr(alg, constr)
#     end
end

function compute_min_slack(alg_data::PreprocessData, 
	                   constr::Constraint, 
                           form::Formulation)
    slack = getrhs(getcurdata(constr))
    if constr.duty <:AbstractMasterConstr
       var_filter = _rep_of_orig_var_ 
    else
       var_filter = (var -> (var.duty == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[constr.id,:]
         var = getvar(form, var_id)
         if !var_filter(var) 
             continue
         end
         if coef > 0
             cur_ub = getub(getcurdata(var))
             if cur_ub == Inf
                 alg_data.nb_inf_sources_for_min_slack[constr.id] += 1
             else
                 slack -= coef*cur_ub
             end
         else
             cur_lb = getlb(getcurdata(var))
             if cur_lb == -Inf
                 alg_data.nb_inf_sources_for_min_slack[constr.id] += 1
             else
                 slack -= coef*cur_lb
             end
         end
     end
     alg_data.cur_min_slack[constr.id] = slack
end

function compute_max_slack(alg_data::PreprocessData, 
	                   constr::Constraint, 
                           form::Formulation)
    slack = getrhs(getcurdata(constr))
    if constr.duty <:AbstractMasterConstr
       var_filter = _rep_of_orig_var_ 
    else
       var_filter = (var -> (var.duty == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[constr.id,:]
         var = getvar(form, var_id)
         if !var_filter(var) 
             continue
         end
         if coef > 0
             cur_lb = getlb(getcurdata(var))
             if cur_lb == -Inf
                 alg_data.nb_inf_sources_for_max_slack[constr.id] += 1
             else
                 slack -= coef*cur_lb
             end
         else
             cur_ub = getub(getcurdata(var))
             if cur_ub == Inf
                 alg_data.nb_inf_sources_for_max_slack[constr.id] += 1
             else
                 slack -= coef*cur_ub
             end
         end
     end
     alg_data.cur_max_slack[constr.id] = slack
 end

function update_max_slack(alg_data::PreprocessData,
	                  constr::Constraint, 
			  form::Formulation,
                          var_was_inf_source::Bool,
			  delta::Float64)
    alg_data.cur_max_slack[constr.id] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_max_slack[constr.id] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_max_slack[constr.id]
    sense = getcursense(constr)
    if nb_inf_sources == 0
        if sense != Greater && alg_data.cur_max_slack[constr.id] < -0.0001
            return true
        elseif sense == Greater && alg_data.cur_max_slack[constr.id] <= -0.0001
            #add_to_preprocessing_list(alg, constr)
            return false
        end
     end
     if nb_inf_sources <= 1
         if sense != Greater
             add_to_stack(alg_data, constr, form)
         end
     end
     return false
end

function update_min_slack(alg_data::PreprocessData,
	                  constr::Constraint,
			  form::Formulation,
                          var_was_inf_source::Bool,
			  delta::Float64)
    alg_data.cur_min_slack[constr.id] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_min_slack[constr.id] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_min_slack[constr.id]
    sense = getcursense(constr)
    if nb_inf_sources == 0
        if sense != Less && alg_data.cur_min_slack[constr.id] > 0.0001
            return true
        elseif sense == Less && alg_data.cur_min_slack[constr.id] >= 0.0001
            #add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if sense != Less
            add_to_stack(alg_data, constr, form)
        end
    end
    return false
end

function add_to_stack(alg_data::PreprocessData, constr::Constraint, form::Formulation)
    if !alg_data.constr_in_stack[constr.id]
        push!(alg_data.stack, (constr, form))
        alg_data.constr_in_stack[constr.id] = true
    end
end
      
function update_lower_bound(alg_data::PreprocessData, 
	                    var::Variable,
			    form::Formulation,
                            new_lb::Float64, 
			    check_monotonicity::Bool = true)
    cur_lb = getcurlb(var)
    cur_ub = getcurub(var)
    if new_lb > cur_lb || !check_monotonicity
        if new_lb > cur_ub
            return true
        end

        diff = cur_lb == -Inf ? -new_lb : cur_lb - new_lb
        coef_matrix = getcoefmatrix(form)
        for (constr_id, coef) in filter(_active_explicit_, coef_matrix[:, getid(var)])
             func = coef < 0 ? update_min_slack : update_max_slack
             if func(alg_data, getconstr(form, constr_id), form, cur_lb == -Inf , diff*coef)
                 return true
             end
         end
         if alg_data.printing
             println("updating lb of var $(getname(var)) from "*
                     "$(cur_lb) to $(new_lb). duty $(getduty(var))")
         end
         setlb!(form, var, new_lb)

         #now we update bounds of clones
         if var.duty == MasterRepPricingVar 
             subprob = find_owner_formulation(form.parent_formulation, var)
             (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(subprob)]
	     clone_in_sp = getvar(subprob, getid(var))
             if update_lower_bound(alg_data, clone_in_sp, subprob, getcurlb(var) - (max(sp_ub, 1) - 1)*getcurub(clone_in_sp))
                 return true
             end
         elseif var.duty == DwSpPricingVar
	     master = form.parent_formulation
             (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(form)]
	     clone_in_master = getvar(master, getid(var))
             if update_lower_bound(alg_data, clone_in_master, master, getcurlb(var) * sp_lb)
                 return true
             end
             new_ub_in_sp = getcurub(clone_in_master) - (max(sp_lb, 1) - 1) * getcurlb(var)
             if update_upper_bound(alg_data, var, form, new_ub_in_sp)
                 return true
             end
	 end
     end
     return false
end

function update_upper_bound(alg_data::PreprocessData, 
	                    var::Variable,
			    form::Formulation,
                            new_ub::Float64, 
			    check_monotonicity::Bool = true)
    cur_lb = getcurlb(var)
    cur_ub = getcurub(var)
    if new_ub < cur_ub || !check_monotonicity
        if new_ub < cur_lb
            return true
        end

        diff = cur_ub == Inf ? -new_ub : cur_ub - new_ub
        coef_matrix = getcoefmatrix(form)
        for (constr_id, coef) in filter(_active_explicit_, coef_matrix[:, getid(var)])
             func = coef > 0 ? update_min_slack : update_max_slack
             if func(alg_data, getconstr(form, constr_id), form, cur_ub == Inf , diff*coef)
                 return true
             end
         end
         if alg_data.printing
             println("updating ub of var $(getname(var)) from "*
                     "$(cur_ub) to $(new_ub). duty $(getduty(var))")
         end
         setub!(form, var, new_ub)
 
         #now we update bounds of clones
         if var.duty == MasterRepPricingVar 
             subprob = find_owner_formulation(form.parent_formulation, var)
             (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(subprob)]
	     clone_in_sp = getvar(subprob, getid(var))
             if update_upper_bound(alg_data, clone_in_sp, subprob, getcurub(var) - (max(sp_lb, 1) - 1)*getcurlb(clone_in_sp))
                 return true
             end
         elseif var.duty == DwSpPricingVar
	     master = form.parent_formulation
             (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(form)]
	     clone_in_master = getvar(master, getid(var))
             if update_upper_bound(alg_data, clone_in_master, master, getcurub(var) * sp_ub)
                 return true
             end
             new_lb_in_sp = getcurlb(clone_in_master) - (max(sp_ub, 1) - 1) * getcurub(var)
             if update_lower_bound(alg_data, var, form, new_lb_in_sp)
                 return true
             end
	 end
     end
     return false
end

function adjust_bound(var::Variable, bound::Float64, is_upper::Bool)
    if getcurkind(var) != Continuous 
        bound = is_upper ? floor(bound) : ceil(bound)
    end
    return bound
end

 function compute_new_var_bound(alg_data::PreprocessData,
	                        var::Variable, 
				cur_lb::Float64, 
                                cur_ub::Float64, 
				coef::Float64, 
				constr::Constraint)

    function compute_new_bound(nb_inf_sources::Int, 
	                       slack::Float64, 
                               var_contrib_to_slack::Float64, 
			       inf_bound::Float64)
        if nb_inf_sources == 0
            bound = (slack - var_contrib_to_slack)/coef
        elseif nb_inf_sources == 1 && isinf(var_contrib_to_slack)
            bound = slack/coef 
        else
            bound = inf_bound
        end
        return bound
    end

    if coef > 0 && getcursense(constr) == Less
        is_ub = true
        return (is_ub, compute_new_bound(alg_data.nb_inf_sources_for_max_slack[constr.id],
                                         alg_data.cur_max_slack[constr.id], -coef*cur_lb, Inf))
    elseif coef > 0 && getcursense(constr) != Less
        is_ub = false
        return (is_ub, compute_new_bound(alg_data.nb_inf_sources_for_min_slack[constr.id], 
                                         alg_data.cur_min_slack[constr.id], -coef*cur_ub, -Inf))
    elseif coef < 0 && getcursense(constr) != Greater
        is_ub = false
        return (is_ub, compute_new_bound(alg_data.nb_inf_sources_for_max_slack[constr.id],
                                         alg_data.cur_max_slack[constr.id], -coef*cur_ub, -Inf))
    else
        is_ub = true
        return (is_ub, compute_new_bound(alg_data.nb_inf_sources_for_min_slack[constr.id], 
                                         alg_data.cur_min_slack[constr.id], -coef*cur_lb, Inf))
    end
end

function analyze_constraint(alg_data::PreprocessData, constr::Constraint, form::Formulation)
    if constr.duty <:AbstractMasterConstr
       var_filter = _rep_of_orig_var_ 
    else
       var_filter = (var -> (var.duty == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[constr.id,:]
         var = getvar(form, var_id)
         if !var_filter(var) 
             continue
         end
         (is_ub, bound) = compute_new_var_bound(alg_data, var, getcurlb(var), getcurub(var),
                                                coef, constr) 
         if !isinf(bound)
             bound = adjust_bound(var, bound, is_ub)
             func = is_ub ? update_upper_bound : update_lower_bound
             if func(alg_data, var, form, bound)
                 return true
             end
         end
     end
     return false
 end

function propagation(alg_data::PreprocessData)
     while !isempty(alg_data.stack)
         (constr, form) = pop!(alg_data.stack)
         alg_data.constr_in_stack[constr.id] = false

         if alg_data.printing
             println("constr $(getname(constr)) $(typeof(constr)) popped")
	     println("rhs $(getcurrhs(constr)) max: $(alg_data.cur_max_slack[constr.id]) min: $(alg_data.cur_min_slack[constr.id])")
         end
         if analyze_constraint(alg_data, constr, form)
             return true
         end
     end
     return false
end

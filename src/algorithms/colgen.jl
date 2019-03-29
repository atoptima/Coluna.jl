function optimize!(r::Reformulation)
    
    println("\e[1;31m draft of the col gen algorithm here \e[00m")
    return
end

function update_pricing_problem(sp_form::Formulation, dual_sol::ConstrMembership)
    new_obj = Dict{VarId, Float64}()

    active = true
    static = true

    master_form = sp_form.parent_formulation

    var_uids = getvar_uids(sp_form, PricingSpVar)

    ### compute red costs
   for (constr_uid, dual_val) in dual_sol
        membership = get_var_members_of_constr(master_form.memeberships, constr_uid)

        var_membership = intersect(membership, var_uids)
           
        for (var_uid, coef) in var_membership
            if haskey(new_obj, var_uid)
                new_obj[var_uid] -= dual_val * coef
            end
        end
    end

    println("new objective func = ", new_obj)

    set_optimizer_obj(sp_form, new_obj)

    return false
end


 function update_pricing_target(sp_form::Formulation)
     println("pricing target will only be needed after automating convexity constraints")
 end


 function insert_cols_in_master(sp_form::Formulation,
                                sp_sols::Vector{PrimalSolution})

     # TODO add tolerances 

     sp_uid = getuid(sp_form)
     master_form = sp_form.parent
     m = master_form.memberships
     nb_of_gen_col = 0
     
     var_uids = getvar_uids(sp_form, PricingSpSetupVar)
     @assert length(var_uids) == 1
     setup_var_uid = var_uids[1]

     for sp_sol in sp_sols
         if sp_sol.value < -0.0001
             
             nb_of_gen_col += 1
             name = "MC_$(sp_uid)"
             cost = compute_original_cost(sp_sol,sp_form)
             lb = 0.0
             ub = Inf
             kind = Continuous
             flag = Dynamic
             duty = MasterCol
             sense = Positive
             mc_var = Variable(m, getuid(master_form), name, cost, lb, ub, kind, flag, duty, sense)
             mc_uid = getuid(mc_var)
             name = "MC_$(sp_uid)_$(mc_uid)"
             setname!(mc_var, name)
             
 
             ### compute column vector
             for (var_uid, var_val) in sp_sol.var_members
                 for (constr_uid, var_coef) in get_constr_members_of_var(m, var_uid)
                     add_constr_members_of_var!(m, mc_uid, constr_uid, var_val * var_coef)
                 end
             end 
             for (constr_uid, var_coef) in get_constr_members_of_var(m, setup_var_uid)
                 add_constr_members_of_var!(m, mc_uid, constr_uid, var_coef)
             end
             
             ### record Sp solution
             add_var_members_of_partialsol!(master_form.memberships, mc_uid, sp_sol.var_members)
             add_var_members_of_partialsol!(master_form.memberships, mc_uid, setup_var_uid, 1.0)
 
             #update_moi_membership(master_form, mc_var)

             @show string("added column ", mc_var)
             # TODO  do while sp_sol.next exists
         end
     end
     
     return nb_of_gen_col
 end


# function gen_new_col(sp_form::Formulation)

#     flag_need_not_generate_more_col = 0 # Not used
#     flag_is_sp_infeasible = -1
#     flag_cannot_generate_more_col = -2 # Not used
#     dual_bound_contrib = 0 # Not used
#     pseudo_dual_bound_contrib = 0 # Not used

#     # TODO renable this. Needed at least for the diving
#     # if can_not_generate_more_col(princing_prob)
#     #     return flag_cannot_generate_more_col
#     # end

#     # Compute target
#     update_pricing_target(alg, sp_form)

#     # Reset var bounds, var cost, sp minCost
#     if update_pricing_prob(alg, sp_form) # Never returns true
#         #     This code is never executed because update_pricing_prob always returns false
#         #     @logmsg LogLevel(-3) "pricing prob is infeasible"
#         #     # In case one of the subproblem is infeasible, the master is infeasible
#         #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
#         #     return flag_is_sp_infeasible
#     end
#     # if alg.colgen_stabilization != nothing && true #= TODO add conds =#
#     #     # switch off the reduced cost estimation when stabilization is applied
#     # end

#     # Solve sub-problem and insert generated columns in master

    
#     status, p_sol, d_sol = optimize(sp_form)

#     compute_pricing_dual_bound_contrib(alg, sp_form)
#     if status != MOI.OPTIMAL
#         return flag_is_sp_infeasible
#     end
#     insertion_status = insert_cols_in_master(alg, sp_form)
#     return insertion_status
# end

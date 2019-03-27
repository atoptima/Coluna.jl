function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             sp_form::Formulation)

    #@timeit to(alg) "update_pricing_prob"
    #begin
        new_obj = Dict{VarId, Float64}()
        
        alg.pricing_const_obj[pricing_prob] = 0

        active = true
        static = true

        master_form = sp_form.parent_formulation
 
        var_uids = getvar_uids(sp_form, PricingSpVar)

        new_obj = get_red_costs(master_form, var_uids)

        @logmsg LogLevel(-3) string("new objective func = ", new_obj)

        set_optimizer_obj(sp_form, new_obj)

    #end # @timeit to(alg) "update_pricing_prob"
    return false
end

function update_pricing_target(alg::AlgToEvalNodeByLagrangianDuality,
                               sp_form::Formulation)

    @logmsg LogLevel(-3) ("pricing target will only be needed after" *
                          "automating convexity constraints")
end

function insert_cols_in_master(alg::AlgToEvalNodeByLagrangianDuality,
                               sp_form::Formulation,
                               sp_sol::PrimalSolution)

    # TODO add tolerances 
    
    sp_uid = getuid(sp_form)
    master_form = sp_form.parent

    if sp_sol.value < -0.0001
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
        
        membership = sp_sol.var_members
        
        add_partialsol_members_of_var!(master_form.memberships, mc_var, membership)

        var_uids = getvar_uids(sp_form, PricingSpSetupVar)
        @assert length(var_uids) == 1
        add_var!(membership, var_uids[1], 1.0)
        
        add!(master_form, mc_var, membership)
       
        
        #col = MasterColumnConstructor(master.counter, sp_sol) # generates memberships
        #convexity_lb = alg.extended_problem.pricing_convexity_lbs[pricing_prob]
        #convexity_ub = alg.extended_problem.pricing_convexity_ubs[pricing_prob]
        #add_membership(col, convexity_lb, 1.0; optimizer = nothing)
        #add_membership(col, convexity_ub, 1.0; optimizer = nothing)
        #add_variable(master, col; update_moi = true) # updates moi, doesnt touch membership

        update_moi_membership(master_form, mc_var)
        
        @logmsg LogLevel(-2) string("added column ", mc_var)
        # TODO  do while sp_sol.next exists
        return 1
    else
        return 0
    end
end


function gen_new_col(alg::AlgToEvalNodeByLagrangianDuality,
                     sp_form::Formulation)
    
    @timeit to(alg) "gen_new_col" begin

        flag_need_not_generate_more_col = 0 # Not used
        flag_is_sp_infeasible = -1
        flag_cannot_generate_more_col = -2 # Not used
        dual_bound_contrib = 0 # Not used
        pseudo_dual_bound_contrib = 0 # Not used

        # TODO renable this. Needed at least for the diving
        # if can_not_generate_more_col(princing_prob)
        #     return flag_cannot_generate_more_col
        # end

        # Compute target
        update_pricing_target(alg, sp_form)
        
        # Reset var bounds, var cost, sp minCost
        @logmsg LogLevel(-3) "updating pricing prob"
        if update_pricing_prob(alg, sp_form) # Never returns true
            #     This code is never executed because update_pricing_prob always returns false
            #     @logmsg LogLevel(-3) "pricing prob is infeasible"
            #     # In case one of the subproblem is infeasible, the master is infeasible
            #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
            #     return flag_is_sp_infeasible
        end
        # if alg.colgen_stabilization != nothing && true #= TODO add conds =#
        #     # switch off the reduced cost estimation when stabilization is applied
        # end

        # Solve sub-problem and insert generated columns in master
        @logmsg LogLevel(-3) "optimizing pricing prob"
        @timeit to(alg) "optimize!(pricing_prob)" begin
            status, p_sol, d_sol = optimize(sp_form)
        end
        compute_pricing_dual_bound_contrib(alg, sp_form)
        if status != MOI.OPTIMAL
            @logmsg LogLevel(-3) "pricing prob is infeasible"
            return flag_is_sp_infeasible
        end
        @timeit to(alg) "insert_cols_in_master" begin
            insertion_status = insert_cols_in_master(alg, sp_form)
        end
        return insertion_status

    end # @timeit to(alg) "gen_new_col" begin
end

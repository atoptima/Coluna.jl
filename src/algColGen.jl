function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             sp_form::Formulation)

    @timeit to(alg) "update_pricing_prob"
    begin
        new_obj = SparseVector{Float64, MOI.VariableIndex}()
        alg.pricing_const_obj[pricing_prob] = 0

        active = true
        static = true


        var_uids = getvar_uids(sp_form, PricingSpVar)

       for var_uid in var_uids
            var = sp_form.vars[var_uid]
            @logmsg LogLevel(-4) string("$var original cost = ", getcost(var))
            new_obj[var.index] = getcost(var)
        end

        master_form = sp_form.parent_formulation
        dual_solution = get_dual_sol(alg)
        for (constr_uid, dual_val) in dual_solution
            #@assert (constr isa MasterConstr) || (constr isa MasterBranchConstr)
            #if constr isa ConvexityConstr &&
            #    (extended_prob.pricing_convexity_lbs[pricing_prob] == constr ||
            #     extended_prob.pricing_convexity_ubs[pricing_prob] == constr)
            #    alg.pricing_const_obj[pricing_prob] -= dual
            #    continue
            # end
            var_membership = get_var_members_of_constr(master_form, constr_uid)
            for (var_uid, coef) in constr_membership
                if haskey(new_obj, var) 
                if haskey(new_obj, var)
                    new_obj[var] -= dual * coef
                end
            end
        end
        @logmsg LogLevel(-3) string("new objective func = ", new_obj)
        set_optimizer_obj(pricing_prob.optimizer, new_obj)

    end # @timeit to(alg) "update_pricing_prob"
    return false
end

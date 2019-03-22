function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             pricing_prob::Formulation)

    @timeit to(alg) "update_pricing_prob"
    begin
        new_obj = SparseVector{Float64, MOI.VariableIndex}()
        alg.pricing_const_obj[pricing_prob] = 0

        active = true
        static = true
        var_members = get_var_list(pricing_prob, actice, static)
        for (var_uid, var) in var_members
            @logmsg LogLevel(-4) string("$var original cost = ", var.cost)
            new_obj[var.index] = get_var_cost(pricing_prob,var_uid)
        end
       # master_form = pricing_prob.parent.master
        dual_solution = get_dual_sol(alg)
        for (constr_uid, dual_val) in dual_solution
            #@assert (constr isa MasterConstr) || (constr isa MasterBranchConstr)
            #if constr isa ConvexityConstr &&
            #    (extended_prob.pricing_convexity_lbs[pricing_prob] == constr ||
            #     extended_prob.pricing_convexity_ubs[pricing_prob] == constr)
            #    alg.pricing_const_obj[pricing_prob] -= dual
            #    continue
            # end
            constr_membership = get_var_member(pricing_prob, constr_uid)
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

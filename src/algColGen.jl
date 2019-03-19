function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             pricing_prob::Formulation)

    @timeit to(alg) "update_pricing_prob"
    begin
        new_obj = SparseVector{Float64, MoiIndex}()
        alg.pricing_const_obj[pricing_prob] = 0

        active = true
        static = true
        var_members = get_list(pricing_prob.var_manager, actice, static)
        for (var_uid, var) in var_members
            @logmsg LogLevel(-4) string("$var original cost = ", var.cost)
            new_obj[var.moi_def.index] = var.cost
        end
        parent_prob = 
        master_form = pricing_prob.parent.master
        duals_dict = master.dual_sol.constr_val_map
        for (constr, dual) in duals_dict
            @assert (constr isa MasterConstr) || (constr isa MasterBranchConstr)
            if constr isa ConvexityConstr &&
                (extended_prob.pricing_convexity_lbs[pricing_prob] == constr ||
                 extended_prob.pricing_convexity_ubs[pricing_prob] == constr)
                alg.pricing_const_obj[pricing_prob] -= dual
                continue
            end
            for (var, coef) in constr.subprob_var_coef_map
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

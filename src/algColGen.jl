
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

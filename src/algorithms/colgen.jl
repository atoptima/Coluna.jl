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

    sp_uid = getuid(sp_form)
    master_form = sp_form.parent
    m = master_form.memberships
    nb_of_gen_col = 0
    
    var_uids = getvar_uids(sp_form, PricingSpSetupVar)
    @assert length(var_uids) == 1
    setup_var_uid = var_uids[1]

    for sp_sol in sp_sols
        if sp_sol.value < -0.0001 # TODO use tolerance
            
            ### add setup_var in sp sol
            add!(sp_sol.var_members, setup_var_uid, 1.0)

            ### check if sp sol exists as a registered column
            id_of_existing_mc = check_if_exists(master_form.memberships.partialsol_to_var_members,
                                                sp_sol.var_members)

            if id_of_existing_mc > 0 # already exists
                @show string("column already exists as", id_of_existing_mc)
            else
                
                
                ### create new column
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

                
                
                #update_moi_membership(master_form, mc_var)

                @show string("added column ", mc_var)
                # TODO  do while sp_sol.next exists
            end
        end
    end

    return nb_of_gen_col
end

function compute_pricing_dual_bound_contrib(sp_form::Formulation,
                                            sp_sol_value::Float64,
                                            sp_lb::Float64,
                                            sp_ub::Float64)
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost * multiplicty

    contrib =  sp_sol_value * sp_ub
    @logmsg LogLevel(-2) string("princing prob has contribution = ", contrib)
    return contrib
end

function gen_new_col(sp_form::Formulation,
                     dual_sol::ConstrMembership,
                     sp_lb::Float64,
                     sp_ub::Float64)
    
    # @timeit to(alg) "gen_new_col" begin

    #flag_need_not_generate_more_col = 0 # Not used
    flag_is_sp_infeasible = -1
    #flag_cannot_generate_more_col = -2 # Not used
    #dual_bound_contrib = 0 # Not used
    #pseudo_dual_bound_contrib = 0 # Not used

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_col(princing_prob)
    #     return flag_cannot_generate_more_col
    # end

    # Compute target
    update_pricing_target(sp_form)

    # Reset var bounds, var cost, sp minCost
    if update_pricing_prob(sp_form, dual_sol) # Never returns true
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
    #@timeit to(alg) "optimize!(pricing_prob)"
    #begin
    status, value, p_sols, d_sol = optimize(sp_form)
    #end
    
    dual_bound_contrib = compute_pricing_dual_bound_contrib(sp_form, value, sp_lb, sp_ub)
    
    if status != MOI.OPTIMAL
        @logmsg LogLevel(-3) "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end
    insertion_status = insert_cols_in_master(sp_form, p_sols)
    
    return (insertion_status, dual_bound_contrib)

    #end # @timeit to(alg) "gen_new_col" begin

end

function gen_new_columns(reformulation::Reformulation,
    dual_sol::ConstrMembership,
    sp_lbs::Dict{FormId, Float64},
    sp_ubs::Dict{FormId, Float64})
    
    nb_new_col = 0
    dual_bound_contrib = 0.0
    
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)
        (gen_status, contrib) = gen_new_col(sp_form, dual_sol, sp_lbs[sp_uid], sp_ubs[sp_uid])
        
        if gen_status > 0
            nb_new_col += gen_status
            dual_bound_contrib += contrib
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, Inf)
        end
    end
    return (nb_new_col, dual_bound_contrib)
end


function solve_restricted_mast(master::Formulation)
    @logmsg LogLevel(-2) "starting solve_restricted_mast"
    #@timeit to(alg) "solve_restricted_mast" begin
 
    status, value, primal_sols, dual_sol = optimize(master)
    # @shows status
    # @show result_count = MOI.get(master.optimizer, MOI.ResultCount())
    # @show primal_status = MOI.get(master.optimizer, MOI.PrimalStatus())
    # @show dual_status = MOI.get(master.optimizer, MOI.DualStatus())
    #end # @timeit to(alg) "solve_restricted_mast"
    return status, value, primal_sols[1], dual_sol.members
end


#==
function update_lagrangian_dual_bound(alg::AlgToEvalNodeByLagrangianDuality,
                                      update_dual_bound::Bool)
    mast_lagrangian_bnd = 0
    mast_lagrangian_bnd = compute_mast_dual_bound_contrib(alg)
    @logmsg LogLevel(-2) string("dual bound contrib of master = ",
                               mast_lagrangian_bnd)

    # Subproblem contributions
    for pricing_prob in alg.extended_problem.pricing_vect
        mast_lagrangian_bnd += alg.pricing_contribs[pricing_prob]
        @logmsg LogLevel(-2) string("dual bound contrib of SP[",
                   pricing_prob.prob_ref, "] = ",
                   alg.pricing_contribs[pricing_prob],
                   ". mast_lagrangian_bnd = ", mast_lagrangian_bnd)
    end

    @logmsg LogLevel(-2) string("UPDATED CURRENT DUAL BOUND. lp_primal_bound = ",
              alg.sols_and_bounds.alg_inc_lp_primal_bound,
              ". mast_lagrangian_bnd = ", mast_lagrangian_bnd)

    #TODO: clarify this comment
    # by Guillaume : subgradient algorithm needs to know when the incumbent
    if update_dual_bound
        update_dual_lp_bound(alg.sols_and_bounds, mast_lagrangian_bnd)
        update_dual_ip_bound(alg.sols_and_bounds, mast_lagrangian_bnd)
    end
    # if alg.colgen_stabilization != nothing
    #     update_dual_lp_bound(alg.sols_and_bounds, mast_lagrangian_bnd)
    #     update_dual_ip_bound(alg.sols_and_bounds, mast_lagrangian_bnd)
    # end
end
==#

function solve_mast_lp_ph2(reformulation::Reformulation)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    while true
        # glpk_prob = alg.extended_problem.master_problem.optimizer.optimizer.inner
        # GLPK.write_lp(glpk_prob, string("/Users/vitornesello/Desktop/mip_", nb_cg_iterations,".lp"))
        # solver restricted master lp and update bounds
        status_rm, master_val, primal_sol, dual_sol = solve_restricted_mast(reformulation.master)
        #status_rm, mst_time, b, gc, allocs = @timed solve_restricted_mast(reformulation.master)
        # status_rm, mas_time = solve_restricted_mast(alg)
        # if alg.colgen_stabilization != nothing # Never evals to true
        #     # This function does not exist
        #     init_after_solving_restricted_mast(colgen_stabilization,
        #             computeOptimGap(alg), nbCgIterations,
        #             curMaxLevelOfSubProbRestriction)
        # end

        if status_rm == MOI.INFEASIBLE || status_rm == MOI.INFEASIBLE_OR_UNBOUNDED
            @logmsg LogLevel(-2) "master restrcited lp solver returned infeasible"
            #mark_infeasible(alg)
            return true
        end
        ##update_alg_primal_lp_incumbents(alg, master_val)
        ##update_alg_primal_ip_incumbents(alg, master_val, primal_sol)
        ##cleanup_restricted_mast_columns(alg, nb_cg_iterations)
        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        nb_new_col = 0
        sp_time = 0.0
        while true
            @logmsg LogLevel(-2) "need to generate new master columns"
            nb_new_col, dual_bound_contrib =  gen_new_columns(alg)
           # nb_new_col, sp_time, b, gc, allocs = @timed gen_new_columns(alg)
            # In case subproblem infeasibility results in master infeasibility
            if nb_new_col < 0
                #mark_infeasible(alg)
                return true
            end
            ###TD update_lagrangian_dual_bound(dual_bound_contrib, true)
            # if alg.colgen_stabilization == nothing
            #|| !update_after_pricing_problem_solution(alg.colgen_stabilization, nb_new_col)
            break
            # end
        end

       ##TD print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations, mst_time, sp_time)
        # if alg.colgen_stabilization != nothing
        #     # This function does not exist
        #     update_after_colgen_iteration(alg.colgen_stabilization)
        # end
        @logmsg LogLevel(-2) string("colgen iter ", nb_cg_iterations,
                                   " : inserted ", nb_new_col, " columns")

       ##TD lower_bound = alg.sols_and_bounds.alg_inc_ip_dual_bound
        ##TDupper_bound = alg.sols_and_bounds.alg_inc_lp_primal_bound
        # upper_bound = min(alg.sols_and_bounds.alg_inc_lp_primal_bound,
        #                   alg.sols_and_bounds.alg_inc_ip_primal_bound)

        ##TDif nb_new_col == 0 || lower_bound + 0.00001 > upper_bound
       ##TD     alg.is_master_converged = true
       ##TD     return false
       ##TD end
        if nb_cg_iterations > 100 ##TDalg.max_nb_cg_iterations
            @logmsg LogLevel(-2) "max_nb_cg_iterations limit reached"
            ##TDmark_infeasible(alg)
            return true
        end
        @logmsg LogLevel(-2) "next colgen ph2 iteration"
    end
    # These lines are never executed becasue there is no break from the outtermost 'while true' above
    # @logmsg LogLevel(-2) "solve_mast_lp_ph2 has finished"
    # return false
end

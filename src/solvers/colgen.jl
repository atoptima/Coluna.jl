struct ColumnGeneration <: AbstractSolver end

struct ColumnGenerationRecord <: AbstractSolverRecord
    nb_iterations::Int
end

function setup(::Type{ColumnGeneration}, f, n)
    println("\e[31m Setup ColumnGeneration \e[00m")
end

function run(::Type{ColumnGeneration}, f, n, p)
    # db = 0
    # nb_iter = 0
    # for i in 1:rand(10:20)
    #     db += rand(0:0.01:100)
    #     mlp = rand(2000:0.01:2500)
    #     println("<it=$i> <DB=$db> <Mlp=$mlp>")
    #     nb_iter += 1
    #     sleep(0.3)
    # end
    println("\e[1;31m draft of the col gen algorithm here \e[00m")
    println("main function of the alg")
    alg = SimplexLpColGenAlg(f.master.obj_sense)
    solve_mast_lp_ph2(alg, f)
    nb_iter = 0
    return ColumnGenerationRecord(nb_iter)
end

function record_output(::Type{ColumnGeneration}, f, n)
    println("\e[31m record column generation \e[00m")
end
#### Methods for colgen 

mutable struct SimplexLpColGenAlg <: AbstractAlg
    incumbents::Incumbents
    is_converged::Bool
    is_infeasible::Bool
end

SimplexLpColGenAlg(S::Type{<:AbstractObjSense}) = SimplexLpColGenAlg(Incumbents(S), false, false)


function update_pricing_problem(sp_form::Formulation, dual_sol::DualSolution)

    #new_obj = VarMembership(get_vars(sp_form))
    #master_form = sp_form.parent_formulation

    ### initialized costs
    active_sp_vars = filter(_active_pricingSpVar_ , get_vars(sp_form))

    for (id, var) in active_sp_vars
        set_cost!(get_cur_data(var), get_cost(get_initial_data(var)))
    end

    coefficient_matrix = get_coefficient_matrix(sp_form.parent_formulation)


    #println("all vars: ")
    #for (id, var) in get_vars(sp_form.parent_formulation)
    #    println(get_name(var), " : ", get_cost(get_cur_data(var)))
    #end



    println("Costs before: ")
    for (id, var) in active_sp_vars
        println(get_name(var), " : ", get_cost(get_cur_data(var)))
    end

    ## compute reduced cost
    for (constr_id, dual_val) in getsol(dual_sol)

        println("update reduced cost vars of constr: ", constr_id, " with dual val : ", dual_val)

        println("--------------> All vars with its coeffs")
        for (id, coeff) in coefficient_matrix[constr_id, :]
            println(id, " : ", coeff)
        end

        #active_sp_rep_memb_vars = filter(_active_pricingMastRepSpVar_, coefficient_matrix[constr_id, :])
        active_sp_rep_memb_vars =  coefficient_matrix[constr_id, :]

        for (var_id, coeff) in active_sp_rep_memb_vars
            println("Modifying reduced cost of variable: ", var_id)
            if haskey(active_sp_vars, var_id)
                var = get_element(active_sp_vars, var_id)
                println("new cost for sp var : ", get_name(var))
                vardata = get_cur_data(var) # shortcut needed
                set_cost!(vardata, get_cost(vardata) - dual_val * coeff)

                println("new cost: ", get_cost(vardata))
            end
            


            # set cost also in sp
            #sp_var = getvar(sp_form, var_id)
            #sp_vardata = get_cur_data(sp_var)
            #set_cost!(sp_vardata, get_cost(vardata))
        end

    end

    println("Costs after: ")
    for (id, var) in active_sp_vars
        println(get_name(var), " : ", get_cost(get_cur_data(var)))
    end


    set_optimizer_obj(get_optimizer(sp_form), active_sp_vars) #filter(_explicit_, get_vars(sp_form)))


    # println("initialized costs = ", new_obj)

    ### compute red costs
    # for (constr_id, dual_val) in getsol(dual_sol)
    #     #println("Compute contrib of constraint ", constr_id)
    #     #@show get_var_members_of_constr(master_form.memberships, constr_id)

    #     #var_membership = filter(_active_MspVar_, get_var_members_of_constr(master_form.memberships, constr_id))

    #     for (m_rep_var_id, coef) in var_membership
    #         #println("var : ", m_rep_var_id, " (", get_duty(getstate(m_rep_var_id)), ")")
    #         sp_var_id = getkey(sp_vars, m_rep_var_id, Id{VarState}(-1))
    #         #println("collect Sp var : ", sp_var_id, " (", get_duty(getstate(sp_var_id)), ")")
    #         sp_var_id.uid == -1 && continue
    #         cost = get_cost(getstate(sp_var_id))
    #         setcost(getstate(sp_var_id), cost - dual_val * coef)
    #     end
    # end

    # #println("update_pricing_problem: new objective func = ", new_obj)


    return false
end


function update_pricing_target(sp_form::Formulation)
    println("pricing target will only be needed after automating convexity constraints")
end


function insert_cols_in_master(master_form::Formulation,
                               sp_form::Formulation,
                               sp_sols::Vector{PrimalSolution{S}}) where {S}

    println("\e[1;32m insert cols in master \e[00m")
    sp_uid = get_uid(sp_form)
    #mbship = master_form.memberships
    nb_of_gen_col = 0
    
    #var_uids = getvar_uids(sp_form, PricingSpSetupVar)
    #@assert length(var_uids) == 1
    #setup_var_uid = var_uids[1]

    @show sp_sols

    for sp_sol in sp_sols
        if getvalue(sp_sol) < -0.0001 # TODO use tolerance
            println(" >>>> \e[33m  create new column \e[00m")
            ### add setup_var in sp sol: already in solution
            #add!(sp_sol.var_membeprs, setup_var_uid, 1.0)

            ### TODO  : check if sp sol exists as a registered column

            #if id_of_existing_mc > 0 # already exists
            #    @warn string("column already exists as", id_of_existing_mc)
            #else
                ### create new column
                nb_of_gen_col += 1
                name = "MC_$(sp_uid)"
                cost = compute_original_cost(sp_sol, sp_form)
                lb = 0.0
                ub = Inf
                kind = Continuous
                duty = MasterCol
                sense = Positive
                mc_var = Variable(get_uid(master_form), name, cost, lb, ub, kind, sense)
                mc_id = add!(master_form, mc_var, duty)
                #add!(mbship, mc_id)
                name = "MC_$(sp_uid)_$(get_uid(mc_id))"
                setname!(mc_var, name)

                @show "new column" mc_id mc_var
                
                ### compute column vector
                # for (var_id, var_val) in sp_sol.var_members
                #     for (constr_id, var_coef) in get_constr_members_of_var(mbship, var_id)
                #         add_constr_members_of_var!(mbship, mc_id, constr_id, var_val * var_coef)
                #     end
                # end
                # setup var is in the sp_sol
                #for (constr_uid, var_coef) in get_constr_members_of_var(m, setup_var_uid)
               #     add_constr_members_of_var!(m, mc_uid, constr_uid, var_coef)
               # end
                
                ### record Sp solution
                #add_var_members_of_partialsol!(mbship, mc_id, sp_sol.var_members)

                
                
                #update_moi_membership(master_form, mc_var)

                @show string("added column ", mc_id, mc_var)
                # TODO  do while sp_sol.next exists
            #end
        end
    end

    return nb_of_gen_col
end

function compute_pricing_dual_bound_contrib(sp_form::Formulation,
                                            sp_sol_value::PrimalBound{S},
                                            sp_lb::Float64,
                                            sp_ub::Float64) where {S}
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost * multiplicty
    if ( sp_sol_value <= 0) 
        contrib =  sp_sol_value * sp_ub
    else
        contrib =  sp_sol_value * sp_lb
    end
    
        
    @logmsg LogLevel(-2) string("princing prob has contribution = ", contrib)
    return contrib
end

function gen_new_col(master_form::Formulation,
                     sp_form::Formulation,
                     dual_sol::DualSolution,
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
    if update_pricing_problem(sp_form, dual_sol) # Never returns true
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
    status, value, p_sols, d_sol = optimize!(sp_form)
    #end
    
    pricing_dual_bound_contrib = compute_pricing_dual_bound_contrib(sp_form, value, sp_lb, sp_ub)
    @show pricing_dual_bound_contrib
    
    if status != MOI.OPTIMAL
        @logmsg LogLevel(-3) "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end
    
    insertion_status = insert_cols_in_master(master_form, sp_form, p_sols)
    
    return (insertion_status, pricing_dual_bound_contrib)

    #end # @timeit to(alg) "gen_new_col" begin

end

function gen_new_columns(reformulation::Reformulation,
                         dual_sol::DualSolution{S},
                         sp_lbs::Dict{FormId, Float64},
                         sp_ubs::Dict{FormId, Float64}) where {S}

    nb_new_cols = 0
    dual_bound_contrib = DualBound(S, 0.0)
    master_form = getmaster(reformulation)
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = get_uid(sp_form)
        (gen_status, contrib) = gen_new_col(master_form, sp_form, dual_sol, sp_lbs[sp_uid], sp_ubs[sp_uid])

        if gen_status > 0
            nb_new_cols += gen_status
            dual_bound_contrib += contrib
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, Inf)
        end
    end
    return (nb_new_cols, dual_bound_contrib)
end

function solve_restricted_mast(master::Formulation)
    @logmsg LogLevel(-2) "starting solve_restricted_mast"
    #@timeit to(alg) "solve_restricted_mast" begin
 
    println("Solving master problem: ")
    @show master
    status, value, primal_sols, dual_sol = optimize!(master)
    @show status
    #@show result_count = MOI.get(master.moi_optimizer, MOI.ResultCount())
    #@show primal_status = MOI.get(master.moi_optimizer, MOI.PrimalStatus())
    #@show dual_status = MOI.get(master.moi_optimizer, MOI.DualStatus())
    @show value
    @show primal_sols
    @show dual_sol
    #end # @timeit to(alg) "solve_restricted_mast"
    return status, value, primal_sols[1], dual_sol
end


function compute_mast_dual_bound_contrib(alg::SimplexLpColGenAlg,
                                      restricted_master_sol_value::PrimalBound{S})where {S}
    # stabilization = alg.colgen_stabilization
    # This is commented because function is_active does not exist
    # if stabilization == nothing# || !is_active(stabilization)
        return DualBound(S, restricted_master_sol_value)
    # else
    #     error("compute_mast_dual_bound_contrib" *
    #           "is not yet implemented with stabilization")
    # end
end

function update_lagrangian_dual_bound(alg::SimplexLpColGenAlg,
                                      restricted_master_sol_value::PrimalBound{S},
                                      pricing_sp_dual_bound_contrib::DualBound{S},
                                      update_dual_bound::Bool) where {S}
    mast_lagrangian_bnd = DualBound(S, 0)
    mast_lagrangian_bnd += compute_mast_dual_bound_contrib(alg, restricted_master_sol_value)
    @logmsg LogLevel(-2) string("dual bound contrib of master = ",
                               mast_lagrangian_bnd)

    # Subproblem contributions
   # for pricing_prob in alg.extended_problem.pricing_vect
   #     mast_lagrangian_bnd += alg.pricing_contribs[pricing_prob]
    #    @logmsg LogLevel(-2) string("dual bound contrib of SP[",
   #                pricing_prob.prob_ref, "] = ",
   #                alg.pricing_contribs[pricing_prob],
   #                ". mast_lagrangian_bnd = ", mast_lagrangian_bnd)
   # end

    mast_lagrangian_bnd += pricing_sp_dual_bound_contrib

    @logmsg LogLevel(-2) string("UPDATED CURRENT DUAL BOUND. lp_primal_bound = ",
              alg.sols_and_bounds.alg_inc_lp_primal_bound,
              ". mast_lagrangian_bnd = ", mast_lagrangian_bnd)

            @show mast_lagrangian_bnd

    #TODO: clarify this comment
    # by Guillaume : subgradient algorithm needs to know when the incumbent
    if update_dual_bound
        set_dual_ip_bound!(alg.incumbents, mast_lagrangian_bnd)
        #update_dual_lp_bound(alg.incumbents, mast_lagrangian_bnd) TODO : should provide the dual lp sol
    else # if alg.colgen_stabilization != nothing
        set_dual_ip_bound!(alg.incumbents, mast_lagrangian_bnd)
        #update_dual_lp_bound(alg.incumbents, mast_lagrangian_bnd)
    end
    return mast_lagrangian_bnd
end

function solve_mast_lp_ph2(alg::SimplexLpColGenAlg,
                           reformulation::Reformulation)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    master_form = reformulation.master
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = get_uid(sp_form)
        lb_convexity_constr_id = reformulation.dw_pricing_sp_lb[sp_uid]
        ub_convexity_constr_id = reformulation.dw_pricing_sp_ub[sp_uid]
        sp_lbs[sp_uid] = get_rhs(get_constr(master_form, lb_convexity_constr_id))
        sp_ubs[sp_uid] = get_rhs(get_constr(master_form, ub_convexity_constr_id))
    end

    @show sp_lbs

    while true
        glpk_prob = master_form.moi_optimizer.inner
        GLPK.write_lp(glpk_prob, string(dirname(@__FILE__ ), "/mip_", nb_cg_iterations,".lp"))
        # solver restricted master lp and update bounds
        status_rm, master_val, primal_sol, dual_sol = solve_restricted_mast(master_form)

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

        set_primal_lp_sol!(alg.incumbents, primal_sol)
        # if integer update_primal_ip_incumbents(alg.incumbents, master_val, primal_sol.members)
        ##cleanup_restricted_mast_columns(alg, nb_cg_iterations)
        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        nb_new_col = 0
        sp_time = 0.0
        while true
            @logmsg LogLevel(-2) "need to generate new master columns"
            nb_new_col, sp_dual_bound_contrib =  gen_new_columns(reformulation,
                                                                 dual_sol,
                                                                 sp_lbs,
                                                                 sp_ubs)
            # nb_new_col, sp_time, b, gc, allocs = @timed gen_new_columns(alg)

            update_lagrangian_dual_bound(alg, master_val, sp_dual_bound_contrib, true)

            # In case subproblem infeasibility results in master infeasibility
            if nb_new_col < 0
                #mark_infeasible(alg)
                return true
            end
            # if alg.colgen_stabilization == nothing
            #|| !update_after_pricing_problem_solution(alg.colgen_stabilization, nb_new_col)
            # break
            # end
            break
        end

       ##TD print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations, mst_time, sp_time)
        # if alg.colgen_stabilization != nothing
        #     # This function does not exist
        #     update_after_colgen_iteration(alg.colgen_stabilization)
        # end
        #@logmsg LogLevel(-2) string
        println("colgen iter ", nb_cg_iterations,
                                   " : inserted ", nb_new_col, " columns")

        lower_bound = get_ip_dual_bound(alg.incumbents)
        upper_bound = min(
            get_lp_primal_bound(alg.incumbents), get_ip_primal_bound(alg.incumbents)
        )

       if nb_new_col == 0 || lower_bound + 0.00001 > upper_bound
            alg.is_converged = true
            return false
        end
        if nb_cg_iterations > 10 ##TDalg.max_nb_cg_iterations
            @logmsg LogLevel(-2) "max_nb_cg_iterations limit reached"
            alg.is_infeasible = true
            return true
        end
        @logmsg LogLevel(-2) "next colgen ph2 iteration"
    end
    # These lines are never executed becasue there is no break from the outtermost 'while true' above
    # @logmsg LogLevel(-2) "solve_mast_lp_ph2 has finished"
    # return false
end


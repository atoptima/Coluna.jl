##############################
#### AlgToEvalNodeByLp #######
##############################

mutable struct AlgToEvalNodeByLp <: AlgToEvalNode 
    sols_and_bounds::SolsAndBounds
    extended_problem::Reformulation
    sol_is_master_lp_feasible::Bool
    is_master_converged::Bool
end

function AlgToEvalNodeByLpBuilder(problem::Reformulation)
    return AlgToEvalNodeByLp(SolsAndBounds(), problem, false, false)
end

function print_intermediate_statistics(alg::AlgToEvalNodeByLp, solve_time::Float64)
    mlp = alg.sols_and_bounds.alg_inc_lp_primal_bound
    db = alg.sols_and_bounds.alg_inc_lp_dual_bound
    db_ip = alg.sols_and_bounds.alg_inc_ip_dual_bound
    pb = alg.sols_and_bounds.alg_inc_ip_primal_bound
    println("<et=", round(elapsed_solve_time()), "> ",
            "<lpt= ", round(solve_time, digits=3), "> ",
            "<mlp=", round(mlp, digits=4), "> ",
            "<DB=", round(db, digits=4), "> ",
            "<PB=", round(pb, digits=4), ">")
end

function run(alg::AlgToEvalNodeByLp, primal_ip_bound::Float64)
    alg.sols_and_bounds.alg_inc_ip_primal_bound = primal_ip_bound
    println("Starting eval by lp")

    res = @timed optimize(
        alg.extended_problem.master_problem
    )
    status = res[1][1]
    solve_time = res[2][1]

    if status == MOI.INFEASIBLE || status == MOI.INFEASIBLE_OR_UNBOUNDED
        println("Lp is infeasible, exiting treatment of node.")
        return true
    end

    alg.sol_is_master_lp_feasible = true
    update_alg_primal_lp_incumbents(alg)
    update_alg_primal_ip_incumbents(alg)
    lp_bound = alg.sols_and_bounds.alg_inc_lp_primal_bound
    update_dual_lp_bound(alg.sols_and_bounds, lp_bound)
    update_dual_ip_bound(alg.sols_and_bounds, lp_bound)

    print_intermediate_statistics(alg, solve_time)
    return false
end

#############################################
#### AlgToEvalNodeByLagrangianDuality #######
#############################################

# struct ColGenStabilization end
abstract type AlgToEvalNodeByLagrangianDuality <: AlgToEvalNode end

mutable struct AlgToEvalNodeBySimplexColGen <: AlgToEvalNodeByLagrangianDuality
    sols_and_bounds::SolsAndBounds
    extended_problem::Reformulation
    sol_is_master_lp_feasible::Bool
    is_master_converged::Bool
    pricing_contribs::Dict{AbstractFormulation, Float64}
    pricing_const_obj::Dict{AbstractFormulation, Float64}
    # colgen_stabilization::Union{ColGenStabilization, Nothing}
    max_nb_cg_iterations::Int
end

function AlgToEvalNodeBySimplexColGen(problem::Reformulation)
    return AlgToEvalNodeBySimplexColGen(SolsAndBounds(), problem, false,
            false, Dict{AbstractFormulation, Float64}(), 
            Dict{AbstractFormulation, Float64}(), 10000) # TODO put as parameter
end

function cleanup_restricted_mast_columns(alg::AlgToEvalNodeByLagrangianDuality,
                                         nb_cg_iterations::Int)

    @logmsg LogLevel(-2) "cleanup_restricted_mast_columns is empty for now"
end

function update_pricing_target(alg::AlgToEvalNodeByLagrangianDuality,
                               pricing_prob::AbstractFormulation)

    @logmsg LogLevel(-3) ("pricing target will only be needed after" *
                         "automating convexity constraints")
end

function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             pricing_prob::AbstractFormulation)

    @timeit to(alg) "update_pricing_prob" begin

    new_obj = Dict{SubprobVar, Float64}()
    alg.pricing_const_obj[pricing_prob] = 0
    for var in pricing_prob.var_manager.active_static_list
        @logmsg LogLevel(-4) string("$var original cost = ", var.cost_rhs)
        new_obj[var] = var.cost_rhs
    end
    extended_prob = alg.extended_problem
    master = extended_prob.master_problem
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

function compute_pricing_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality,
                                            pricing_prob::AbstractFormulation)
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost * multiplicty
    multiplicity_ub = alg.extended_problem.pricing_convexity_ubs[pricing_prob].cost_rhs
    const_obj = alg.pricing_const_obj[pricing_prob]
    @logmsg LogLevel(-4) string("princing prob has const obj = ", const_obj)
    contrib = (pricing_prob.primal_sol.cost + alg.pricing_const_obj[pricing_prob]) * multiplicity_ub
    alg.pricing_contribs[pricing_prob] = contrib
    @logmsg LogLevel(-2) string("princing prob has contribution = ", contrib)
end

function insert_cols_in_master(alg::AlgToEvalNodeByLagrangianDuality,
                               pricing_prob::AbstractFormulation)

    # TODO add tolerances
    sp_sol = pricing_prob.primal_sol
    if sp_sol.cost < -0.0001
        master = alg.extended_problem.master_problem
        col = MasterColumnConstructor(master.counter, sp_sol) # generates memberships
        convexity_lb = alg.extended_problem.pricing_convexity_lbs[pricing_prob]
        convexity_ub = alg.extended_problem.pricing_convexity_ubs[pricing_prob]
        add_membership(col, convexity_lb, 1.0; optimizer = nothing)
        add_membership(col, convexity_ub, 1.0; optimizer = nothing)
        add_variable(master, col; update_moi = true) # updates moi, doesnt touch membership
        update_moi_membership(master.optimizer, col)
        @logmsg LogLevel(-2) string("added column ", col)
        return 1
    else
        return 0
    end
end

function gen_new_col(alg::AlgToEvalNodeByLagrangianDuality, pricing_prob::AbstractFormulation)
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
    update_pricing_target(alg, pricing_prob)
    # Reset var bounds, var cost, sp minCost
    @logmsg LogLevel(-3) "updating pricing prob"
    if update_pricing_prob(alg, pricing_prob) # Never returns true
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
    status, p_sol, d_sol = optimize(pricing_prob)
    end
    compute_pricing_dual_bound_contrib(alg, pricing_prob)
    if status != MOI.OPTIMAL
        @logmsg LogLevel(-3) "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end
    @timeit to(alg) "insert_cols_in_master" begin
    insertion_status = insert_cols_in_master(alg, pricing_prob)
    end
    return insertion_status

    end # @timeit to(alg) "gen_new_col" begin
end

function gen_new_columns(alg::AlgToEvalNodeByLagrangianDuality)
    nb_new_col = 0
    for pricing_prob in alg.extended_problem.pricing_vect
        gen_status = gen_new_col(alg, pricing_prob)
        if gen_status > 0
            nb_new_col += gen_status
        elseif gen_status == -1 # Sp is infeasible
            return gen_status
        end
    end
    return nb_new_col
end

function compute_mast_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality)
    # stabilization = alg.colgen_stabilization
    # This is commented because function is_active does not exist
    # if stabilization == nothing# || !is_active(stabilization)
        return alg.extended_problem.master_problem.primal_sol.cost
    # else
    #     error("compute_mast_dual_bound_contrib" *
    #           "is not yet implemented with stabilization")
    # end
end

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

#########################################
#### AlgToEvalNodeBySimplexColGen #######
#########################################

function solve_restricted_mast(alg)
    @logmsg LogLevel(-2) "starting solve_restricted_mast"
    @timeit to(alg) "solve_restricted_mast" begin
    master = alg.extended_problem.master
    status, p_sol, d_sol = optimize(master)
    # @shows status
    # @show result_count = MOI.get(master.optimizer, MOI.ResultCount())
    # @show primal_status = MOI.get(master.optimizer, MOI.PrimalStatus())
    # @show dual_status = MOI.get(master.optimizer, MOI.DualStatus())
    end # @timeit to(alg) "solve_restricted_mast"
    return status
end

function solve_mast_lp_ph2(alg::AlgToEvalNodeBySimplexColGen)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    while true
        # glpk_prob = alg.extended_problem.master_problem.optimizer.optimizer.inner
        # GLPK.write_lp(glpk_prob, string("/Users/vitornesello/Desktop/mip_", nb_cg_iterations,".lp"))
        # solver restricted master lp and update bounds
        status_rm, mst_time, b, gc, allocs = @timed solve_restricted_mast(alg)
        # status_rm, mas_time = solve_restricted_mast(alg)
        # if alg.colgen_stabilization != nothing # Never evals to true
        #     # This function does not exist
        #     init_after_solving_restricted_mast(colgen_stabilization,
        #             computeOptimGap(alg), nbCgIterations,
        #             curMaxLevelOfSubProbRestriction)
        # end
        if status_rm == MOI.INFEASIBLE || status_rm == MOI.INFEASIBLE_OR_UNBOUNDED
            @logmsg LogLevel(-2) "master restrcited lp solver returned infeasible"
            mark_infeasible(alg)
            return true
        end
        update_alg_primal_lp_incumbents(alg)
        update_alg_primal_ip_incumbents(alg)
        cleanup_restricted_mast_columns(alg, nb_cg_iterations)
        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        nb_new_col = 0
        sp_time = 0.0
        while true
            @logmsg LogLevel(-2) "need to generate new master columns"
            nb_new_col, sp_time, b, gc, allocs = @timed gen_new_columns(alg)
            # In case subproblem infeasibility results in master infeasibility
            if nb_new_col < 0
                mark_infeasible(alg)
                return true
            end
            update_lagrangian_dual_bound(alg, true)
            # if alg.colgen_stabilization == nothing
            #|| !update_after_pricing_problem_solution(alg.colgen_stabilization, nb_new_col)
            break
            # end
        end

        print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations,
                                      mst_time, sp_time)
        # if alg.colgen_stabilization != nothing
        #     # This function does not exist
        #     update_after_colgen_iteration(alg.colgen_stabilization)
        # end
        @logmsg LogLevel(-2) string("colgen iter ", nb_cg_iterations,
                                   " : inserted ", nb_new_col, " columns")

        lower_bound = alg.sols_and_bounds.alg_inc_ip_dual_bound
        upper_bound = alg.sols_and_bounds.alg_inc_lp_primal_bound
        # upper_bound = min(alg.sols_and_bounds.alg_inc_lp_primal_bound,
        #                   alg.sols_and_bounds.alg_inc_ip_primal_bound)

        if nb_new_col == 0 || lower_bound + 0.00001 > upper_bound
            alg.is_master_converged = true
            return false
        end
        if nb_cg_iterations > alg.max_nb_cg_iterations
            @logmsg LogLevel(-2) "max_nb_cg_iterations limit reached"
            mark_infeasible(alg)
            return true
        end
        @logmsg LogLevel(-2) "next colgen ph2 iteration"
    end
    # These lines are never executed becasue there is no break from the outtermost 'while true' above
    # @logmsg LogLevel(-2) "solve_mast_lp_ph2 has finished"
    # return false
end

function run(alg::AlgToEvalNodeBySimplexColGen, primal_ip_bound::Float64)
    alg.sols_and_bounds.alg_inc_ip_primal_bound = primal_ip_bound

    @timeit to(alg) "run_eval_by_col_gen" begin
    @logmsg LogLevel(-2) "Starting eval by simplex colgen"
    status = solve_mast_lp_ph2(alg)

    if status == false
        alg.sol_is_master_lp_feasible = true
    end
    return false
    end # "run_eval_by_col_gen"
end

mutable struct SolsAndBounds
    alg_inc_ip_primal_bound::Float
    alg_inc_lp_primal_bound::Float
    alg_inc_ip_dual_bound::Float
    alg_inc_lp_dual_bound::Float
    alg_inc_lp_primal_sol_map::Dict{Variable, Float}
    alg_inc_ip_primal_sol_map::Dict{Variable, Float}
    alg_inc_lp_dual_sol_map::Dict{Constraint, Float}
    is_alg_inc_ip_primal_bound_updated::Bool
end

### Methods of SolsAndBounds
function update_primal_lp_bound(incumbents::SolsAndBounds, newBound::Float)
    if newBound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newBound
    end
end

function update_primal_ip_incumbents(incumbents::SolsAndBounds,
        var_val_map::Dict{Variable,Float}, newBound::Float)
    if newBound < incumbents.alg_inc_ip_primal_bound
        incumbents.alg_inc_ip_primal_bound = newBound
        incumbents.alg_inc_ip_primal_sol_map = Dict{Variable, Float}()
        for var_val in var_val_map
            push!(incumbents.alg_inc_ip_primal_sol_map, var_val)
        end
        incumbents.is_alg_inc_ip_primal_bound_updated = true
    end
end

function update_primal_lp_incumbents(incumbents::SolsAndBounds,
        var_val_map::Dict{Variable,Float}, newBound::Float)
    if newBound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newBound
        incumbents.alg_inc_lp_primal_sol_map = Dict{Variable, Float}()
        for var_val in var_val_map
            push!(incumbents.alg_inc_lp_primal_sol_map, var_val)
        end
    end
end

function update_dual_lp_bound(incumbents::SolsAndBounds, newBound::Float)
    if newBound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newBound
    end
end

function update_dual_ip_bound(incumbents::SolsAndBounds, newBound::Float)
    new_ip_bound = newBound
    # new_ip_bound = ceil(newBound) # TODO ceil if objective is integer
    if new_ip_bound > incumbents.alg_inc_ip_dual_bound
        incumbents.alg_inc_ip_dual_bound = new_ip_bound
    end
end

function update_dual_lp_incumbents(incumbents::SolsAndBounds,
        constr_val_map::Dict{Constraint, Float}, newBound::Float)
    if newBound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newBound
        incumbents.alg_inc_lp_dual_sol_map = Dict{Constraint, Float}()
        for constr_val in constr_val_map
            push!(incumbents.alg_inc_lp_dual_sol_map, constr_val)
        end
    end
end

mutable struct StabilizationInfo
    problem::Problem
    params::Params
end

mutable struct ColGenEvalInfo <: EvalInfo
    stabilization_info::StabilizationInfo
    master_lp_basis::LpBasisRecord
    latest_reduced_cost_fixing_gap::Float
end

mutable struct LpEvalInfo <: EvalInfo
    stabilization_info::StabilizationInfo
end

##########################
#### AlgToEvalNode #######
##########################

@hl mutable struct AlgToEvalNode <: AlgLike
    sols_and_bounds::SolsAndBounds
    extended_problem::ExtendedProblem
    sol_is_master_lp_feasible::Bool
    is_master_converged::Bool
end

function to(alg::AlgToEvalNode)
    return alg.extended_problem.timer_output
end

AlgToEvalNodeBuilder(problem::ExtendedProblem) = (SolsAndBounds(Inf, Inf, -Inf,
        -Inf, Dict{Variable, Float}(), Dict{Variable, Float}(),
        Dict{Constraint, Float}(), false), problem, false, false)

function update_alg_primal_lp_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    primal_bnd = master.primal_sols[end].cost
    update_primal_lp_bound(alg.sols_and_bounds, primal_bnd)
end

function update_alg_primal_lp_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    primal_sol = master.primal_sols[end].var_val_map
    primal_bnd = master.primal_sols[end].cost
    update_primal_lp_incumbents(alg.sols_and_bounds, primal_sol, primal_bnd)
end

function update_alg_primal_ip_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    primal_sol = master.primal_sols[end].var_val_map
    primal_bnd = master.primal_sols[end].cost
    if is_sol_integer(primal_sol,
                      alg.extended_problem.params.mip_tolerance_integrality)
        update_primal_ip_incumbents(alg.sols_and_bounds, primal_sol, primal_bnd)
    end
end

function update_alg_dual_lp_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_bnd = master.dual_sols[end].cost
    update_dual_lp_bound(alg.sols_and_bounds, dual_bnd)
end

function update_alg_dual_lp_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_sol = master.dual_sols[end].constr_val_map
    dual_bnd = master.dual_sols[end].cost
    ## not retreiving dual solution yet, but lp dual = lp primal
    update_dual_lp_incumbents(alg.sols_and_bounds, dual_sol, dual_bnd)
end

function update_alg_dual_ip_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_bnd = master.dual_sols[end].cost
    update_dual_ip_bound(alg.sols_and_bounds, ceil(dual_bnd))
end

function mark_infeasible(alg::AlgToEvalNode)
    alg.sols_and_bounds.alg_inc_lp_primal_bound = Inf
    alg.sols_and_bounds.alg_inc_ip_dual_bound = Inf
    alg.sols_and_bounds.alg_inc_lp_dual_bound = Inf
    alg.sol_is_master_lp_feasible = false
end

function setup(alg::AlgToEvalNode)
    return false
end

function setdown(alg::AlgToEvalNode)
    return false
end

function update_alg_incumbents(alg::AlgToEvalNode)
    update_alg_primal_lp_incumbents(alg)
    update_alg_primal_ip_incumbents(alg)
    update_alg_dual_lp_incumbents(alg)
    update_alg_dual_ip_bound(alg)

    println("Final incumbent bounds of lp evaluation:")
    println("alg_inc_ip_primal_bound: ", alg.sols_and_bounds.alg_inc_ip_primal_bound)
    println("alg_inc_ip_dual_bound: ", alg.sols_and_bounds.alg_inc_ip_dual_bound)
    println("alg_inc_lp_primal_bound: ", alg.sols_and_bounds.alg_inc_lp_primal_bound)
    println("alg_inc_lp_dual_bound: ", alg.sols_and_bounds.alg_inc_lp_dual_bound)

    println("Incumbent ip primal sol")
    for kv in alg.sols_and_bounds.alg_inc_ip_primal_sol_map
        println("var: ", kv[1].name, ": ", kv[2])
    end
    println()
    # readline()
end

##############################
#### AlgToEvalNodeByLp #######
##############################

@hl mutable struct AlgToEvalNodeByLp <: AlgToEvalNode end

function AlgToEvalNodeByLpBuilder(problem::ExtendedProblem)
    return AlgToEvalNodeBuilder(problem)
end

function run(alg::AlgToEvalNodeByLp)
    println("Starting eval by lp")

    status = optimize(alg.extended_problem.master_problem)

    if status != MOI.Success
        println("Lp is infeasible, exiting treatment of node.")
        return true
    end

    alg.sol_is_master_lp_feasible = true
    update_alg_incumbents(alg)

    return false
end

#############################################
#### AlgToEvalNodeByLagrangianDuality #######
#############################################

struct ColGenStabilization end

@hl mutable struct AlgToEvalNodeByLagrangianDuality <: AlgToEvalNode
    pricing_contribs::Dict{Problem, Float}
    pricing_const_obj::Dict{Problem, Float}
    colgen_stabilization::Union{ColGenStabilization, Nothing}
    max_nb_cg_iterations::Int
end

function AlgToEvalNodeByLagrangianDualityBuilder(problem::ExtendedProblem)
    return tuplejoin(AlgToEvalNodeBuilder(problem), Dict{Problem, Float}(),
                     Dict{Problem, Float}(), nothing, 10000) # TODO put as parameter
end

function cleanup_restricted_mast_columns(alg::AlgToEvalNodeByLagrangianDuality,
                                         nb_cg_iterations::Int)

    @logmsg LogLevel(-2) "cleanup_restricted_mast_columns is empty for now"
end

function update_pricing_target(alg::AlgToEvalNodeByLagrangianDuality,
                               pricing_prob::Problem)

    @logmsg LogLevel(-3) ("pricing target will only be needed after" *
                         "automating convexity constraints")
end

function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             pricing_prob::Problem)

    @timeit to(alg) "update_pricing_prob" begin

    new_obj = Dict{SubprobVar, Float}()
    alg.pricing_const_obj[pricing_prob] = 0
    for var in pricing_prob.var_manager.active_static_list
        @logmsg LogLevel(-4) string("$var original cost = ", var.cost_rhs)
        new_obj[var] = var.cost_rhs
    end
    extended_prob = alg.extended_problem
    master = extended_prob.master_problem
    duals_dict = master.dual_sols[end].constr_val_map
    for (constr, dual) in duals_dict
        @assert constr isa MasterConstr
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
    set_optimizer_obj(pricing_prob, new_obj)

    end # @timeit to(alg) "update_pricing_prob"
    return false
end

function compute_pricing_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality,
                                            pricing_prob::Problem)
    # TODO support multiple subproblems

    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost
    const_obj = alg.pricing_const_obj[pricing_prob]
    @logmsg LogLevel(-4) string("princing prob has const obj = ", const_obj)
    contrib = pricing_prob.obj_val + alg.pricing_const_obj[pricing_prob]
    alg.pricing_contribs[pricing_prob] = contrib
    @logmsg LogLevel(-2) string("princing prob has contribution = ", contrib)
end

function insert_cols_in_master(alg::AlgToEvalNodeByLagrangianDuality,
                               pricing_prob::Problem)

    # TODO add tolerances
    sp_sol = pricing_prob.primal_sols[end]
    if sp_sol.cost < 0
        master = alg.extended_problem.master_problem
        col = MasterColumn(master.counter, sp_sol)
        add_variable(master, col)
        convexity_lb = alg.extended_problem.pricing_convexity_lbs[pricing_prob]
        convexity_ub = alg.extended_problem.pricing_convexity_ubs[pricing_prob]
        add_membership(master, col, convexity_lb, 1.0)
        add_membership(master, col, convexity_ub, 1.0)
        @logmsg LogLevel(-2) string("added column ", col)
        return 1
    else
        return 0
    end
end

function gen_new_col(alg::AlgToEvalNodeByLagrangianDuality, pricing_prob::Problem)
    @timeit to(alg) "gen_new_col" begin

    flag_need_not_generate_more_col = 0
    flag_is_sp_infeasible = -1
    flag_cannot_generate_more_col = -2
    dual_bound_contrib = 0;
    pseudo_dual_bound_contrib = 0

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_col(princing_prob)
    #     return flag_cannot_generate_more_col
    # end

    # compute target
    update_pricing_target(alg, pricing_prob)
    # Reset var bounds, var cost, sp minCost
    @logmsg LogLevel(-3) "updating pricing prob"
    if update_pricing_prob(alg, pricing_prob)
        @logmsg LogLevel(-3) "pricing prob is infeasible"
        # In case one of the subproblem is infeasible, the master is infeasible
        compute_pricing_dual_bound_contrib(alg, pricing_prob)
        return flag_is_sp_infeasible
    end
    if alg.colgen_stabilization != nothing && true #= TODO add conds =#
        # switch off the reduced cost estimation when stabilization is applied
    end

    # Solve sub-problem and insert generated columns in master
    @logmsg LogLevel(-3) "optimizing pricing prob"
    @timeit to(alg) "optimize(pricing_prob)" begin
    status = optimize(pricing_prob)
    end
    compute_pricing_dual_bound_contrib(alg, pricing_prob)
    if status == MOI.InfeasibleNoResult
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
        end
    end
    return nb_new_col
end

function compute_mast_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality)
    stabilization = alg.colgen_stabilization
    if stabilization == nothing || !is_active(stabilization)
        return alg.extended_problem.master_problem.primal_sols[end].cost
    else
        error("compute_mast_dual_bound_contrib" *
              "is not yet implemented with stabilization")
    end
end

function update_lagrangian_dual_bound(alg::AlgToEvalNodeByLagrangianDuality,
                                      update_dual_bound::Bool)
    mast_lagrangian_bnd = 0
    mast_lagrangian_bnd = compute_mast_dual_bound_contrib(alg)
    @logmsg LogLevel(-2) string("dual bound contrib of master = ",
                               mast_lagrangian_bnd)

    # Subproblem contributions
    for pricing_prob in alg.extended_problem.pricing_vect
        alg.pricing_contribs[pricing_prob]
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
    if alg.colgen_stabilization != nothing
        update_dual_lp_bound(alg.sols_and_bounds, mast_lagrangian_bnd)
        update_dual_ip_bound(alg.sols_and_bounds, mast_lagrangian_bnd)
    end
end

function print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations)
    mlp = alg.sols_and_bounds.alg_inc_lp_primal_bound
    db = alg.sols_and_bounds.alg_inc_lp_dual_bound
    db_ip = alg.sols_and_bounds.alg_inc_ip_dual_bound
    pb = alg.sols_and_bounds.alg_inc_ip_primal_bound
    println(string("<it=$nb_cg_iterations> <cols=$nb_new_col> <mlp=$mlp> "),
            string("<DB=$db> <PB=$pb>"))
end

#########################################
#### AlgToEvalNodeBySimplexColGen #######
#########################################

@hl mutable struct AlgToEvalNodeBySimplexColGen <:
                   AlgToEvalNodeByLagrangianDuality end

AlgToEvalNodeBySimplexColGenBuilder(problem::ExtendedProblem) = (
    AlgToEvalNodeByLagrangianDualityBuilder(problem)
)

function setup(alg::AlgToEvalNode)
    return false
end

function setdown(alg::AlgToEvalNode)
    return false
end

function solve_restricted_mast(alg)
    @logmsg LogLevel(-2) "starting solve_restricted_mast"
    @timeit to(alg) "solve_restricted_mast" begin
    status = optimize(alg.extended_problem.master_problem)
    end # @timeit to(alg) "solve_restricted_mast"
    return status
end

function solve_mast_lp_ph2(alg::AlgToEvalNodeBySimplexColGen)
    @timeit to(alg) "solve_mast_lp_ph2" begin

    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    # glpk_prob = alg.extended_problem.master_problem.optimizer.optimizer.inner
    while(true)
        # GLPK.write_lp(glpk_prob, string("mip_", nb_cg_iterations,".lp"))
        # solver restricted master lp and update bounds
        status_rm = solve_restricted_mast(alg)
        if alg.colgen_stabilization != nothing
            init_after_solving_restricted_mast(colgen_stabilization,
                    computeOptimGap(alg), nbCgIterations,
                    curMaxLevelOfSubProbRestriction)
        end
        if status_rm == MOI.InfeasibleNoResult
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
        while true
            @logmsg LogLevel(-2) "need to generate new master columns"
            nb_new_col = gen_new_columns(alg)

            # In case subproblem infeasibility results in master infeasibility
            if nb_new_col < 0
                mark_infeasible(alg)
                return true
            end
            update_lagrangian_dual_bound(alg, true)
            if alg.colgen_stabilization == nothing ||
                !update_after_pricing_problem_solution(alg.colgen_stabilization,
                                                       nb_new_col)
                break
            end
        end

        print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations)
        if alg.colgen_stabilization != nothing
            update_after_colgen_iteration(alg.colgen_stabilization)
        end
        @logmsg LogLevel(-2) string("colgen iter ", nb_cg_iterations,
                                   " : inserted ", nb_new_col, " columns")

        lower_bound = alg.sols_and_bounds.alg_inc_ip_dual_bound
        upper_bound = alg.sols_and_bounds.alg_inc_lp_primal_bound


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
    @logmsg LogLevel(-2) "solve_mast_lp_ph2 has finished"
    return false

    end # @timeit to "solve_mast_lp_ph2"
end

function run(alg::AlgToEvalNodeBySimplexColGen)
    @logmsg LogLevel(-2) "Starting eval by simplex colgen"
    status = solve_mast_lp_ph2(alg)

    if status == false
        alg.sol_is_master_lp_feasible = true
    end

    return false
end

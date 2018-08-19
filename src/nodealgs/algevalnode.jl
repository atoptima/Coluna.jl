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
    new_ip_bound = ceil(newBound)
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
    update_primal_ip_incumbents(alg.sols_and_bounds, primal_sol, primal_bnd)
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
    update_dual_ip_bound(alg.sols_and_bounds, dual_bnd)
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
    update_alg_dual_ip_bound(alg)
    update_alg_primal_lp_incumbents(alg)
    update_alg_dual_lp_incumbents(alg)    

    master = alg.extended_problem.master_problem
    primal_sol = master.primal_sols[end].var_val_map
    if sol_is_integer(primal_sol,
            alg.extended_problem.params.mip_tolerance_integrality)
        update_alg_primal_ip_incumbents(alg)
    end

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
    colgen_stabilization::Union{ColGenStabilization, Nothing}
    max_nb_cg_iterations::Int
end

function AlgToEvalNodeByLagrangianDualityBuilder(problem::ExtendedProblem)
    return tuplejoin(AlgToEvalNodeBuilder(problem), Dict{Problem, Float}(),
                     nothing, 100) #TODO put as parameter
end

function cleanup_restricted_mast_columns(alg::AlgToEvalNodeByLagrangianDuality, 
                                         nb_cg_iterations::Int)

    @logmsg LogLevel(2) "cleanup_restricted_mast_columns is empty for now"
end

function update_pricing_target(alg::AlgToEvalNodeByLagrangianDuality,
                               pricing_prob::Problem)

    @logmsg LogLevel(3) ("pricing target will only be needed after" *
                         "automating convexity constraints")
end

function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality, 
                             pricing_prob::Problem)
    
    new_obj = Dict{SubprobVar, Float}()
    for var in pricing_prob.var_manager.active_static_list
        new_obj[var] = var.cost_rhs
    end
    master = alg.extended_problem.master_problem
    duals_dict = master.dual_sols[end].constr_val_map
    for (constr, dual) in duals_dict
        @assert constr isa MasterConstr
        for (var, coef) in constr.subprob_var_coef_map
            new_obj[var] -= dual * coef
        end
    end    
    @logmsg LogLevel(3) string("new objective func = ", new_obj)
    set_optimizer_obj(pricing_prob, new_obj)    
    return false
end

function compute_pricing_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality, 
                                            pricing_prob::Problem)
    # TODO support multiple subproblems
    
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost
    contrib = pricing_prob.obj_val
    alg.pricing_contribs[pricing_prob] = contrib
    @logmsg LogLevel(2) string("princing prob has contribution = ", contrib)
end

function insert_cols_in_master(alg::AlgToEvalNodeByLagrangianDuality, 
                               pricing_prob::Problem)
    
    # TODO add tolerances
    sp_sol = pricing_prob.primal_sols[end]
    if sp_sol.cost < 0
        master = alg.extended_problem.master_problem
        col = MasterColumn(master.counter, sp_sol)
        add_variable(master, col)
        @logmsg LogLevel(2) string("added column ", col)
        return 1
    else
        return 0
    end    
end

function gen_new_col(alg::AlgToEvalNodeByLagrangianDuality, pricing_prob::Problem)                
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
    @logmsg LogLevel(3) "updating pricing prob"
    if update_pricing_prob(alg, pricing_prob)
        @logmsg LogLevel(3) "pricing prob is infeasible"
        # In case one of the subproblem is infeasible, the master is infeasible
        compute_pricing_dual_bound_contrib(alg, pricing_prob)
        return flag_is_sp_infeasible
    end
    if alg.colgen_stabilization != nothing && true #= TODO add conds =#
        # switch off the reduced cost estimation when stabilization is applied
    end

    # Solve sub-problem and insert generated columns in master
    @logmsg LogLevel(3) "optimizing pricing prob"
    status = optimize(pricing_prob)
    compute_pricing_dual_bound_contrib(alg, pricing_prob)
    if status == MOI.InfeasibleNoResult
        @logmsg LogLevel(3) "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end
    insertion_status = insert_cols_in_master(alg, pricing_prob)
    return insertion_status
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
    @logmsg LogLevel(2) string("dual bound contrib of master = ",
                               mast_lagrangian_bnd)
    
    # Subproblem contributions
    for pricing_prob in alg.extended_problem.pricing_vect
        alg.pricing_contribs[pricing_prob]
        mast_lagrangian_bnd += alg.pricing_contribs[pricing_prob]
        @logmsg LogLevel(2) string("dual bound contrib of SP[",
                   pricing_prob.prob_ref, "] = ",
                   alg.pricing_contribs[pricing_prob],
                   ". mast_lagrangian_bnd = ", mast_lagrangian_bnd)
    end

    @logmsg LogLevel(2) string("UPDATED CURRENT DUAL BOUND. lp_primal_bound = ",
              alg.sols_and_bounds.alg_inc_lp_primal_bound,
              ". mast_lagrangian_bnd = ", mast_lagrangian_bnd)
    
    #TODO: clarify this comment
    # by Guillaume : subgradient algorithm needs to know when the incumbent
    if update_dual_bound
        mast_lagrangian_bnd = update_alg_dual_lp_bound(alg)
    end    
    if alg.colgen_stabilization != nothing
        mast_lagrangian_bnd = update_alg_dual_lp_bound(alg)
    end
end

function print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations)    
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
    @logmsg LogLevel(2) "starting solve_restricted_mast"
    status = optimize(alg.extended_problem.master_problem)
    return status
end

function solve_mast_lp_ph2(alg::AlgToEvalNodeBySimplexColGen)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and 
    # termination by bound does not apply
    glpk_prob = alg.extended_problem.master_problem.optimizer.optimizer.inner
    while(true)
        GLPK.write_lp(glpk_prob, string("mip_", nb_cg_iterations,".lp"))
        # solver restricted master lp and update bounds        
        status_rm = solve_restricted_mast(alg)        
        if alg.colgen_stabilization != nothing
            init_after_solving_restricted_mast(colgen_stabilization,
                    computeOptimGap(alg), nbCgIterations, 
                    curMaxLevelOfSubProbRestriction)
        end
        if status_rm == MOI.InfeasibleNoResult
            @logmsg LogLevel(2) "master restrcited lp solver returned infeasible"
            mark_infeasible(alg)
            return true
        end
        update_alg_primal_lp_bound(alg)
        cleanup_restricted_mast_columns(alg, nb_cg_iterations) 
        nb_cg_iterations += 1
        
        # generate new columns by solving the subproblems
        nb_new_col = 0
        while true
            @logmsg LogLevel(2) "need to generate new master columns"
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
        @logmsg LogLevel(2) string("colgen iter ", nb_cg_iterations,
                                   " : inserted ", nb_new_col, " columns")
        if nb_new_col == 0
            alg.is_master_converged = true
            return false
        end        
        if nb_cg_iterations > alg.max_nb_cg_iterations
            @logmsg LogLevel(2) "max_nb_cg_iterations limit reached"
            mark_infeasible(alg)
            return true
        end
        @logmsg LogLevel(2) "next colgen ph2 iteration"
    end
    
    @logmsg LogLevel(2) "solve_mast_lp_ph2 has finished"
    return false
end

function run(alg::AlgToEvalNodeBySimplexColGen)
    @logmsg LogLevel(2) "Starting eval by simplex colgen"
    status = solve_mast_lp_ph2(alg)
    
    if status == false
        alg.sol_is_master_lp_feasible = true
        update_alg_incumbents(alg)
    end
    
    return false
end
mutable struct SolsAndBounds ###FVC### why not simply struct
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
         ###FVC### should we use an epsilon to enforce a strict improvement
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
 ###FVC### do we assume a minimization problem, or do we want to make it generic for both min and max

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

    update_primal_lp_incumbents(alg.sols_and_bounds, primal_sol, primal_bnd)
end

function update_alg_dual_lp_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_sol = master.dual_sols[end].var_val_map
    dual_bnd = master.dual_sols[end].cost
    ## not retreiving dual solution yet, but lp dual = lp primal
    update_dual_lp_incumbents(alg.sols_and_bounds, dual_sol, dual_bnd) 
end

function update_alg_dual_ip_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_bnd = master.dual_sols[end].cost
    update_dual_ip_bound(alg.sols_and_bounds, dual_bnd)
end

function update_alg_dual_lp_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_bnd = master.dual_sols[end].cost
    update_dual_lp_bound(alg.sols_and_bounds, dual_bnd)
end

function mark_infeasible(alg::AlgToEvalNode)
    alg.sols_and_bounds.alg_inc_lp_primal_bound = Inf
    alg.sols_and_bounds.alg_inc_ip_dual_bound = Inf
    alg.sols_and_bounds.alg_inc_lp_dual_bound = Inf
    alg.sol_is_master_lp_feasible = false
end    

##############################
#### AlgToEvalNodeByLp #######
##############################

@hl mutable struct AlgToEvalNodeByLp <: AlgToEvalNode end

function AlgToEvalNodeByLpBuilder(problem::ExtendedProblem)
    return AlgToEvalNodeBuilder(problem)
end

function setup(alg::AlgToEvalNode)
    return false
end

function setdown(alg::AlgToEvalNode)
    return false
end

function update_alg_incumbents(alg::AlgToEvalNodeByLp)
    update_alg_dual_ip_bound(alg)
    update_alg_primal_lp_incumbents(alg)
    update_alg_dual_lp_incumbents(alg)    

    if sol_is_integer(primal_sol,
            alg.extended_problem.params.mip_tolerance_integrality)
        update_primal_ip_incumbents(alg.sols_and_bounds, primal_sol, obj_bound)
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

@hl mutable struct AlgToEvalNodeByLagrangianDuality <: AlgToEvalNode end

function cleanup_restricted_mast_columns(alg::AlgToEvalNodeByLagrangianDuality, 
                                         nb_cg_iterations::Int)
    @logmsg 2 "cleanup_restricted_mast_columns is empty for now"
end

function update_pricing_target(alg::AlgToEvalNodeByLagrangianDuality,
                               pricing_prob::Problem)
    error("Not yet implemented")
end

function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality, 
                             pricing_prob::Problem)
    error("Not yet implemented")
end

function compute_pricing_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality, 
                                            pricing_prob::Problem)
    error("Not yet implemented")
end

function insert_cols_in_master(alg::AlgToEvalNodeByLagrangianDuality, 
                               pricing_prob::Problem)
    error("Not yet implemented")
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
    if update_pricing_prob(alg, pricing_prob)
        @logmsg 3 "pricing prob is infeasible"
        # In case one of the subproblem is infeasible, the master is infeasible
        compute_pricing_dual_bound_contrib(alg, pricing_prob)
        return flag_is_sp_infeasible
    end    
    if alg.colgen_stabilization != nothing && true #= TODO add conds =#
        # switch off the reduced cost estimation when stabilization is applied
    end    

    # Solve sub-problem and insert generated columns in master
    status = optimize(pricing_prob)
    compute_pricing_dual_bound_contrib(alg, pricing_prob)
    if status == InfeasibleNoResult
        @logmsg 3 "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end
    insertion_status = insert_cols_in_master(alg, pricing_prob)
    return insertion_status
end

function gen_new_columns(alg::AlgToEvalNodeByLagrangianDuality)  
    for pricing_prob in alg.pricing_vect
        gen_new_col(alg, pricing_prob)  
    end
end

function compute_mast_dual_bound_contrib(alg::AlgToEvalNodeByLagrangianDuality)
    if colgen_stabilization == nothing || !is_active(colgen_stabilization)
        return alg.extended_problem.master_problem.primal_sols[end].cost
    else
        error("compute_mast_dual_bound_contrib" *  
              "is not yet implemented with stabilization")
    end
end

function update_lagrangian_dual_bound(alg::AlgToEvalNodeByLagrangianDuality, 
                                      update_dual_bound)
    mast_lagrangian_bnd = 0
    compute_mast_dual_bound_contrib(mast_lagrangian_bnd)
    
    # Subproblem contributions
    for pricing_prob in alg.extended_problem.pricing_vect
        sp_alg.dual_bound_contrib[pricing_prob]
        mast_lagrangian_bnd += sp_alg.dual_bound_contrib[pricing_prob]
        @logmsg 3 ("master dual bound: contrib of SP[" * pricing_prob.prob_ref *
                   "] = " * sp_alg.dual_bound_contrib[pricing_prob] *
                   ". mast_lagrangian_bnd = " * mast_lagrangian_bnd)
    end

    @logmsg 2 ("UPDATED CURRENT DUAL BOUND. lp_primal_bound = " 
              * alg.sols_and_bounds.alg_inc_lp_primal_bound
              * ". mast_lagrangian_bnd = " * mast_lagrangian_bnd)
    
    #TODO: clarify this comment
    # by Guillaume : subgradient algorithm needs to know when the incumbent
    if update_dual_bound
        update_alg_dual_lp_bound(alg, mast_lagrangian_bnd)
    end    
    if alg.colgen_stabilization != nothing
        update_on_lgr_bnd_change(alg.colgen_stabilization, mast_lagrangian_bnd)
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
    AlgToEvalNodeBuilder(problem)
)

function setup(alg::AlgToEvalNode)
    return false
end

function setdown(alg::AlgToEvalNode)
    return false
end

function solve_restricted_mast(alg)
    @logmsg 2 "starting solve_restricted_mast"
    status = optimize(alg.extended_problem.master_problem)
    return status
end

function solve_mast_lp_ph2(alg::AlgToEvalNodeBySimplexColGen)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and 
    # termination by bound does not apply
    while(true)
        # solver restricted master lp and update bounds
        status_rm = solve_restricted_mast(alg)        
        if colgen_stabilization != nothing
            init_after_solving_restricted_mast(colgen_stabilization,
                    computeOptimGap(alg), nbCgIterations, 
                    curMaxLevelOfSubProbRestriction)
        end        
        if status_rm == MOI.InfeasibleNoResult
            @logmsg 2 "master restrcited lp solver returned infeasible"
            mark_infeasible(alg)
            return true
        end
        update_primal_lp_bound(alg)
        cleanup_restricted_mast_columns(alg, nb_cg_iterations) 
        nb_cg_iterations += 1
        
        # generate new columns by solving the subproblems
        nb_new_col = 0
        while true
            @logmsg 2 "need to generate new master columns"
            nb_new_col = gen_new_columns(alg)
            
            # In case subproblem infeasibility results in master infeasibility
            if nb_new_col < 0
                mark_infeasible(alg)
                return true;
            end
            update_lagrangian_dual_bound(alg, true)
            if colgen_stabilization == Nothing || 
                update_after_pricing_problem_solution(colgen_stabilization, 
                                                      nb_new_col)
                break
            end
        end        
        
        print_intermediate_statistics(alg, nb_new_col, nb_cg_iterations)
        if colgen_stabilization != Nothing
            update_after_colgen_iteration(colgen_stabilization)
        end        
        @logmsg 2 ("CG iteration " * nb_cg_iterations * 
                   " : inserted " * nb_new_col * " columns")
        if nb_new_col == 0
            alg.is_master_converged = true
            return false
        end
        
        if nb_cg_iterations < alg.max_nb_cg_iterations
            break
        end        
    end
    
    @logmsg 2 "solve_mast_lp_ph2 has finished"
    return false
end

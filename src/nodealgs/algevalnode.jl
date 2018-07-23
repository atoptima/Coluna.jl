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
#### Put flags to update sol?
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

function update_dual_ip_bound(incumbents::SolsAndBounds, newBound::Float)
    if newBound > incumbents.alg_inc_ip_dual_bound
        incumbents.alg_inc_ip_dual_bound = newBound
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


type StabilizationInfo
    problem::Problem
    params::Params
end

type ColGenEvalInfo <: EvalInfo
    stabilization_info::StabilizationInfo
    master_lp_basis::LpBasisRecord
    latest_reduced_cost_fixing_gap::Float
end

type LpEvalInfo <: EvalInfo
    stabilization_info::StabilizationInfo
end


@hl type AlgToEvalNode <: AlgLike
    sols_and_bounds::SolsAndBounds
    extended_problem::ExtendedProblem
    sol_is_master_lp_feasible::Bool
end


AlgToEvalNodeBuilder(problem::ExtendedProblem) = (SolsAndBounds(Inf, Inf, -Inf,
        -Inf, Dict{Variable, Float}(), Dict{Variable, Float}(),
        Dict{Constraint, Float}(), false), problem, false)

@hl type AlgToEvalNodeByColGen <: AlgToEvalNode end

AlgToEvalNodeByColGenBuilder(problem::ExtendedProblem) = (
    AlgToEvalNodeBuilder(problem)
)

@hl type AlgToEvalNodeByLp <: AlgToEvalNode end

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
    const primal_sol = alg.extended_problem.master_problem.primal_sols[end].var_val_map
    const dual_sol = alg.extended_problem.master_problem.dual_sols[end].var_val_map
    const obj_value = alg.extended_problem.master_problem.primal_sols[end].cost
    const obj_bound = alg.extended_problem.master_problem.dual_sols[end].cost

    update_dual_ip_bound(alg.sols_and_bounds, obj_bound)
    update_primal_lp_incumbents(alg.sols_and_bounds, primal_sol, obj_value)

    ## not retreiving dual solution yet, but lp dual = lp primal
    update_dual_lp_incumbents(alg.sols_and_bounds, dual_sol, obj_value)

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
    readline()
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

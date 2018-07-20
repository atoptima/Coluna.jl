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
function update_dual_ip_bound(incumbents::SolsAndBounds, newBound::Float)
    if newBound > incumbents.alg_inc_ip_dual_bound
        incumbents.alg_inc_ip_dual_bound = newBound
    end
end

function update_primal_lp_incumbents(incumbents::SolsAndBounds,
        vars::Set{Variable}, newBound::Float)
    if newBound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newBound
        incumbents.alg_inc_lp_primal_sol_map = Dict{Variable, Float}()
        for var in vars
            incumbents.alg_inc_lp_primal_sol_map[var] = var.val
        end
    end
end

function update_primal_ip_incumbents(incumbents::SolsAndBounds,
        vars::Set{Variable}, newBound::Float)
    if newBound < incumbents.alg_inc_ip_primal_bound
        incumbents.alg_inc_ip_primal_bound = newBound
        incumbents.alg_inc_ip_primal_sol_map = Dict{Variable, Float}()
        for var in vars
            incumbents.alg_inc_ip_primal_sol_map[var] = var.val
        end
        incumbents.is_alg_inc_ip_primal_bound_updated = true
    end
end

function update_dual_lp_incumbents(incumbents::SolsAndBounds,
        constrs::Set{Constraint}, newBound::Float)
    if newBound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newBound
        incumbents.alg_inc_lp_dual_sol_map = Dict{Constraint, Float}()
        for constr in constrs
            incumbents.alg_inc_lp_dual_sol_map[var] = constr.val
        end
    end
end


type StabilizationInfo
    problem::Problem
    params::Params
end

abstract type EvalInfo end

type ColGenEvalInfo <: EvalInfo
    stabilization_info::StabilizationInfo
    master_lp_basis::LpBasisRecord
    latest_reduced_cost_fixing_gap::Float
end

type LpEvalInfo <: EvalInfo
    stabilization_info::StabilizationInfo
end


@hl type AlgToEvalNode
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
    const primal_sol = alg.extended_problem.master_problem.in_primal_lp_sol
    const dual_sol = alg.extended_problem.master_problem.in_dual_sol
    const obj_value = alg.extended_problem.master_problem.obj_val
    const obj_bound = alg.extended_problem.master_problem.obj_bound

    update_dual_ip_bound(alg.sols_and_bounds, obj_bound)
    update_primal_lp_incumbents(alg.sols_and_bounds, primal_sol, obj_value)

    ## not retreiving dual solution yet, but lp dual = lp primal
    update_dual_lp_incumbents(alg.sols_and_bounds, dual_sol, obj_value)

    if cur_sol_is_integer(alg.extended_problem.master_problem,
            alg.extended_problem.params.mip_tolerance_integrality)
        update_primal_ip_incumbents(alg.sols_and_bounds, primal_sol, obj_bound)
    end

    println("Final incumbent bounds of lp evaluation:")
    println("alg_inc_ip_primal_bound: ", alg.sols_and_bounds.alg_inc_ip_primal_bound)
    println("alg_inc_ip_dual_bound: ", alg.sols_and_bounds.alg_inc_ip_dual_bound)
    println("alg_inc_lp_primal_bound: ", alg.sols_and_bounds.alg_inc_lp_primal_bound)
    println("alg_inc_lp_dual_bound: ", alg.sols_and_bounds.alg_inc_lp_dual_bound)

    println("incmbent ip primal sol")
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
        return true
    end

    alg.sol_is_master_lp_feasible = true
    update_alg_incumbents(alg)

    return false
end

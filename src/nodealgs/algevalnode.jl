type SolsAndBounds
    alg_inc_ip_primal_bound::Float
    alg_inc_lp_primal_bound::Float
    alg_inc_ip_dual_bound::Float
    alg_inc_lp_dual_bound::Float
    alg_inc_lp_primal_sol_map::Dict{Variable, Float}
    alg_inc_lp_dual_sol_map::Dict{Variable, Float}
    alg_inc_ip_primal_sol_map::Dict{Variable, Float}
    is_alg_inc_ip_primal_bound_updated::Bool
end


### Methods of SolsAndBounds




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
end

function AlgToEvalNodeBuilder(params::Params, counter::VarConstrCounter)

    master_problem = SimpleCompactProblem(Cbc.CbcOptimizer(), counter)
    extended_problem = ExtendedProblemConstructor(master_problem,
        Problem[], Problem[], counter, params, Inf, 0.0)

    return (SolsAndBounds(Inf, Inf, 0.0,
    0.0, Dict{VarConstr, Float}(), Dict{VarConstr, Float}(),
    Dict{VarConstr, Float}(), false), extended_problem)

end


AlgToEvalNodeBuilder(problem::ExtendedProblem) = (SolsAndBounds(Inf, Inf, 0.0,
        0.0, Dict{VarConstr, Float}(), Dict{VarConstr, Float}(),
        Dict{VarConstr, Float}(), false), problem)

@hl type AlgToEvalNodeByColGen <: AlgToEvalNode end

AlgToEvalNodeByColGenBuilder(problem::ExtendedProblem) = (
    AlgToEvalNodeBuilder(problem)
)

@hl type AlgToEvalNodeByLp <: AlgToEvalNode
    eval_info::LpEvalInfo
end

function AlgToEvalNodeByLpBuilder(problem::ExtendedProblem, eval_info::LpEvalInfo)
    return tuplejoin(AlgToEvalNodeBuilder(problem), eval_info)
end


function setup(alg::AlgToEvalNode)
    return false
end

function setdown(alg::AlgToEvalNode)
    return false
end


function run(alg::AlgToEvalNodeByLp)

    status = optimize(alg.extended_problem.master_problem)

    # if status <= 0
    #     return true
    # end
    #
    # alg.sol_is_master_lp_feasible = true
    #
    # if check_if_sol_is_integer()
    #     update_primal_lp_sol_and_bnds()
    # end

    return false
end

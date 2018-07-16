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
end

AlgToEvalNodeBuilder() = (SolsAndBounds(Inf, Inf, 0.0, 0.0,
        Dict{VarConstr, Float}(), Dict{VarConstr, Float}(),
        Dict{VarConstr, Float}(), false), )

@hl type AlgToEvalNodeByColGen <: AlgToEvalNode end

AlgToEvalNodeByColGenBuilder() = AlgToEvalNodeBuilder()

@hl type AlgToEvalNodeByLp <: AlgToEvalNode
    eval_info::LpEvalInfo
end

function setup(alg::AlgToEvalNode)
    return false
end

function setdown(alg::AlgToEvalNode)
    return false
end


function AlgToEvalNodeByLpBuilder(eval_info::LpEvalInfo)
    return tuplejoin(AlgToEvalNodeBuilder(), eval_info)
end


function run(alg::AlgToEvalNodeByLp)

    return false
end

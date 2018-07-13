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


@hl type AlgToEvalNode end

@hl type AlgToEvalNodeByColGen <: AlgToEvalNode end

@hl type AlgToEvalNodeByLp <: AlgToEvalNode
    eval_info::LpEvalInfo
end


function AlgToEvalNodeByLpBuilder(eval_info::LpEvalInfo)
    return (eval_info,)
end


function run(alg::AlgToEvalNodeByLp, node, problem::Problem)


end

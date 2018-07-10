type StabilizationInfo
    problem::Problem
    params::Params
end

type ColGenEvalInfo
    stabilization_info::StabilizationInfo
    master_lp_basis::LpBasisRecord
    latest_reduced_cost_fixing_gap::Float
end

@hl type EvalInfo end

@hl type AlgToEvalNode end

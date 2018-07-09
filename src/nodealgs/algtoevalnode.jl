type StabilizationInfo 
    problem::Problem
    params::Params
end

type ColGenEvalInfo
    stabilizationinfo::StabilizationInfo
    masterlpbasis::LpBasisRecord
    latestreducedcostfixinggap::Float
end

@hl type EvalInfo end

@hl type AlgToEvalNode end


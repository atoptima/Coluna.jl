@hl mutable struct AlgToPrimalHeurInNode <: AlgLike
    sols_and_bounds::SolsAndBounds
    extended_problem::ExtendedProblem
end

AlgToPrimalHeurInNodeBuilder(prob::ExtendedProblem) = (SolsAndBounds(), prob)

function setup(alg::AlgToPrimalHeurInNode)
    return false
end

function setdown(alg::AlgToPrimalHeurInNode)
    return false
end

@hl mutable struct AlgToPrimalHeurByRestrictedMip <: AlgToPrimalHeurInNode end

AlgToPrimalHeurByRestrictedMipBuilder(prob::ExtendedProblem) =
        AlgToPrimalHeurInNodeBuilder(prob)

function run(alg::AlgToPrimalHeurByRestrictedMip, node::Node,
             global_treat_order::Int)

    master_prob = alg.extended_problem.master_problem
    mip_optimizer = GLPK.Optimizer()
    load_problem_in_optimizer(master_prob, mip_optimizer, false)
    MOI.optimize!(mip_optimizer)
    @show MOI.get(mip_optimizer, MOI.ObjectiveValue())
end

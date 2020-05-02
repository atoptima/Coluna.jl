
# """
#     AbstractRelaxationImprovement

#     Relaxation imporovement is an algorithm to strengethen the current relaxation of the problem
#     Usual types of such algorithms are finding branching candidates and cut separation
#     However, other types are possible, for example, increasing ng-neighbourhood in the ng-path relaxation
#     Each relaxation improvement should have a root and non-root priority
# """
# abstract type AbstractRelaxationImprovement end

# getrootpriority(improvement::AbstractRelaxationImprovement) = 1.0
# getnonrootpriority(improvement::AbstractRelaxationImprovement) = 1.0
# getpriority(improvement::AbstractRelaxationImprovement, rootnode::Bool) = 
#     rootnode ? getrootpriority(improvement) : getnonrootpriority(improvement) 

"""
    SelectionCriterion
"""
@enum SelectionCriterion FirstFoundCriterion MostFractionalCriterion 


"""
    BranchingRuleInput

    Input of a branching rule (branching separation algorithm)
    Contains current solution, max number of candidates and local candidate id.
"""
struct BranchingRuleInput <: AbstractInput 
    solution::PrimalSolution 
    isoriginalsol::Bool
    max_nb_candidates::Int64
    criterion::SelectionCriterion
    local_id::Int64
end

"""
    BranchingRuleOutput

    Input of a branching rule (branching separation algorithm)
    Contains current incumbents, infeasibility status, and the record of its storage.
"""
struct BranchingRuleOutput <: AbstractOutput 
    local_id::Int64
    groups::Vector{BranchingGroup}
end

function BranchingRuleOuput(input::BranchingRuleInput)
    return BranchingRuleOuput(input.local_id, Vector{BranchingGroup}())
end

getlocalid(output::BranchingRuleOutput) = output.local_id
getgroups(output::BranchingRuleOutput) = output.groups

"""
    AbstractBranchingRule

    Branching rules are algorithms which find branching candidates 
    (branching separation algorithms).
"""
abstract type AbstractBranchingRule <: AbstractAlgorithm end

function run!(
    rule::AbstractBranchingRule, data::AbstractData, input::BranchingRuleInput
)::BranchingRuleOutput
    algotype = typeof(rule)
    error("Method run! in not defined for branching rule $(typeof(rule)), data $(typeof(data)), and input $(typeof(input)).")
end

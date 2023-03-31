############################################################################################
# Branching rules
############################################################################################
"""
Supertype of branching rules.
"""
abstract type AbstractBranchingRule <: AbstractAlgorithm end

"""
    PrioritisedBranchingRule

A branching rule with root and non-root priorities.
"""
struct PrioritisedBranchingRule
    rule::AbstractBranchingRule
    root_priority::Float64
    nonroot_priority::Float64
end

function getpriority(rule::PrioritisedBranchingRule, isroot::Bool)::Float64
    return isroot ? rule.root_priority : rule.nonroot_priority
end

"""
Input of a branching rule (branching separation algorithm)
Contains current solution, max number of candidates and local candidate id.
"""
struct BranchingRuleInput{SelectionCriterion<:AbstractSelectionCriterion,Node<:AbstractNode}
    solution::PrimalSolution 
    isoriginalsol::Bool
    max_nb_candidates::Int64
    criterion::SelectionCriterion
    local_id::Int64
    int_tol::Float64
    minimum_priority::Float64
    parent::Node
end

"""
Output of a branching rule (branching separation algorithm)
It contains the branching candidates generated and the updated local id value
"""
struct BranchingRuleOutput
    local_id::Int64
    candidates::Vector{AbstractBranchingCandidate}
end
 
# branching rules are always manager algorithms (they manage storing and restoring storage units)
ismanager(algo::AbstractBranchingRule) = true

"Returns all candidates that satisfy a given branching rule."
@mustimplement "BranchingRule" apply_branching_rule(rule, env, reform, input)

"Candidates selection for branching algorithms."
function select!(rule::AbstractBranchingRule, env::Env, reform::Reformulation, input::BranchingRuleInput)
    candidates = apply_branching_rule(rule, env, reform, input)
    local_id = input.local_id + length(candidates)
    select_candidates!(candidates, input.criterion, input.max_nb_candidates)

    for candidate in candidates
        children = generate_children!(candidate, env, reform, input.parent)
        set_children!(candidate, children)
    end
    return BranchingRuleOutput(local_id, candidates)
end

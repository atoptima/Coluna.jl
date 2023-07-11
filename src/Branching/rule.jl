############################################################################################
# Branching rules
############################################################################################
"""
Supertype of branching rules.
"""
abstract type AbstractBranchingRule <: AlgoAPI.AbstractAlgorithm end

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
struct BranchingRuleInput{SelectionCriterion<:AbstractSelectionCriterion,DivideInput,Solution}
    solution::Solution 
    isoriginalsol::Bool
    max_nb_candidates::Int64
    criterion::SelectionCriterion
    local_id::Int64
    int_tol::Float64
    minimum_priority::Float64
    input::DivideInput
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
@mustimplement "BranchingRule" apply_branching_rule(rule, env, reform, input) = nothing

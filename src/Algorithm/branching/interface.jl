
############################################################################################
# Branching Candidates
############################################################################################

"""
A branching candidate is a data structure that contain all information needed to generate
children of a node.
"""
abstract type AbstractBranchingCandidate end

"""
    getdescription(branching_candidate)

Returns a string which serves to print the branching rule in the logs.
"""
getdescription(candidate::AbstractBranchingCandidate) = 
    error("getdescription not defined for branching candidates of type $(typeof(candidate)).")

"""
    generate_children!(branching_candidate, lhs, env, reform, node)

This method generates the children of a node described by `branching_candidate`.
"""
generate_children!(
    candidate::AbstractBranchingCandidate, ::Float64, ::Env, ::Reformulation, ::Node
) = error("generate_children not defined for branching candidates of type $(typeof(candidate)).")


# Group

"""
A branching group is the union of a branching candidate and additional information that are
computed during the execution of the branching algorithm (TODO : which one ?).
"""
mutable struct BranchingGroup
    candidate::AbstractBranchingCandidate # the left-hand side in general.
    local_id::Int64
    lhs::Float64
    children::Vector{SbNode}
    isconquered::Bool
    score::Float64
end


############################################################################################
# Selection Criteria of branching candidates
############################################################################################

"""
Supertype of selection criteria of branching candidates.

A selection criterion provides a way to keep only the most promising branching
candidates. To create a new selection criterion, one needs to create a subtype of
`AbstractSelectionCriterion` and implements the method `select_candidates!`.
"""
abstract type AbstractSelectionCriterion end

"""
    select_candidates!(branching_candidates, selection_criterion, max_nb_candidates)

Sort branching candidates according to the selection criterion and remove excess ones.
"""
select_candidates!(::Vector{BranchingGroup}, selection::AbstractSelectionCriterion, ::Int) =
    error("select_candidates! not defined for branching selection rule $(typeof(selection)).")


############################################################################################
# BranchingRuleAlgorithm
############################################################################################

"""
Input of a branching rule (branching separation algorithm)
Contains current solution, max number of candidates and local candidate id.
"""
struct BranchingRuleInput <: AbstractInput 
    solution::PrimalSolution 
    isoriginalsol::Bool
    max_nb_candidates::Int64
    criterion::AbstractSelectionCriterion
    local_id::Int64
    int_tol::Float64
    minimum_priority::Float64
end


"""
Output of a branching rule (branching separation algorithm)
It contains the branching candidates generated and the updated local id value
"""
struct BranchingRuleOutput <: AbstractOutput 
    local_id::Int64
    groups::Vector{BranchingGroup}
end

abstract type AbstractBranchingRule <: AbstractAlgorithm end
 
# branching rules are always manager algorithms (they manage storing and restoring storage units)
ismanager(algo::AbstractBranchingRule) = true

run!(rule::AbstractBranchingRule, ::Env, model::AbstractModel, input::BranchingRuleInput) =
    error("Method run! in not defined for branching rule $(typeof(rule)), model $(typeof(model)), and input $(typeof(input)).")



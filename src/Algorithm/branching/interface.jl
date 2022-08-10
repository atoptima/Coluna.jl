"""
A branching candidate is a data structure that contain all information needed to generate
children of a node.
"""
abstract type AbstractBranchingCandidate end

"Returns a string which serves to print the branching rule in the logs."
getdescription(candidate::AbstractBranchingCandidate) = 
    error("getdescription not defined for branching candidates of type $(typeof(candidate)).")

# Branching candidate and branching rule should be together.
# the rule generates the candidate.

## Note: Branching candidates must be created in the BranchingRule algorithm so they do not need
## a generic constructor.

get_lhs(::AbstractBranchingCandidate) = nothing
get_lhs_distance_to_integer(::AbstractBranchingCandidate) = nothing
get_local_id(::AbstractBranchingCandidate) = nothing
get_children(::AbstractBranchingCandidate) = nothing
set_children!(::AbstractBranchingCandidate, children) = nothing
get_parent(::AbstractBranchingCandidate) = nothing

# TODO: this method should not generate the children of the tree search algorithm.
# However, AbstractBranchingCandidate should implement an interface to retrieve data to
# generate a children.
"""
    generate_children!(branching_candidate, lhs, env, reform, node)

This method generates the children of a node described by `branching_candidate`.
"""
generate_children!(
    candidate::AbstractBranchingCandidate, ::Float64, ::Env, ::Reformulation, ::Node
) = error("generate_children not defined for branching candidates of type $(typeof(candidate)).")

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
select_candidates!(::Vector{C}, selection::AbstractSelectionCriterion, ::Int) where {C <: AbstractBranchingCandidate} =
    error("select_candidates! not defined for branching selection rule $(typeof(selection)).")


############################################################################################
# Branching score
############################################################################################

abstract type AbstractBranchingScore end

compute_score(::AbstractBranchingScore, candidate) = nothing

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
    parent::Node
end

"""
Output of a branching rule (branching separation algorithm)
It contains the branching candidates generated and the updated local id value
"""
struct BranchingRuleOutput <: AbstractOutput 
    local_id::Int64
    candidates::Vector{AbstractBranchingCandidate}
end

abstract type AbstractBranchingRule <: AbstractAlgorithm end
 
# branching rules are always manager algorithms (they manage storing and restoring storage units)
ismanager(algo::AbstractBranchingRule) = true

apply_branching_rule(rule, env, reform, input) = nothing

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
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

"Returns the left-hand side of the candidate."
@mustimplement "BranchingCandidate" get_lhs(c::AbstractBranchingCandidate)

"Returns the generation id of the candidiate."
@mustimplement "BranchingCandidate" get_local_id(c::AbstractBranchingCandidate)

"Returns the children of the candidate."
@mustimplement "BranchingCandidate" get_children(c::AbstractBranchingCandidate)

"Set the children of the candidate."
@mustimplement "BranchingCandidate" set_children!(c::AbstractBranchingCandidate, children)

"Returns the parent node of the candidate's children."
@mustimplement "BranchingCandidate" get_parent(c::AbstractBranchingCandidate)

# TODO: this method should not generate the children of the tree search algorithm.
# However, AbstractBranchingCandidate should implement an interface to retrieve data to
# generate a children.
"""
    generate_children!(branching_candidate, lhs, env, reform, node)

This method generates the children of a node described by `branching_candidate`.
Make sure that this method returns an object the same type as the second argument of
`set_children!(candiate, children)`.
"""
@mustimplement "BranchingCandidate" generate_children!(c::AbstractBranchingCandidate, env, reform, parent)

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

"Sort branching candidates according to the selection criterion and remove excess ones."
@mustimplement "BranchingSelection" select_candidates!(::Vector{<:AbstractBranchingCandidate}, selection::AbstractSelectionCriterion, ::Int)

############################################################################################
# Branching score
############################################################################################
"""
Supertype of branching scores.
"""
abstract type AbstractBranchingScore end

"Returns the score of a candidate."
@mustimplement "BranchingScore" compute_score(::AbstractBranchingScore, candidate)

############################################################################################
# BranchingRuleAlgorithm
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
apply_branching_rule(rule, env, reform, input) = nothing

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
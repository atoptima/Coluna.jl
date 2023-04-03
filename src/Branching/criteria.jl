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
@mustimplement "BranchingSelection" select_candidates!(::Vector{<:AbstractBranchingCandidate}, selection::AbstractSelectionCriterion, ::Int) = nothing

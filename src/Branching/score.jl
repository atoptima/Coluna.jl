
############################################################################################
# Branching score
############################################################################################
"""
Supertype of branching scores.
"""
abstract type AbstractBranchingScore end

"Returns the score of a candidate."
@mustimplement "BranchingScore" compute_score(::AbstractBranchingScore, candidate, input) = nothing
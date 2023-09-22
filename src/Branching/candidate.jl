############################################################################################
# Candidates
############################################################################################

"""
A branching candidate is a data structure that contain all information needed to generate
children of a node.
"""
abstract type AbstractBranchingCandidate end

"Returns a string which serves to print the branching rule in the logs."
@mustimplement "BranchingCandidate" getdescription(candidate::AbstractBranchingCandidate) = nothing

# Branching candidate and branching rule should be together.
# the rule generates the candidate.

## Note: Branching candidates must be created in the BranchingRule algorithm so they do not need
## a generic constructor.

"Returns the left-hand side of the candidate."
@mustimplement "BranchingCandidate" get_lhs(c::AbstractBranchingCandidate) = nothing

"Returns the generation id of the candidiate."
@mustimplement "BranchingCandidate" get_local_id(c::AbstractBranchingCandidate) = nothing

"""
    generate_children!(branching_context, branching_candidate, lhs, env, reform, node)

This method generates the children of a node described by `branching_candidate`.
"""
@mustimplement "BranchingCandidate" generate_children!(ctx, candidate::AbstractBranchingCandidate, env, reform, parent) = nothing

"List of storage units to restore before evaluating the node."
@mustimplement "BranchingCandidate" get_branching_candidate_units_usage(::AbstractBranchingCandidate, reform) = nothing

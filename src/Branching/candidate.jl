############################################################################################
# Candidates
############################################################################################

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

"List of storage units to restore before evaluating the node."
@mustimplement "BranchingCandidate" get_branching_candidate_units_usage(::AbstractBranchingCandidate, reform)


### WIP
### Node for the strong branching (Goal: decouple strong branching from tree search)
### TODO: transform into a very light node dedicated to the strong branching algorithm.
### This light node will contain information to generate the real node of the tree search.
mutable struct SbNode <: TreeSearch.AbstractNode
    depth::Int

    # Receives the current incumbent primal bound of the B&B tree and will be updated using
    # the output of the conquer algorithms called by the strong branching.
    # There information are printed by the StrongBranchingPrinter.
    # These information will be then transfered to the B&B algorithm when instantating the
    # node of the tree search.
    conquer_output::Union{Nothing, OptimizationState}

    branchdescription::String
    ip_dual_bound::Bound
    records::Records
    function SbNode(
        depth, branch_description::String, ip_dual_bound::Bound, records::Records
    )
        return new(depth, nothing, branch_description, ip_dual_bound, records)
    end
end

getdepth(n::SbNode) = n.depth

TreeSearch.set_records!(n::SbNode, records) = n.records = records
TreeSearch.get_branch_description(n::SbNode) = n.branchdescription
TreeSearch.isroot(n::SbNode) = false
Branching.isroot(n::SbNode) = TreeSearch.isroot(n)

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
    optstate::OptimizationState

    var_name::String
    branchdescription::String
    records::Records
    conquerwasrun::Bool
    function SbNode(
        reform::Reformulation, depth, var_name::String, branch_description::String, records::Records, input
    )
        node_state = OptimizationState(
            getmaster(reform);
            ip_dual_bound = get_ip_dual_bound(Branching.get_conquer_opt_state(input))
        )
        return new(depth, node_state, var_name, branch_description, records, false)
    end
end

getdepth(n::SbNode) = n.depth

TreeSearch.set_records!(n::SbNode, records) = n.records = records
TreeSearch.get_branch_description(n::SbNode) = n.branchdescription
get_var_name(n::SbNode) = n.var_name
TreeSearch.isroot(n::SbNode) = false
Branching.isroot(n::SbNode) = TreeSearch.isroot(n)
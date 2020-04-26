####################################################################
#                      Branch
####################################################################

# struct Branch
#     var_coeffs::Dict{VarId, Float64}
#     rhs::Float64
#     sense::ConstrSense
#     depth::Int
# end

# function Branch(var::Variable, rhs::Float64, sense::ConstrSense, depth::Int)
#     var_coeffs = Dict{VarId,Float64}()
#     var_coeffs[getid(var)] = 1.0
#     return Branch(var_coeffs, rhs, sense, depth)
# end

# get_var_coeffs(b::Branch) = b.var_coeffs
# getrhs(b::Branch) = b.rhs
# getsense(b::Branch) = b.sense
# getdepth(b::Branch) = b.depth

# function show(io::IO, branch::Branch, form::Formulation)
#     for (id, coeff) in branch.var_coeffs
#         print(io, " + ", coeff, " ", getname(form, id))
#     end
#     if branch.sense == Greater
#         print(io, " >= ")
#     else
#         print(io, " <= ")
#     end
#     print(io, branch.rhs)
#     return
# end

# apply_branch!(f::Reformulation, ::Nothing) = nothing

# function apply_branch!(f::Reformulation, b::Branch)
#     if b == Nothing
#         return
#     end
#     @logmsg LogLevel(-1) "Adding branching constraint."
#     @logmsg LogLevel(-2) "Apply Branch : " b
#     sense = (getsense(b) == Greater ? "geq_" : "leq_")
#     name = string("branch_", sense,  getdepth(b))
#     # In master we define a branching constraint
#     branch_constraint = setconstr!(
#         f.master, name, MasterBranchOnOrigVarConstr; sense = getsense(b), rhs = getrhs(b),
#         members = get_var_coeffs(b)
#     )
#     # # In subproblems we only change the bounds
#     # # Problem: Only works if val == 1.0 !!! TODO: Fix this problem ?
#     # for (id, val) in get_var_coeffs(b)
#     #     # The following lines should be changed when we store the pointer to the vc represented by the representative
#     #     owner_form = find_owner_formulation(f, getvar(f.master, id))
#     #     if getuid(owner_form) != getuid(f.master)
#     #         sp_var = getvar(owner_form, id)
#     #         getsense(b) == Less && setub!(owner_form, sp_var, getrhs(b))
#     #         getsense(b) == Greater && setlb!(owner_form, sp_var, getrhs(b))
#     #     end
#     #     @logmsg LogLevel(-2) "Branching constraint added : " branch_constraint
#     # end
#     return
# end

####################################################################
#                      ConquerRecord
####################################################################

# """
#     ConquerRecord

#     Record of a conquer algorithm used by the tree search algorithm.
#     Contain ReformulationRecord and records for all storages used by 
#     reformulation algorithms.
# """
# # TO DO : add records for storages and record id
# struct ConquerRecord <: AbstractRecord 
#     # id::Int64
#     reformrecord::ReformulationRecord
#     # storagerecords::Dict{Tuple{AbstractFormulation, Type{<:AbstractStorage}}, AbstractRecord}    
# end

# function record!(reform::Reformulation)::ConquerRecord
#     @logmsg LogLevel(-1) "Recording reformulation state."
#     reformrecord = ReformulationRecord()
#     add_to_recorded!(reform, reformrecord)
#     return ConquerRecord(reformrecord)
# end

# prepare!(reform::Reformulation, ::Nothing) = nothing

# function prepare!(reform::Reformulation, record::ConquerRecord)
#     @logmsg LogLevel(-1) "Preparing reformulation according to node record"
#     @logmsg LogLevel(-1) "Preparing reformulation master"
#     prepare!(getmaster(reform), record.reformrecord)
#     for (spuid, spform) in get_dw_pricing_sps(reform)
#         @logmsg LogLevel(-1) string("Resetting sp ", spuid, " state.")
#         prepare!(spform, record.reformrecord)
#     end
#     return
# end

####################################################################
#                      Node
####################################################################

mutable struct Node 
    tree_order::Int
    istreated::Bool
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    #branch::Union{Nothing, Branch} # branch::Id{Constraint}
    branchdescription::String
    stateids::StorageStatesVector
    conquerwasrun::Bool
end

function RootNode(
    form::AbstractFormulation, treestate::OptimizationState, storagestateids::StorageStatesVector, skipconquer::Bool
)
    nodestate = CopyBoundsAndStatusesFromOptState(form, treestate, false)
    return Node(
        -1, false, 0, nothing, nodestate, "", storagestateids, skipconquer
    )
end

function Node(
    form::AbstractFormulation, parent::Node, branchdescription::String, storagestateids::StorageStatesVector
)
    depth = getdepth(parent) + 1
    nodestate = CopyBoundsAndStatusesFromOptState(form, getoptstate(parent), false)
    
    return Node(
        -1, false, depth, parent, nodestate, branchdescription, storagestateids, false
    )
end

# this function creates a child node by copying info from another child
# used in strong branching
function Node(parent::Node, child::Node)
    depth = getdepth(parent) + 1
    return Node(
        -1, false, depth, parent, getoptstate(child),
        child.branchdescription, child.storagestateids, false
    )
end

get_tree_order(n::Node) = n.tree_order
set_tree_order!(n::Node, tree_order::Int) = n.tree_order = tree_order
getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getbranch(n::Node) = n.branch
getoptstate(n::Node) = n.optstate
addchild!(n::Node, child::Node) = push!(n.children, child)
settreated!(n::Node) = n.istreated = true
istreated(n::Node) = n.istreated
isrootnode(n::Node) = n.tree_order == 1
getinfeasible(n::Node) = n.infesible
setinfeasible(n::Node, status::Bool) = n.infeasible = status

function to_be_pruned(node::Node)
    nodestate = getoptstate(node)
    isinfeasible(nodestate) && return true
    bounds_ratio = get_ip_primal_bound(nodestate) / get_ip_dual_bound(nodestate)
    return isapprox(bounds_ratio, 1) || ip_gap(nodestate) < 0
end

# function restore_node_states!(node::Node, reform::Reformulation, usage::StoragesUsageDict)
#     copy_usage = copy(usage)
#     if getbranch(node) !== nothing
#         copy_usage[(getmaster(reform), BranchingConstrStorage)] = READ_AND_WRITE
#     end
#     restore_states!(node.stateids, copy_usage)

# end

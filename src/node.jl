struct Node <: AbstractNode
    treat_order::Int
    depth::Int
    parent::Union{Nothing, Node}
    children::Vector{Node}
    incumbents::Incumbents
    solver_records::Dict{Type{<:AbstractSolver},AbstractSolverRecord}
end

function RootNode(ObjSense::Type{<:AbstractObjSense})
    return Node(
        1, 0, nothing, Node[], Incumbents(ObjSense),
        Dict{Type{<:AbstractSolver},AbstractSolverRecord}()
    )
end

function Node(parent::Node)
    depth = getdepth(parent) + 1
    incumbents = deepcopy(getincumbents(parent))
    return Node(
        1, depth, parent, Node[], incumbents,
        Dict{Type{<:AbstractSolver},AbstractSolverRecord}()
    )
end

get_treat_order(n::Node) = n.treat_order
getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getincumbents(n::Node) = n.incumbents

addchild!(n::Node, child::Node) = push!(n.children, child)

function set_solver_record!(n::Node, S::Type{<:AbstractSolver}, 
                            r::AbstractSolverRecord)
    n.solver_records[S] = r
end
get_solver_record!(n::Node, S::Type{<:AbstractSolver}) = n.solver_records[S]

function to_be_pruned(n::Node)
    return true
    # How to determine if a node should be pruned?? By the lp_gap?

    # lp_gap(n.incumbents) <= 0.0 && return true
    # return false
end

function record(f::Reformulation, n::Node)
    println("Record for reformulation is empty")
end

function setup(f::Reformulation, n::Node)
    println("Setup for reformulation is empty")
end
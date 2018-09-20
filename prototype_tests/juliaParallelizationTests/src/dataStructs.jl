## This file defines the data structures used in the examples.
#
## Please ignore lines starting with "#IGNORE#"
###################################################################
using Distributed
@everywhere struct DualStruct
    id::Int
    duals_vec::Vector{Float64}
end

@everywhere mutable struct Column
    col_id::Int
    proc_id::Int
    col::Vector{Bool}
    reduced_cost::Float64
    solved::Bool
end
function EmptyColumn()
    return Column(-1, -1, Bool[], 0.0, false)
end

@everywhere mutable struct SolverData
    name::String
    graph::Array{Float64,2}
    n_vars::Int
end
@everywhere EmptyData() = SolverData("", Array{Float64,2}(undef, 0, 0), 0)

struct Messages
    messages_to_waiter::Vector{RemoteChannel}
    messages_to_solver::Vector{RemoteChannel}
    messages_from_workers::RemoteChannel
    results_channel::RemoteChannel
    duals_channels::Vector{RemoteChannel}
end

@everywhere mutable struct Node
    solution::Vector{Bool}
    sol_cost::Float64
    treated::Bool
    conquered::Bool
end
@everywhere UnsolvedNode() = Node(Bool[], 0.0, false, false)


## This file emulates the solution of a parallel branch and bound
## tree.
#
## The solution of nodes are added to the sheduler, which then
## spawns to the procesess.
#
## The used tools are the Julia built-in functions and macros
## available in package 'Distributed'.
#
###################################################################
using Distributed
addprocs(2)
include("dataStructs.jl")
include("create_moi_model.jl")
include("shared_functions.jl")

@everywhere function eval_node(node::Node)
    node.solution = rand(Bool, 10)
    node.sol_cost = 10 + 10*rand() # optimal is 10
    node.treated = true
    node.conquered = rand(Bool)
end

@everywhere function gen_children(node::Node, bb_tree::RemoteChannel)
    println("Generating children")
    children = [UnsolvedNode() for i in 1:2]
    println("Children: ", children)
    for child in children
        put!(bb_tree, child)
    end
end

@everywhere function treat_node(node::Node, bb_tree::RemoteChannel,
                                open_close_nodes_flag::RemoteChannel)

    println("Treating node")
    eval_node(node)
    if node.conquered
        println("Node was conquered")
        put!(open_close_nodes_flag, -1)
    else
        println("Node was not conquered")
        put!(open_close_nodes_flag, 1)
        gen_children(node, bb_tree)
    end

end

@everywhere function solve_bb(bb_tree::RemoteChannel,
                              open_close_nodes_flag::RemoteChannel)
    while true
        node = take!(bb_tree)
        println("Got node")
        treat_node(node, bb_tree, open_close_nodes_flag)
        println("Node treated")
    end

end

function nodes_manager()
    nb_vars = 4

    # The workers put and remove nodes in this channel
    remote_bb_tree = RemoteChannel(()->Channel{Node}(Inf))
    bb_tree = channel_from_id(remoteref_id(remote_bb_tree))
    root_node = UnsolvedNode()
    put!(bb_tree, root_node)

    # Workers send 1 if branch and -1 if node is conquered
    open_close_nodes_flag = RemoteChannel(()->Channel{Int}(Inf))
    put!(open_close_nodes_flag, 1)

    @distributed for worker_id in workers()
        solve_bb(remote_bb_tree, open_close_nodes_flag)
    end

    nb_open_nodes = 0
    while true

        if !isready(open_close_nodes_flag)
            println("Doing work")
            sleep(1.0)
        else
            nb_open_nodes += take!(open_close_nodes_flag)
            println("Doing more work with new information")
            sleep(1.0)
            println("New nb of open nodes: ", nb_open_nodes)
            if nb_open_nodes == 0
                break
            end
        end


    end

end

nodes_manager()


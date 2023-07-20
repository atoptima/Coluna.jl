using Coluna 

# To be able to properly test the tree search implemented in Coluna, we write a redefinition of the tree search interface with a customized search space TestBaBSearchSpace.
# The goal is to simplify the tests writings by giving the possibility to "build" a specific branch and bound tree. 

# To do so, we use customized conquer and divide algorithms, together with node ids. To be more precise, each test corresponds to the construction of a branch and bound tree where the nodes are built thanks to a deterministic divide algorithm where we specify the nodes ids, and a deterministic conquer which matches each node id to the optimization state we want for the given node. 

mutable struct TestBaBSearchSpace <: Coluna.Algorithm.AbstractColunaSearchSpace
    inner::Coluna.Algorithm.BaBSearchSpace
end


# We create a TestBaBNode which wraps a "real" branch and bound Node and carries the node id. 
mutable struct TestBaBNode <: Coluna.TreeSearch.AbstractNode
    inner::Coluna.Algorithm.Node
    id::Int
end

# LightNode are used to contains the minimal information needed to create real nodes. In the tests only LightNode are defined, the re-implementation of the interface is then responsible to create real nodes. 
mutable struct LightNode 
    id::Int
    depth::Int
    parent_ip_dual_bound::Coluna.Algorithm.Bound
end


# Deterministic conquer, a map with all the nodes ids matched to their optimization state
struct DeterministicConquer <: Coluna.Algorithm.AbstractConquerAlgorithm
    conquer::Dict{Int, Coluna.OptimizationState} 
end


struct TestConquerOutput 
    node_id::Int
    inner::Coluna.Algorithm.OptimizationState
end

# Deterministic divide, match each node id to the nodes that should be generated as children from this node.
struct DeterministicDivide <: Coluna.AlgoAPI.AbstractDivideAlgorithm
    divide::Dict{Int, Vector{LightNode}} ## the children are creating using the minimal information, they will turned into real nodes later in the algorithm run
end


struct TestDivideInput <: Coluna.Branching.AbstractDivideInput
    node_id::Int
    parent_conquer_output::Coluna.OptimizationState
end

Coluna.Branching.get_conquer_opt_state(divide_input::TestDivideInput) = return divide_input.parent_conquer_output

# We redefine the interface for TestBaBSearchSpace: 

function Coluna.TreeSearch.search_space_type(::Coluna.Algorithm.TreeSearchAlgorithm)
    return TestBaBSearchSpace
end

function Coluna.TreeSearch.new_space(::Type{TestBaBSearchSpace}, alg, model, input)
    inner_space = Coluna.TreeSearch.new_space(
        Coluna.Algorithm.BaBSearchSpace, 
        alg, model, 
        input)
    return TestBaBSearchSpace(inner_space)
end


# new_root returns a TestBaBNode with id 1 by default. The stack in treesearch (in explore.jl) will therefore contains nodes of type TestBaBNode. 
function Coluna.TreeSearch.new_root(space::TestBaBSearchSpace, input)
    inner = Coluna.TreeSearch.new_root(space.inner, input)
    return TestBaBNode(inner, 1) ## root id is set to 1 by default
end

Coluna.TreeSearch.stop(space::TestBaBSearchSpace, untreated_nodes) = Coluna.TreeSearch.stop(space.inner, untreated_nodes)
Coluna.TreeSearch.tree_search_output(space::TestBaBSearchSpace, untreated_nodes) = Coluna.TreeSearch.tree_search_output(space.inner, untreated_nodes)


# methods called by native method children (in branch_and_bound.jl)
Coluna.Algorithm.get_previous(space::TestBaBSearchSpace) = Coluna.Algorithm.get_previous(space.inner)
Coluna.Algorithm.set_previous!(space::TestBaBSearchSpace, previous::TestBaBNode) = Coluna.Algorithm.set_previous!(space.inner, previous.inner)
Coluna.Algorithm.get_reformulation(space::TestBaBSearchSpace) = Coluna.Algorithm.get_reformulation(space.inner)


Coluna.Algorithm.node_is_leaf(space::TestBaBSearchSpace, current::TestBaBNode, conquer_output::TestConquerOutput) = Coluna.Algorithm.node_is_leaf(space.inner, current.inner, conquer_output.inner)

    


#   *************   redefinition of the methods to implement the deterministic conquer:    *************

Coluna.Algorithm.get_conquer(space::TestBaBSearchSpace) = Coluna.Algorithm.get_conquer(space.inner)

## the only information the deterministic conquer needs is the node id
Coluna.Algorithm.get_input(::DeterministicConquer, ::TestBaBSearchSpace, node::TestBaBNode) = return node.id


## takes the node id as the input, retrieve the corresponding optimization state in the dict, returns it together with the node id to pass them to the divide
function Coluna.Algorithm.run!(alg::DeterministicConquer, env, reform, input)
    println("\e[33m run conquer with node $(input) \e[00m")
    conquer_output = alg.conquer[input]
    return TestConquerOutput(input, conquer_output) ## pass node id as a conquer output
end 

## retrieve the optimization state and call the native method
function Coluna.Algorithm.after_conquer!(space::TestBaBSearchSpace, current, conquer_output)
    return Coluna.Algorithm.after_conquer!(space.inner, current.inner, conquer_output.inner)
end

#   *************   redefinition of the methods to implement the deterministic divide:    *************

Coluna.Algorithm.get_divide(space::TestBaBSearchSpace) = Coluna.Algorithm.get_divide(space.inner)

## the only information the deterministic divide needs is the node id
function Coluna.Algorithm.get_input(::Coluna.AlgoAPI.AbstractDivideAlgorithm, ::TestBaBSearchSpace, ::TestBaBNode, conquer_output)
    return TestDivideInput(conquer_output.node_id, conquer_output.inner)
end

## takes the node id as the input, retrieve the list of (LightNode) children of the corresponding node and returns a DivideOutput made up of these (LightNode) children. 
function Coluna.Algorithm.run!(alg::DeterministicDivide, env::Coluna.Env, reform::Coluna.MathProg.Reformulation, input::TestDivideInput)
    println("\e[33m run divide with node $(input.node_id) \e[00m")
    children = alg.divide[input.node_id]
    return Coluna.Algorithm.DivideOutput(children, nothing) 
end

# constructs a real node from a LightNode, used in new_children to built real children from the minimal information contained in LightNode
function Coluna.Algorithm.Node(node::LightNode)
    return Coluna.Algorithm.Node(node.depth, " ", nothing, node.parent_ip_dual_bound, Coluna.Algorithm.Records(), false)
end

## The candidates are passed as LightNodes and the current node is passed as a TestBaBNode. The method retrieves the inner nodes to run the native method new_children of branch_and_bound.jl, gets the result as a vector of Nodes and then re-built a solution as a vector of TestBaBNodes using the nodes ids contained in LightNode structures.
# branches input is a divide output with children of type LightNode. In the native method new_children in branch_and_bound.jl, those children are retrieved via get_children and then real nodes are created with a direct call to the constructor Node so it is sufficient to re-write a Node(child) method with child a LightNode to make the method works.
function Coluna.Algorithm.new_children(space::TestBaBSearchSpace, branches::Coluna.Algorithm.DivideOutput{LightNode}, node::TestBaBNode)
    new_children_inner = Coluna.Algorithm.new_children(space.inner, branches, node.inner) ## vector of Nodes
    ids = map(node -> node.id, branches.children) ## vector of ids
    children = map( (n, id) -> TestBaBNode(n, id), new_children_inner, ids)## build the list of TestBaBNode
    return children 
end

Coluna.Algorithm.node_change!(previous::Coluna.Algorithm.Node, current::TestBaBNode, space::TestBaBSearchSpace, untreated_nodes) = Coluna.Algorithm.node_change!(previous, current.inner, space.inner, map(n -> n.inner, untreated_nodes))

# end of the interface's redefinition 

# Tests: 

# ```mermaid
# graph TD
#     0( ) --> |ip_dual_bound = 20, \n ip_primal_bound = 40| 1 
#     1((1)) --> |ip_dual_bound = 20, \n ip_primal_bound = 40| 2((2))
#     1 --> |ip_dual_bound = 30, \n ip_primal_bound = 30| 5((5))
#     2 --> |ip_dual_bound = 45, \n ip_primal_bound = 40| 3((3))
#     2 --> |ip_dual_bound = 45, \n ip_primal_bound = 40| 4((4))
#     5 --> |STOP| stop( ) 
# ```
function test_stop_condition()
    ## create an empty formulation
    param = Coluna.Params()
    env = Coluna.Env{Coluna.MathProg.VarId}(param)
    master = Coluna.MathProg.create_formulation!( ## min sense by default
        env,
        Coluna.MathProg.DwMaster()
    )
    reform = Coluna.MathProg.Reformulation(env)
    reform.master = master

    #input = Coluna.OptimizationState( 
    #    master,
    #    ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), 
    #    ip_dual_bound = Coluna.MathProg.DualBound(master, 20.0)
    #)

    input = Coluna.OptimizationState(master)

    ## build initial opt state and final opt state separately to pass some ip and lp primal sols

    lp_primal_sol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 40.0, Coluna.ColunaBase.FEASIBLE_SOL)
    primal_sol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 30.0, Coluna.ColunaBase.FEASIBLE_SOL)

    init_optstate = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    final_optstate = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 30.0), lp_dual_bound = Coluna.MathProg.DualBound(master, 30.0))#optstate of node 5

    ## add primal sols to the nodes
    Coluna.Algorithm.add_lp_primal_sol!(init_optstate, lp_primal_sol)
    Coluna.Algorithm.add_lp_primal_sol!(final_optstate, primal_sol)
    Coluna.Algorithm.add_ip_primal_sol!(final_optstate, primal_sol)


    ## set up the conquer and the divide (and thus the shape of the branch-and-bound tree, see the mermaid diagram below)
    conquermock = DeterministicConquer(
        Dict(
            1 => init_optstate,
            2 => Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0)),
            3 => Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), lp_dual_bound = Coluna.MathProg.DualBound(master, 45.0)), 
            4 => Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), lp_dual_bound = Coluna.MathProg.DualBound(master, 45.0)), 
            5 => final_optstate
        ) 
    )
    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(5, 1, Coluna.Bound(true, false, 20.0)), LightNode(2, 1, Coluna.Bound(true, false, 20.0))], ##remark: should pass first the right child, and second the left child (a bit contre intuitive ?)  ##TODO see and fix code
            2 => [LightNode(4, 2, Coluna.Bound(true, false, 20.0)), LightNode(3, 2, Coluna.Bound(true, false, 20.0))],
            3 => [], 
            4 => [],
            5 => []
        )
    )
    
    treesearch = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conquermock,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)
    algstate = Coluna.Algorithm.run!(treesearch, env, reform, input)
    @show algstate

end

test_stop_condition()

#```mermaid
#graph TD
#     0( ) --> |ip_dual_bound = 20, \n ip_primal_bound = 40| 1 
#     1((1)) --> |ip_dual_bound = 20, \n ip_primal_bound = 20| 2((2))
#     1 --> |should not be explored \n because gap is closed \n at node 2| 3((3)) 
#```
function test_stop_gap_closed()
    ## create an empty formulation
    param = Coluna.Params()
    env = Coluna.Env{Coluna.MathProg.VarId}(param)
    master = Coluna.MathProg.create_formulation!( ## min sense by default
        env,
        Coluna.MathProg.DwMaster()
    )
    reform = Coluna.MathProg.Reformulation(env)
    reform.master = master

    input = Coluna.OptimizationState( 
        master,
        ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), 
        ip_dual_bound = Coluna.MathProg.DualBound(master, 20.0)
    )
    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), ip_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 20.0), ip_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 30.0), ip_dual_bound = Coluna.MathProg.DualBound(master, 20.0)) ## should not be explored

    conquermock = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        )
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 20.0)), LightNode(2, 1, Coluna.DualBound(master, 20.0)),], 
            2 => [],
            3 => []
        )
    )

    treesearch = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conquermock,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)
    algstate = Coluna.Algorithm.run!(treesearch, env, reform, input)
    @show algstate

end

test_stop_gap_closed()


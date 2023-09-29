# To be able to properly test the tree search implemented in Coluna, we write a redefinition of the tree search interface with a customized search space TestBaBSearchSpace.
# The goal is to simplify the tests writings by giving the possibility to "build" a specific branch and bound tree. 

# To do so, we use customized conquer and divide algorithms, together with node ids. To be more precise, each test corresponds to the construction of a branch and bound tree where the nodes are built thanks to a deterministic divide algorithm where we specify the nodes ids, and a deterministic conquer which matches each node id to the optimization state we want for the given node. 

# Flags are added to the conquer and divide algorithms in order to be able to check which nodes have been explored during the execution. The expected behaviour of each test is specified at its beginning. 

# WARNING: the re-implementation is generic, but the tests have been implemented keeping in mind a DFS exploration strategy. The expected results (and therefore the tests) are no longer valid if we change the explore strategy. 

mutable struct TestBaBSearchSpace <: Coluna.Algorithm.AbstractColunaSearchSpace
    inner::Coluna.Algorithm.BaBSearchSpace
end

# We create a TestBaBNode which wraps a "real" branch and bound Node and carries the node id. 
mutable struct TestBaBNode <: Coluna.TreeSearch.AbstractNode
    inner::Coluna.Algorithm.Node
    id::Int
end

# LightNode are used to contains the minimal information needed to create real nodes. In the tests only LightNode are defined, the re-implementation of the interface is then responsible to create real nodes when it is necessary. 
mutable struct LightNode 
    id::Int
    depth::Int
    parent_ip_dual_bound::Coluna.Algorithm.Bound
end

# Deterministic conquer, a map with all the nodes ids matched to their optimization state
struct DeterministicConquer <: Coluna.Algorithm.AbstractConquerAlgorithm
    conquer::Dict{Int, Coluna.OptimizationState}
    new_primal_sol::Dict{Int, Coluna.PrimalSolution}
    run_conquer_on_nodes::Vector{Int}    ## FLAG, node ids of the nodes on which we have run conquer during the execution
end

## the only information the deterministic conquer needs is the node id but we need to embedded it in a TestBaBConquerInput to match the implementation of children in treesearch
struct TestBaBConquerInput
    node_id::Int
    inner::Coluna.Algorithm.ConquerInputFromBaB
end

Coluna.Algorithm.get_global_primal_handler(input::TestBaBConquerInput) = Coluna.Algorithm.get_global_primal_handler(input.inner)
Coluna.Algorithm.get_conquer_input_ip_dual_bound(input::TestBaBConquerInput) = Coluna.Algorithm.get_conquer_input_ip_dual_bound(input.inner)
Coluna.Algorithm.get_node_depth(input::TestBaBConquerInput) = Coluna.Algorithm.get_node_depth(input.inner)
Coluna.Algorithm.get_units_to_restore(input::TestBaBConquerInput) = Coluna.Algorithm.get_units_to_restore(input.inner)

struct TestBaBConquerOutput 
    node_id::Int
    inner::Coluna.Algorithm.OptimizationState ## to update if we create a "real" BaBConquerOutput in the branch and bound 
end

# Deterministic divide, match each node id to the nodes that should be generated as children from this node.
struct DeterministicDivide <: Coluna.AlgoAPI.AbstractDivideAlgorithm
    divide::Dict{Int, Vector{LightNode}} ## the children are creating using the minimal information, they will turned into real nodes later in the algorithm run
    nodes_created_by_divide::Vector{Int} ## FLAG, node ids of the nodes that have been created by divide during the run of the branch-and-bound
    run_divide_on_nodes::Vector{Int}     ## FLAG, node ids of the nodes on which we have run divide 
end

## the only information the deterministic divide needs is the node id but we need to embedded it in a TestBaBDivideInput to match the implementation of children in treesearch
struct TestBaBDivideInput <: Coluna.Branching.AbstractDivideInput
    node_id::Int
    parent_conquer_output::Coluna.OptimizationState ## to update if we create a "real" BaBDivideInput in branch and bound
end
Coluna.Branching.get_conquer_opt_state(divide_input::TestBaBDivideInput) = return divide_input.parent_conquer_output

# We redefine the interface for TestBaBSearchSpace: 
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
Coluna.TreeSearch.tree_search_output(space::TestBaBSearchSpace, untreated_nodes) = Coluna.TreeSearch.tree_search_output(space.inner, map(n -> n.inner, untreated_nodes))

# methods called by native method children (in branch_and_bound.jl)
Coluna.Algorithm.get_previous(space::TestBaBSearchSpace) = Coluna.Algorithm.get_previous(space.inner)
Coluna.Algorithm.set_previous!(space::TestBaBSearchSpace, previous::TestBaBNode) = Coluna.Algorithm.set_previous!(space.inner, previous.inner)
Coluna.Algorithm.get_reformulation(space::TestBaBSearchSpace) = Coluna.Algorithm.get_reformulation(space.inner)

# extra methods needed by the new implementation of treesearch with the storage of the leaves state:
Coluna.Algorithm.node_is_leaf(space::TestBaBSearchSpace, current::TestBaBNode, conquer_output::TestBaBConquerOutput) = Coluna.Algorithm.node_is_leaf(space.inner, current.inner, conquer_output.inner)
Coluna.Algorithm.is_pruned(space::TestBaBSearchSpace, current::TestBaBNode) = Coluna.Algorithm.is_pruned(space.inner, current.inner)
Coluna.Algorithm.node_is_pruned(space::TestBaBSearchSpace, current::TestBaBNode) = Coluna.Algorithm.node_is_pruned(space.inner, current.inner)

#   *************   redefinition of the methods to implement the deterministic conquer:    *************
Coluna.Algorithm.get_conquer(space::TestBaBSearchSpace) = Coluna.Algorithm.get_conquer(space.inner)

## the only information the deterministic conquer needs is the node id, but we need to compute a BaBConquerInput as inner:
function Coluna.Algorithm.get_input(alg::DeterministicConquer, space::TestBaBSearchSpace, node::TestBaBNode)
    inner = Coluna.Algorithm.get_input(alg, space.inner, node.inner)
    return TestBaBConquerInput(node.id, inner)
end

## given the node id in the input, retrieves the corresponding optimization state in the dict, returns it together with the node id to pass them to the divide
function Coluna.Algorithm.run!(alg::DeterministicConquer, env, reform, input)
    push!(alg.run_conquer_on_nodes, input.node_id) ## update flag
    new_primal_sol = get(alg.new_primal_sol, input.node_id, nothing)
    if !isnothing(new_primal_sol)
        # Tell the global primal bound handler that we found a new primal solution.
        Coluna.Algorithm.store_ip_primal_sol!(Coluna.Algorithm.get_global_primal_handler(input), new_primal_sol)
    end

    conquer_output = alg.conquer[input.node_id]
    return TestBaBConquerOutput(input.node_id, conquer_output) ## pass node id as a conquer output
end 

function Coluna.Algorithm.after_conquer!(space::TestBaBSearchSpace, current, conquer_output)
    return Coluna.Algorithm.after_conquer!(space.inner, current.inner, conquer_output.inner)
end

#   *************   redefinition of the methods to implement the deterministic divide:    *************
Coluna.Algorithm.get_divide(space::TestBaBSearchSpace) = Coluna.Algorithm.get_divide(space.inner)

## call to the native routine to check if divide should be run
Coluna.Algorithm.run_divide(space::TestBaBSearchSpace, input::TestBaBDivideInput) = Coluna.Algorithm.run_divide(space.inner, input)

## the only information the deterministic divide needs is the node id but we need to embedded it in a TestBaBDivideInput to match the implementation of children in treesearch
function Coluna.Algorithm.get_input(::Coluna.AlgoAPI.AbstractDivideAlgorithm, ::TestBaBSearchSpace, ::TestBaBNode, conquer_output)
    return TestBaBDivideInput(conquer_output.node_id, conquer_output.inner)
end

## takes the node id as the input, retrieve the list of (LightNode) children of the corresponding node and returns a DivideOutput made up of these (LightNode) children. 
function Coluna.Algorithm.run!(alg::DeterministicDivide, ::Coluna.Env, ::Coluna.MathProg.Reformulation, input::TestBaBDivideInput)
    push!(alg.run_divide_on_nodes, input.node_id) ##update flag
    children = alg.divide[input.node_id]
    for c in children                             ## update flag
        push!(alg.nodes_created_by_divide, c.id)
    end
    return Coluna.Algorithm.DivideOutput(children) 
end

# constructs a real node from a LightNode, used in new_children to built real children from the minimal information contained in LightNode
function Coluna.Algorithm.Node(node::LightNode)
    return Coluna.Algorithm.Node(node.depth, " ", nothing, node.parent_ip_dual_bound, Coluna.Algorithm.Records())
end

## The candidates are passed as LightNodes and the current node is passed as a TestBaBNode. The method retrieves the inner nodes to run the native method new_children of branch_and_bound.jl, gets the result as a vector of Nodes and then re-built a solution as a vector of TestBaBNodes using the nodes ids contained in LightNode structures.
# branches input is a divide output with children of type LightNode. In the native method new_children in branch_and_bound.jl, those children are retrieved via get_children and then real nodes are created with a direct call to the constructor Node so it is sufficient to re-write a Node(child) method with child a LightNode (as above) to make the method works.
function Coluna.Algorithm.new_children(space::TestBaBSearchSpace, branches::Coluna.Algorithm.DivideOutput{LightNode}, node::TestBaBNode)
    new_children_inner = Coluna.Algorithm.new_children(space.inner, branches, node.inner) ## vector of Nodes
    ids = map(node -> node.id, branches.children) ## vector of ids
    children = map( (n, id) -> TestBaBNode(n, id), new_children_inner, ids)## build the list of TestBaBNode
    return children 
end

Coluna.Algorithm.node_change!(previous::Coluna.Algorithm.Node, current::TestBaBNode, space::TestBaBSearchSpace, untreated_nodes) = Coluna.Algorithm.node_change!(previous, current.inner, space.inner, map(n -> n.inner, untreated_nodes))

# end of the interface's redefinition 

# Helper
function _tree_search_reformulation()
    param = Coluna.Params()
    env = Coluna.Env{Coluna.MathProg.VarId}(param)
    origform = Coluna.MathProg.create_formulation!(env, Coluna.MathProg.Original())
    master = Coluna.MathProg.create_formulation!(env, Coluna.MathProg.DwMaster())
    dws = Dict{Coluna.MathProg.FormId, Coluna.MathProg.Formulation{Coluna.MathProg.DwSp}}()
    benders = Dict{Coluna.MathProg.FormId, Coluna.MathProg.Formulation{Coluna.MathProg.BendersSp}}()
    reform = Coluna.MathProg.Reformulation(env, origform, master, dws, benders)
    return reform, env
end

# Tests: 

#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 20, \n ip_primal_sol = 40| 1 
#     1((1)) --> |lp_dual_bound = 20, \n ip_primal_sol = 20| 2((2))
#     1 --> |should not be explored \n because gap is closed \n at node 2| 3((3)) 
#```
# exploration should stop at node 2 because gap is gap_closed
# conquer and divide should not be run on node 3
# divide should not be run on node 2
# status: OPTIMAL with prima solution = 20.0
function test_stop_gap_closed()
    ## create an empty formulation
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master) ## empty input 

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0)) ## should not be explored


    primalsol1 = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 40.0, Coluna.ColunaBase.FEASIBLE_SOL)
    opt_sol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 20.0, Coluna.ColunaBase.FEASIBLE_SOL)

    ## set up the conquer and the divide (and thus the shape of the branch-and-bound tree, see the mermaid diagram below)
    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        ),
        Dict(
            1 => primalsol1,
            2 => opt_sol
        ),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 20.0)), LightNode(2, 1, Coluna.DualBound(master, 20.0))], ##remark: should pass first the right child, and second the left child (a bit contre intuitive ?)  ##TODO see and fix code
            2 => [],
            3 => []
        ),
        [],
        []
    )

    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)

    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OPTIMAL
    @test Coluna.get_best_ip_primal_sol(algstate) == opt_sol
    @test 2 in dividealg.nodes_created_by_divide 
    @test 3 in dividealg.nodes_created_by_divide
    @test !(2 in dividealg.run_divide_on_nodes) ## we converge at node 2, we should not enter divide 
    @test !(3 in conqueralg.run_conquer_on_nodes)
    @test !(3 in dividealg.run_divide_on_nodes)
end
register!(unit_tests, "treesearch", test_stop_gap_closed)

#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 55, \n ip_primal_sol = _| 1((1))
#     1 --> |INFEASIBLE| 2((2))
#     1 --> |INFEASIBLE| 3((3))
#```
# exploration should stop at node 3
# divide should not be called on node 2 and 3
# should return status = INFEASIBLE   
function test_infeasible_pb()
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master) 

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 55.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master)
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master)
    
    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        ),
        Dict(),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 55.0)), LightNode(2, 1, Coluna.DualBound(master, 55.0))], 
            2 => [],
            3 => []
        ),
        [],
        []
    )
    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)

    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.INFEASIBLE
    @test 1 in conqueralg.run_conquer_on_nodes
    @test 2 in conqueralg.run_conquer_on_nodes
    @test 3 in conqueralg.run_conquer_on_nodes
    @test 2 in dividealg.nodes_created_by_divide
    @test 3 in dividealg.nodes_created_by_divide
    @test !(2 in dividealg.run_divide_on_nodes)
    @test !(2 in dividealg.run_divide_on_nodes)
end
register!(unit_tests, "treesearch", test_infeasible_pb)

#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 55, \n ip_primal_sol = 60| 1((1))
#     1 --> |INFEASIBLE| 2((2))
#     1 --> |lp_dual_bound = 60, \n ip_primal_sol = 60| 3((3))
#```
# the exploration should stop on node 3 because the gap is closed
# divide should not be run on node 2 because the subproblem is infeasible

function test_infeasible_sp()
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master) 

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 55.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master)
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 60.0))

    optimalsol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 60.0, Coluna.ColunaBase.FEASIBLE_SOL)
    
    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        ),
        Dict(
            1 => optimalsol,
            3 => optimalsol
        ),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 55.0)), LightNode(2, 1, Coluna.DualBound(master, 55.0))], 
            2 => [],
            3 => []
        ),
        [],
        []
    )
    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)

    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OPTIMAL
    @test Coluna.get_best_ip_primal_sol(algstate) == optimalsol
    @test 2 in dividealg.nodes_created_by_divide
    @test 3 in dividealg.nodes_created_by_divide 
    @test !(2 in dividealg.run_divide_on_nodes)
    @test !(3 in dividealg.run_divide_on_nodes)
    @test 1 in conqueralg.run_conquer_on_nodes
    @test 2 in conqueralg.run_conquer_on_nodes
    @test 3 in conqueralg.run_conquer_on_nodes

end
register!(unit_tests, "treesearch", test_infeasible_sp)


#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 53, \n ip_primal_sol = 60| 1((1))
#     1 --> |lp_dual_bound = 56, \n ip_primal_sol = 60| 2((2))
#     1 --> |lp_dual_bound = 57, \n ip_primal_sol = 60| 3((3))
#```
# not enough information to branch on both leaves 2 and 3 and the gap is not closed at any node
# should return OTHER_LIMIT with dual_bound = 56 (worst among the leaves) and primal bound = 60, all nodes should be explored

function test_all_explored_with_pb()
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master) 

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 53.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 56.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 57.0))

    opt_sol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 60.0, Coluna.ColunaBase.FEASIBLE_SOL)
    
    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        ),
        Dict(
            1 => opt_sol
        ),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 53.0)), LightNode(2, 1, Coluna.DualBound(master, 53.0))], 
            2 => [],
            3 => []
        ),
        [],
        []
    )
    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)

    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OTHER_LIMIT
    @test Coluna.get_best_ip_primal_sol(algstate) == opt_sol
    @test Coluna.get_ip_dual_bound(algstate).value ≈ 56.0 
    @test 2 in dividealg.nodes_created_by_divide
    @test 3 in dividealg.nodes_created_by_divide
    @test 1 in dividealg.run_divide_on_nodes
    @test 2 in dividealg.run_divide_on_nodes
    @test 3 in dividealg.run_divide_on_nodes
    @test 1 in conqueralg.run_conquer_on_nodes 
    @test 2 in conqueralg.run_conquer_on_nodes
    @test 3 in conqueralg.run_conquer_on_nodes
    
end
register!(unit_tests, "treesearch", test_all_explored_with_pb)

#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 53, \n ip_primal_sol = 60| 1((1))
#     1 --> |lp_dual_bound = 56, \n ip_primal_sol = 60| 2((2))
#     1 --> |lp_dual_bound = 57, \n ip_primal_sol = 58| 3((3))
#``` 
# not enough information to branch on leaves, should return OTHER_LIMIT with dual_bound = 56 and primal_bound = 58
function test_all_explored_with_pb_2()
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master) 

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 53.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 56.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 57.0))

    primal_sol1 = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 60.0, Coluna.ColunaBase.FEASIBLE_SOL)
    opt_sol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 58.0, Coluna.ColunaBase.FEASIBLE_SOL)

    
    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        ),
        Dict(
            1 => primal_sol1,
            3 => opt_sol
        ),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 53.0)), LightNode(2, 1, Coluna.DualBound(master, 53.0))], 
            2 => [],
            3 => []
        ),
        [],
        []
    )
    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)

    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OTHER_LIMIT
    @test Coluna.get_best_ip_primal_sol(algstate) == opt_sol
    @test Coluna.get_ip_dual_bound(algstate).value ≈ 56.0 
    @test 2 in dividealg.nodes_created_by_divide
    @test 3 in dividealg.nodes_created_by_divide
    @test 1 in dividealg.run_divide_on_nodes
    @test 2 in dividealg.run_divide_on_nodes
    @test 3 in dividealg.run_divide_on_nodes
    @test 1 in conqueralg.run_conquer_on_nodes 
    @test 2 in conqueralg.run_conquer_on_nodes
    @test 3 in conqueralg.run_conquer_on_nodes
end
register!(unit_tests, "treesearch", test_all_explored_with_pb_2)

#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 55, \n ip_primal_bound = _| 1((1))
#     1 --> |lp_dual_bound = 56, \n ip_primal_bound = _| 2((2))
#     1 --> |lp_dual_bound = 57, \n ip_primal_bound = _| 3((3))
#
#```
# not enough information to branch on both leaves
# no primal bound
# should return OTHER_LIMIT with dual_bound = 56
function test_all_explored_without_pb()
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master) 

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 55.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 56.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 57.0))

    
    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3
        ),
        Dict(),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(3, 1, Coluna.DualBound(master, 53.0)), LightNode(2, 1, Coluna.DualBound(master, 53.0))], 
            2 => [],
            3 => []
        ),
        [],
        []
    )
    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)

    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OTHER_LIMIT
    @test Coluna.get_ip_dual_bound(algstate).value ≈ 56.0
    @test isnothing(Coluna.get_best_ip_primal_sol(algstate))
    @test 2 in dividealg.nodes_created_by_divide
    @test 3 in dividealg.nodes_created_by_divide
    @test 1 in dividealg.run_divide_on_nodes
    @test 2 in dividealg.run_divide_on_nodes
    @test 3 in dividealg.run_divide_on_nodes
    @test 1 in conqueralg.run_conquer_on_nodes
    @test 2 in conqueralg.run_conquer_on_nodes
    @test 3 in conqueralg.run_conquer_on_nodes
    
end
register!(unit_tests, "treesearch", test_all_explored_without_pb)

# ```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 20, \n ip_primal_sol = 40| 1 
#     1((1)) --> |lp_dual_bound = 20, \n ip_primal_sol = 40| 2((2))
#     1 --> |lp_dual_bound = 30, \n ip_primal_sol = 30| 5((5))
#     2 --> |lp_dual_bound = 45, \n ip_primal_sol = 40| 3((3))
#     2 --> |lp_dual_bound = 45, \n ip_primal_sol = 40| 4((4))
#     5 --> |STOP| stop( )  
# ```
# At nodes 3 and 4, the local lp_dual_bound > the primal bound but the global dual bound < primal bound so the algorithm should continue and stop at node 5 when gap is closed
# status: OPTIMAL with primal solution = 30.0
function test_local_db()
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master)

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.MathProg.PrimalBound(master, 40.0), lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 20.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 45.0))
    optstate4 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 45.0))
    optstate5 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 30.0))

    primalsol1 = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 40.0, Coluna.ColunaBase.FEASIBLE_SOL)
    optimalsol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 30.0, Coluna.ColunaBase.FEASIBLE_SOL)

    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3, 
            4 => optstate4, 
            5 => optstate5
        ),
        Dict(
            1 => primalsol1,
            5 => optimalsol
        ),
        []
    )
    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(5, 1, Coluna.DualBound(master, 20.0)), LightNode(2, 1, Coluna.DualBound(master, 20.0))], 
            2 => [LightNode(4, 2, Coluna.DualBound(master, 20.0)), LightNode(3, 2, Coluna.DualBound(master, 20.0))],
            3 => [], 
            4 => [],
            5 => []
        ),
        [],
        []
    )
    
    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)
    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OPTIMAL
    @test Coluna.get_best_ip_primal_sol(algstate) == optimalsol
    @test 2 in dividealg.nodes_created_by_divide
    @test 3 in dividealg.nodes_created_by_divide 
    @test 4 in dividealg.nodes_created_by_divide
    @test 5 in dividealg.nodes_created_by_divide 
    @test !(3 in dividealg.run_divide_on_nodes) ## 3 and 4 should not be in run_divide_on_nodes ; they are pruned because their local db is worst than the current best primal sol
    @test !(4 in dividealg.run_divide_on_nodes)
    @test !(5 in dividealg.run_divide_on_nodes)
end
register!(unit_tests, "treesearch", test_local_db)

#```mermaid
#graph TD
#     0( ) --> |lp_dual_bound = 55, \n ip_primal_sol = 60| 1 
#     1((1)) --> |lp_dual_bound = 55, \n ip_primal_sol = 56| 2((2))
#     2 --> |lp_dual_bound = 56, \n ip_primal_sol = 56| 3((3))
#     2 --> |lp_dual_bound = 56, \n ip_primal_sol = 56| 4((4))
#     1 --> |lp_dual_bound = 57, \n ip_primal_sol = 60| 5((5))
#     5 --> |STOP \n because primal sol found at 2\n is better than current db| 6( )
#```
# exploration should not stop at nodes 3 and 4 because the gap between the local lp_dual_bound and the ip_primal_bound is closed, but not with the global dual bound. However, it should be stopped at node 5 because the primal bound found at node 2 is better than the local dual bound of node 5. 
# status: OPTIMAL with primal solution = 56.0
function test_pruning()
    ## create an empty formulation
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)

    input = Coluna.OptimizationState(master)

    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 55.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 55.0))
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 56.0)) 
    optstate4 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 56.0)) 
    optstate5 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 57.0))

    primal_sol1 = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 60.0, Coluna.ColunaBase.FEASIBLE_SOL)
    opt_sol = Coluna.PrimalSolution(master, Vector{Coluna.MathProg.VarId}(), Vector{Float64}(), 56.0, Coluna.ColunaBase.FEASIBLE_SOL)

    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3,
            4 => optstate4,
            5 => optstate5,
            6 => Coluna.OptimizationState(master), ##should not be called
            7 => Coluna.OptimizationState(master) ##should not be called
        ),
        Dict(
            1 => primal_sol1,
            2 => opt_sol
        ),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(5, 1, Coluna.DualBound(master, 55.0)), LightNode(2, 1, Coluna.DualBound(master, 55.0))], 
            2 => [LightNode(4, 2, Coluna.DualBound(master, 55.0)), LightNode(3, 2, Coluna.DualBound(master, 55.0))], 
            3 => [],
            4 => [],
            5 => [LightNode(7, 2, Coluna.DualBound(master, 57.0)), LightNode(6, 2, Coluna.DualBound(master, 57.0))], ##should not be called
            6 => [],##should not be called
            7 => [] ##should not be called,
        ),
        [],
        []
    )

    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
    )
    
    Coluna.set_optim_start_time!(env)
    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OPTIMAL
    @test Coluna.get_best_ip_primal_sol(algstate) == opt_sol
    @test !(6 in dividealg.nodes_created_by_divide) # 6 and 7 should not be created as 5 is pruned
    @test !(7 in dividealg.nodes_created_by_divide)
    @test !(3 in dividealg.run_divide_on_nodes) ## 3 and 4 should not be in run_divide_on_nodes ; they are pruned because their local db is equal to the current best primal sol
    @test !(4 in dividealg.run_divide_on_nodes)
    @test !(5 in dividealg.run_divide_on_nodes) ## 5 is not in run_divide_on_nodes either ; it is pruned because best primal bound found at node 2 is better than its db
    @test 5 in conqueralg.run_conquer_on_nodes ## however, 5 is in run_conquer_on_nodes because when it inherites the db from its parent, this db is better than the best primal solution
    @test !(6 in conqueralg.run_conquer_on_nodes)
    @test !(7 in conqueralg.run_conquer_on_nodes)

end
register!(unit_tests, "treesearch", test_pruning)


function test_one_leaf_infeasible_and_then_node_limit()
    ## create an empty formulation
    reform, env = _tree_search_reformulation()
    master = Coluna.MathProg.getmaster(reform)
    
    input = Coluna.OptimizationState(master)
    optstate1 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 55.0))
    optstate2 = Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master)
    optstate3 = Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, lp_dual_bound = Coluna.MathProg.DualBound(master, 65.0))

    conqueralg = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => optstate2,
            3 => optstate3 # should not be called
        ),
        Dict(),
        []
    )

    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(2, 1, Coluna.DualBound(master, 65.0)), LightNode(3, 1, Coluna.DualBound(master, 65.0))], 
            2 => [], ##should not be called
            3 => [], ##should not be called
        ),
        [],
        []
    )

    algo = Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg = conqueralg,
        dividealg = dividealg,
        explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
        maxnumnodes = 2
    )
    
    Coluna.set_optim_start_time!(env)
    search_space = Coluna.TreeSearch.new_space(TestBaBSearchSpace, algo, reform, input)
    algstate = Coluna.TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)

    @test Coluna.getterminationstatus(algstate) == Coluna.OTHER_LIMIT
    @show Coluna.getterminationstatus(algstate)
end
register!(unit_tests, "treesearch", test_one_leaf_infeasible_and_then_node_limit)


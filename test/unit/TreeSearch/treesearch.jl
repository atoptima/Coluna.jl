using Coluna 

## comments
# alternative (but broken) version in tmp.jl

# the user creates the nodes via the deterministic divide and indicates the nodes ids which are going to be used in the conquer and the divid. It uses LightNode which contains the ids)
# the ids are retrieved in new_children to create TestBaBNodes

# a large part of the PrinterSearchSpace code is skipped by using inner.inner

# TODO: see if it is necessary to have a wrapped search space to manage the nodes ids (PrinterSearchSpace or the other available in tmp.jl)
# -> try to test like this and see ...

# at the moment there is a trick used in new_children to avoid the management of node ids

### structures

mutable struct LightNode 
    id::Int
    depth::Int
    parent_ip_dual_bound::Coluna.Algorithm.Bound
end

mutable struct TestBaBNode <: Coluna.TreeSearch.AbstractNode
    inner::Coluna.Algorithm.Node
    id::Int
end


## construct a real node from an LightNode, used in new_children to built real children from the minimal information contained in LightNode
function Coluna.Algorithm.Node(node::LightNode)
    return Coluna.Algorithm.Node(node.depth, " ", nothing, node.parent_ip_dual_bound, Coluna.Algorithm.Records(), false)
end

mutable struct TestBaBSearchSpace <: Coluna.Algorithm.AbstractColunaSearchSpace
    inner::Coluna.Algorithm.BaBSearchSpace
end

## contains the original conquer input and some extra information used for testing
struct TestConquerInputFromBab <: Coluna.Algorithm.AbstractConquerAlgorithm
    inner::Coluna.Algorithm.ConquerInputFromBaB
    node_id::Int  
end

## contains the original divide input and some extra information used for testing
struct TestDivideInputFromBab
    inner::Coluna.Algorithm.DivideInputFromBaB
    node_id::Int
end


## deterministic conquer, a map with all the nodes id matched to their optimisation state
struct DeterministicConquer <: Coluna.Algorithm.AbstractConquerAlgorithm
    conquer::Dict{Int, Coluna.OptimizationState} ## match each node id with its optimisation state
end

## deterministic divide, match each node to the nodes that should be generated from it as children
struct DeterministicDivide <: Coluna.AlgoAPI.AbstractDivideAlgorithm
    divide::Dict{Int, Vector{LightNode}} #the vector of children can also be empty
end

################    redefine the interface to be able to test the implementation : no tests for the moment ###################################  

function Coluna.TreeSearch.search_space_type(alg::Coluna.Algorithm.TreeSearchAlgorithm)
    println("\e[33m hello from search space type \e[00m")
    return TestBaBSearchSpace
end

function Coluna.TreeSearch.new_space(::Type{TestBaBSearchSpace}, alg, model, input)
    println("\e[33m hello from new space \e[00m")
    inner_space = Coluna.TreeSearch.new_space(
        Coluna.Algorithm.BaBSearchSpace, 
        alg, model, 
        input)
    return TestBaBSearchSpace(inner_space)
end

## direct call to printer root
function Coluna.TreeSearch.new_root(space::TestBaBSearchSpace, input)
    println("\e[33m hello from new root \e[00m")
    inner = Coluna.TreeSearch.new_root(space.inner, input)
    return TestBaBNode(inner, 1) ## we can even imagine to pass the root id in input
end

function Coluna.TreeSearch.stop(space::TestBaBSearchSpace, untreated_nodes)
    println("\e[33m hello from stop \e[00m")
    return Coluna.TreeSearch.stop(space.inner, untreated_nodes)
end


function Coluna.TreeSearch.tree_search_output(space::TestBaBSearchSpace, untreated_nodes)
    println("\e[33m hello from tree_search_output \e[00m")
    return Coluna.TreeSearch.tree_search_output(space.inner, untreated_nodes)
end

## methods called by children

function Coluna.Algorithm.get_previous(space::TestBaBSearchSpace)
    println("\e[33m hello from get_previous \e[00m")
    @show typeof(Coluna.Algorithm.get_previous(space.inner))
    return Coluna.Algorithm.get_previous(space.inner)
end

function Coluna.Algorithm.set_previous!(space::TestBaBSearchSpace, previous::TestBaBNode)
    println("\e[33m hello from set_previous \e[00m")
    return Coluna.Algorithm.set_previous!(space.inner, previous.inner)
end

function Coluna.Algorithm.get_reformulation(space::TestBaBSearchSpace)
    println("\e[33m hello from get_reformulation \e[00m")
    return Coluna.Algorithm.get_reformulation(space.inner)


end
##################### methods to implement deterministic conquer #####################

function Coluna.Algorithm.get_conquer(space::TestBaBSearchSpace)
    println("\e[33m hello from get_reformulation \e[00m")
    return Coluna.Algorithm.get_conquer(space.inner)
end

## to modify to add the node id to the conquer
function Coluna.Algorithm.get_input(alg::DeterministicConquer, space::TestBaBSearchSpace, node::TestBaBNode)
    println("\e[33m hello from conquer get_input \e[00m")
    inner = Coluna.Algorithm.get_input(alg, space.inner, node.inner)
    return TestConquerInputFromBab(inner, node.id)
end

## return a "real" conquer output (an OptimizationState) -> may changed depending on divide input
function Coluna.Algorithm.run!(alg::DeterministicConquer, env, reform, input::TestConquerInputFromBab)
    println("\e[33m hello from run conquer \e[00m")
    conquer_output = alg.conquer[input.node_id]
    return (input.node_id, conquer_output) ## pass node id as a conquer output
end 

function Coluna.Algorithm.after_conquer!(space::TestBaBSearchSpace, current, conquer_output)
    println("\e[33m hello from after conquer \e[00m")
    (_, conquer_output) = conquer_output
    return Coluna.Algorithm.after_conquer!(space.inner, current.inner, conquer_output)
end

##################### methods to implement deterministic divide ##################### 

function Coluna.Algorithm.get_divide(space::TestBaBSearchSpace)
    println("\e[33m hello from get divide \e[00m")
    return Coluna.Algorithm.get_divide(space.inner)
end

function Coluna.Algorithm.get_input(alg::Coluna.AlgoAPI.AbstractDivideAlgorithm, space::TestBaBSearchSpace, node::TestBaBNode, conquer_output)
    println("\e[33m hello from divide get input \e[00m")
    @show typeof(conquer_output)
    (node_id, conquer_output) = conquer_output
    @show typeof(conquer_output)
    @show node_id
    return TestDivideInputFromBab(
        Coluna.Algorithm.get_input(alg, space.inner, node.inner, conquer_output),
        node_id
    )
end


## must return "branches", return as DivideInput{LightNode}
function Coluna.Algorithm.run!(alg::DeterministicDivide, env, reform, input)
    println("\e[33m hello from run divide \e[00m")
    children = alg.divide[input.node_id]
    return Coluna.Algorithm.DivideOutput(children, nothing) ## optimizationstate useless ? 
end

## The candidates are passed as LightNodes, the current node is passed as a TestBaBNode, the method retrieve the inner nodes to run the method new_children implemented in Coluna branch and bound, retrieve the result as a vector of Nodes and then re-built a solution as a vector of TestBaBNodes using the node ids passed with LightNodes.
## branches is a divide output with LightNodes as children -> in the native method new_children in branch_and_bound.jl, those children are retrieved via get_children and then real nodes are created with a direct call to the constructor Node so it is sufficient to re-write a Node(child) method with child a LightNode to make the method works
## TODO clean that diiiiiirty method 
function Coluna.Algorithm.new_children(space::TestBaBSearchSpace, branches::Coluna.Algorithm.DivideOutput{LightNode}, node::TestBaBNode)
    println("\e[33m hello from new_children \e[00m")
    parent_id = node.id
    new_children_inner = Coluna.Algorithm.new_children(space.inner, branches, node.inner) ## vector of Nodes
    @show typeof(new_children_inner)
    @show new_children_inner
    tmp = [(new_children_inner[i], branches.children[i].id) for i in 1:length(new_children_inner)]
    @show tmp
    res = Vector{TestBaBNode}()
    for (n, id) in tmp
        push!(res, TestBaBNode(n, id))
    end
    return res

end


function Coluna.Algorithm.node_change!(previous::Coluna.Algorithm.Node, current::TestBaBNode, space::TestBaBSearchSpace, untreated_nodes)
    println("\e[33m hello from node_change! \e[00m")
    Coluna.Algorithm.node_change!(previous, current.inner, space.inner, map(n -> n.inner, untreated_nodes))
end

###################################  end of interface's redefinition  ###################################  


####################  to be later put in a test ####################  

# ```mermaid
# graph TD
#     0( ) --> |ip_dual_bound = 20, \n ip_primal_bound = 40| 1 
#     1((1)) --> |ip_dual_bound = 20, \n ip_primal_bound = 40| 2((2))
#     1 --> |ip_dual_bound = 30, \n ip_primal_bound = 30| 5((5))
#     2 --> |ip_dual_bound = 45, \n ip_primal_bound = 40| 3((3))
#     2 --> |ip_dual_bound = 45, \n ip_primal_bound = 40| 4((4))
#     5 --> |STOP| stop( ) 
# ````
function test_stop_condition()
    #### create an empty formulation
    param = Coluna.Params()
    env = Coluna.Env{Coluna.MathProg.VarId}(param)
    master = Coluna.MathProg.create_formulation!( ## empty formulation, min sense by default
        env,
        Coluna.MathProg.DwMaster()
    )
    reform = Coluna.MathProg.Reformulation(env)
    reform.master = master
    #### create the nodes (for the divide) and their optimization state (for the conquer)
    ## optstates returned by the deterministic conquer
    optstate1 = Coluna.OptimizationState( ## root : ## TODO use input arg in run! to properly init the root
        master,
        ip_primal_bound = Coluna.Bound(true, true, 40.0), # min sense, primal, value
        ip_dual_bound = Coluna.Bound(true, false, 20.0)
    )

    #### set up the algos
    conquermock = DeterministicConquer(
        Dict(
            1 => optstate1,
            2 => Coluna.OptimizationState(master, ip_primal_bound = Coluna.Bound(true, true, 40.0), ip_dual_bound = Coluna.Bound(true, false, 20.0)),
            3 => Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master, ip_primal_bound = Coluna.Bound(true, true, 40.0), ip_dual_bound = Coluna.Bound(true, false, 45.0)), ##should return done (infeasible ?)
            4 => Coluna.OptimizationState(termination_status = Coluna.INFEASIBLE, master, ip_primal_bound = Coluna.Bound(true, true, 40.0), ip_dual_bound = Coluna.Bound(true, false, 45.0)), ##shoudl return done
            5 => Coluna.OptimizationState(termination_status = Coluna.OPTIMAL, master, ip_primal_bound = Coluna.Bound(true, true, 30.0), ip_dual_bound = Coluna.Bound(true, false, 30.0))
            ## TODO : set termination status essential here ? 
        )
    )
    dividealg = DeterministicDivide(
        Dict(
            1 => [LightNode(5, 1, Coluna.Bound(true, false, 20.0)), LightNode(2, 1, Coluna.Bound(true, false, 20.0))], ##remark: should pass first the right child, and second the left child (a bit contre intuitive ?)
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
    
    input = optstate1
    
    
    Coluna.set_optim_start_time!(env)
    algstate = Coluna.Algorithm.run!(treesearch, env, reform, input)
    @show algstate

end

test_stop_condition()



using Coluna 

### structures

mutable struct TestBaBSearchSpace <: Coluna.Algorithm.AbstractColunaSearchSpace
    inner::Coluna.Algorithm.PrinterSearchSpace
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
    divide::Dict{Int, Vector{Coluna.Algorithm.PrintedNode}} #the vector of children can also be empty
end

#######  redefine the interface to be able to test the implementation : no tests for the moment 

function Coluna.TreeSearch.search_space_type(alg::Coluna.Algorithm.TreeSearchAlgorithm)
    println("\e[33m hello from search space type \e[00m")
    return TestBaBSearchSpace
end

function Coluna.TreeSearch.new_space(::Type{TestBaBSearchSpace}, alg, model, input)
    println("\e[33m hello from new space \e[00m")
    inner_space = Coluna.TreeSearch.new_space(
        Coluna.Algorithm.PrinterSearchSpace{Coluna.Algorithm.BaBSearchSpace,Coluna.Algorithm.DefaultLogPrinter,Coluna.Algorithm.DevNullFilePrinter}, 
        alg, model, 
        input)
    return TestBaBSearchSpace(inner_space)
end

## direct call to printer root
function Coluna.TreeSearch.new_root(space::TestBaBSearchSpace, input)
    println("\e[33m hello from new root \e[00m")
    return Coluna.TreeSearch.new_root(space.inner, input)
end

function Coluna.TreeSearch.stop(space::TestBaBSearchSpace, untreated_nodes)
    println("\e[33m hello from stop \e[00m")
    return Coluna.TreeSearch.stop(space.inner, untreated_nodes)
end


function Coluna.TreeSearch.tree_search_output(space::TestBaBSearchSpace, untreated_nodes)
    println("\e[33m hello from tree_search_output \e[00m")
    return Coluna.TreeSearch.tree_search_output(space.inner.inner, untreated_nodes)
end

## methods called by children

function Coluna.Algorithm.get_previous(space::TestBaBSearchSpace)
    println("\e[33m hello from get_previous \e[00m")
    return Coluna.Algorithm.get_previous(space.inner.inner)
end

function Coluna.Algorithm.set_previous!(space::TestBaBSearchSpace, previous::Coluna.Algorithm.PrintedNode)
    println("\e[33m hello from set_previous \e[00m")
    return Coluna.Algorithm.set_previous!(space.inner.inner, previous.inner)
end

function Coluna.Algorithm.get_reformulation(space::TestBaBSearchSpace)
    println("\e[33m hello from get_reformulation \e[00m")
    return Coluna.Algorithm.get_reformulation(space.inner.inner)


end
##################### deterministic conquer #####################

function Coluna.Algorithm.get_conquer(space::TestBaBSearchSpace)
    println("\e[33m hello from get_reformulation \e[00m")
    return Coluna.Algorithm.get_conquer(space.inner.inner)
end

## to modify to add the node id to the conquer
function Coluna.Algorithm.get_input(alg::DeterministicConquer, space::TestBaBSearchSpace, node::Coluna.Algorithm.PrintedNode)
    println("\e[33m hello from conquer get_input \e[00m")
    inner = Coluna.Algorithm.get_input(alg, space.inner.inner, node.inner)
    return TestConquerInputFromBab(inner, node.tree_order_id)
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
    return Coluna.Algorithm.after_conquer!(space.inner.inner, current.inner, conquer_output)
end

##################### deterministic divide ##################### 

function Coluna.Algorithm.get_divide(space::TestBaBSearchSpace)
    println("\e[33m hello from get divide \e[00m")
    @show typeof(Coluna.Algorithm.get_divide(space.inner.inner))
    return Coluna.Algorithm.get_divide(space.inner.inner)
end

function Coluna.Algorithm.get_input(alg::Coluna.AlgoAPI.AbstractDivideAlgorithm, space::TestBaBSearchSpace, node::Coluna.Algorithm.PrintedNode, conquer_output)
    println("\e[33m hello from divide get input \e[00m")
    @show typeof(conquer_output)
    (node_id, conquer_output) = conquer_output
    @show typeof(conquer_output)
    @show node_id
    return TestDivideInputFromBab(
        Coluna.Algorithm.get_input(alg, space.inner.inner, node.inner, conquer_output),
        node_id
    )
end


## must return "branches"
function Coluna.Algorithm.run!(alg::DeterministicDivide, env, reform, input)
    println("\e[33m hello from run divide \e[00m")
    children = alg.divide[input.node_id]
    return Coluna.Algorithm.DivideOutput(children, nothing) ## TODO: find a way to create the children here and pass it to new_children ; must also be wrapped to be PrintedNode ? 
end

## The candidates and the current node are passed as PrintedNode, the method retrieve the inner nodes to run the method new_children implemented in Coluna branch and bound, retrieve the result as a vector of Nodes and then re-built a solution as a vector of PrintedNodes. 
function Coluna.Algorithm.new_children(space::TestBaBSearchSpace, branches::Coluna.Algorithm.DivideOutput{Coluna.Algorithm.PrintedNode}, node::Coluna.Algorithm.PrintedNode)
    println("\e[33m hello from new_children \e[00m")
    parent_id = node.tree_order_id
    branches_inner = Coluna.Algorithm.DivideOutput(
        map(n -> n.inner, branches.children),
        nothing ## TODO see if need to change
    )

    new_children_inner = Coluna.Algorithm.new_children(space.inner.inner, branches_inner, node.inner)

    return map(n -> Coluna.Algorithm.PrintedNode(parent_id + 1, parent_id, n), new_children_inner)

end




####################  to be later put in a test ####################  




#### create an empty formulation
param = Coluna.Params()
env = Coluna.Env{Coluna.MathProg.VarId}(param)
master = Coluna.MathProg.create_formulation!( ## empty formulation
    env,
    Coluna.MathProg.DwMaster()
)
reform = Coluna.MathProg.Reformulation(env)
reform.master = master

#### set up the algo 
conquermock = DeterministicConquer(
    Dict(
        1 => Coluna.Algorithm.OptimizationState(Coluna.getmaster(reform))
    )
)
dividealg = DeterministicDivide(
    Dict(
        1 => []
    )
)

treesearch = Coluna.Algorithm.TreeSearchAlgorithm(
    conqueralg = conquermock,
    dividealg = dividealg,
    explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
)

input = Coluna.OptimizationState(Coluna.getmaster(reform))


Coluna.set_optim_start_time!(env)
Coluna.Algorithm.run!(treesearch, env, reform, input)

#{Coluna.Algorithm.PrinterSearchSpace{Coluna.Algorithm.BaBSearchSpace,Coluna.Algorithm.DefaultLogPrinter,Coluna.Algorithm.DevNullFilePrinter}}
using Coluna 

### structures

mutable struct TestBaBSearchSpace <: Coluna.Algorithm.AbstractColunaSearchSpace
    inner::Coluna.Algorithm.PrinterSearchSpace
end

## contains the original conquer input and some extra information used for test
struct TestConquerInputFromBab <: Coluna.Algorithm.AbstractConquerAlgorithm
    inner::Coluna.Algorithm.ConquerInputFromBaB
    node_id::Int ## TODO see if other type 
end

## deterministic conquer, a map with all the nodes id matched to their optimisation state
struct DeterministicConquer <: Coluna.Algorithm.AbstractConquerAlgorithm
    conquer::Dict{Int, Coluna.OptimizationState} ## match each node id with its optimisation state
end

# redefine the interface to be able to test the implementation : no tests for the moment 

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
    println("\e[33m hello from get_input \e[00m")
    inner = Coluna.Algorithm.get_input(alg, space.inner.inner, node.inner)
    return TestConquerInputFromBab(inner, node.tree_order_id)
end

## return a "real" conquer output (an OptimizationState) -> may changed depending on divide input
function Coluna.Algorithm.run!(alg::DeterministicConquer, env, reform, input::TestConquerInputFromBab)
    println("\e[33m hello from run conquer \e[00m")
    conquer_output = alg.conquer[input.node_id]
    return conquer_output
end 

function Coluna.Algorithm.after_conquer!(space::TestBaBSearchSpace, current, conquer_output)
    @show typeof(current)
    println("\e[33m hello from after conquer \e[00m")
    return Coluna.Algorithm.after_conquer!(space.inner.inner, current.inner, conquer_output)
end

##################### divide ##################### 

function Coluna.Algorithm.get_divide(space::TestBaBSearchSpace)
    println("\e[33m hello from get divide \e[00m")
    return Coluna.Algorithm.get_divide(space.inner.inner)
end

function Coluna.Algorithm.get_input(alg::Coluna.AlgoAPI.AbstractDivideAlgorithm, space::TestBaBSearchSpace, node::Coluna.Algorithm.PrintedNode, conquer_output)
    println("\e[33m hello from get input \e[00m")
    @show typeof(conquer_output)
    return Coluna.Algorithm.get_input(alg, space.inner.inner, node.inner, conquer_output)
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
dividealg = Coluna.Algorithm.ClassicBranching()

treesearch = Coluna.Algorithm.TreeSearchAlgorithm(
    conqueralg = conquermock,
    dividealg = dividealg,
    explorestrategy = Coluna.TreeSearch.DepthFirstStrategy(),
)

input = Coluna.OptimizationState(Coluna.getmaster(reform))


Coluna.set_optim_start_time!(env)
Coluna.Algorithm.run!(treesearch, env, reform, input)

#{Coluna.Algorithm.PrinterSearchSpace{Coluna.Algorithm.BaBSearchSpace,Coluna.Algorithm.DefaultLogPrinter,Coluna.Algorithm.DevNullFilePrinter}}
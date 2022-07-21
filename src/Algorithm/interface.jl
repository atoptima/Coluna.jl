## Methods for updated interface for algorithms

"Supertype for algorithms."
abstract type AbstractAlgorithm end

"Supertype for algorithms inputs."
abstract type AbstractInput end 

"Supertype for algorithms outputs."
abstract type AbstractOutput end 

"""
    run!(algo::AbstractAlgorithm, model::AbstractModel, input::AbstractInput)::AbstractOutput

Runs the algorithm. The storage unit of the algorithm can be obtained from the data
Returns algorithm's output.    
"""
function run!(algo::AbstractAlgorithm, env::Env, model::AbstractModel, input::AbstractInput)::AbstractOutput
    error("Cannot apply run! for arguments $(typeof(algo)), $(typeof(model)), $(typeof(input)).")
end

new_space(::AbstractAlgorithm, env::Env, reform::Reformulation, input::AbstractInput) = nothing




## WIP below

"""
About algorithms
----------------

An algorithm is a procedure with a known interface (input and output) applied to a data.
An algorithm can use storage units inside the data to keep its computed data between different
runs of the algorithm or between runs of different algorithms.
The algorithm itself contains only its parameters. 

Parameters of an algorithm may contain its child algorithms which used by it. Therefore, 
the algoirthm tree is formed, in which the root is the algorithm called to solver the model 
(root algorithm should be an optimization algorithm, see below). 

Algorithms are divided into two types : "manager algorithms" and "worker algorithms". 
Worker algorithms just continue the calculation. They do not store and restore units 
as they suppose it is done by their master algorithms. Manager algorithms may divide 
the calculation flow into parts. Therefore, they store and restore units to make sure 
that their child worker algorithms have units prepared. 
A worker algorithm cannot have child manager algorithms. 

Examples of manager algorithms : TreeSearchAlgorithm (which covers both BCP algorithm and 
diving algorithm), conquer algorithms, strong branching, branching rule algorithms 
(which create child nodes). Examples of worker algorithms : column generation, SolveIpForm, 
SolveLpForm, cut separation, pricing algorithms, etc.
"""

struct EmptyInput <: AbstractInput end


ismanager(algo::AbstractAlgorithm) = false

"""
    get_child_algorithms(::AbstractAlgorithm, ::AbstractModel)::Vector{Tuple{AbstractAlgorithm, AbstractModel}}

Every algorithm should communicate its child algorithms and the model to which 
each child algorithm is applied. 
"""
get_child_algorithms(::AbstractAlgorithm, ::AbstractModel) = Tuple{AbstractAlgorithm, AbstractModel}[]

"""
    get_units_usage(algo::AbstractAlgorithm, model::AbstractModel)::Vector{Tuple{AbstractModel, UnitType, UnitPermission}}

Every algorithm should communicate the storage units it uses (so that these units 
are created in the beginning) and the usage mode (read only or read-and-write). Usage mode is needed for 
in order to restore units before running a worker algorithm.
"""
get_units_usage(algo::AbstractAlgorithm, model::AbstractModel) = Tuple{AbstractModel, UnitType, UnitPermission}[] 

"""
    OptimizationInput

    Contains OptimizationState
"""
struct OptimizationInput{F,S} <: AbstractInput
    optstate::OptimizationState{F,S}
end

getoptstate(input::OptimizationInput) =  input.optstate

"""
    OptimizationOutput

    Contain OptimizationState, PrimalSolution (solution to relaxation), and 
    DualBound (dual bound value)
"""
struct OptimizationOutput{F,S} <: AbstractOutput
    optstate::OptimizationState{F,S}    
end

getoptstate(output::OptimizationOutput)::OptimizationState = output.optstate

"""
    AbstractOptimizationAlgorithm

    This type of algorithm is used to "bound" a model, i.e. to improve primal
    and dual bounds of the model. Solving to optimality is a special case of "bounding".
    The input of such algorithm should be of type Incumbents.    
    The output of such algorithm should be of type OptimizationState.    
"""
abstract type AbstractOptimizationAlgorithm <: AbstractAlgorithm end

exploits_primal_solutions(algo::AbstractOptimizationAlgorithm) = false

# this function collects storage units to restore for an algorithm and all its child worker algorithms,
# child manager algorithms are skipped, as their restore units themselves
function collect_units_to_restore!(
    global_units_usage::UnitsUsage, algo::AbstractAlgorithm, model::AbstractModel
)
    local_units_usage = get_units_usage(algo, model)
    for (unit_model, unit_type, unit_usage) in local_units_usage
        storage = getstoragewrapper(unit_model, unit_type)
        set_permission!(global_units_usage, storage, unit_usage)
    end

    child_algos = get_child_algorithms(algo, model)
    for (childalgo, childmodel) in child_algos
        !ismanager(childalgo) && collect_units_to_restore!(global_units_usage, childalgo, childmodel)
    end
end

# this function collects units to create for an algorithm and all its child algorithms
# this function is used only the function initialize_storage_units! below
function collect_units_to_create!(
    units_to_create::Dict{AbstractModel,Set{UnitType}}, algo::AbstractAlgorithm, model::AbstractModel
)
    units_usage = get_units_usage(algo, model)
    for (unit_model, unit_pair, unit_usage) in units_usage
        if !haskey(units_to_create, unit_model)
            units_to_create[unit_model] = Set{UnitType}()
        end
        push!(units_to_create[unit_model], unit_pair)
    end

    child_algos = get_child_algorithms(algo, model)
    for (childalgo, childmodel) in child_algos
        collect_units_to_create!(units_to_create, childalgo, childmodel)
    end
end

# this function initializes all the storage units
function initialize_storage_units!(reform::Reformulation, algo::AbstractOptimizationAlgorithm)
    units_to_create = Dict{AbstractModel,Set{UnitType}}()
    collect_units_to_create!(units_to_create, algo, reform) 

    for (model, types_of_storage_unit) in units_to_create        
        ModelType = typeof(model)
        storagedict = model.storage.units
        if storagedict === nothing
            error(string("Model of type $(typeof(model)) with id $(getuid(model)) ",
                         "is not contained in $(getnicename(data))")                        
            )
        end

        for storage_unit_type in types_of_storage_unit
            storagedict[storage_unit_type] = StorageUnitWrapper{
                ModelType, storage_unit_type, record_type(storage_unit_type)
            }(model)
        end
    end
end

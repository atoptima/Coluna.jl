"""
    About algorithms
    ----------------

    An algorithm is a procedure with a known interface (input and output) applied to a data.
    An algorithm can use storages inside the data to keep its computed data between different
    runs of the algorithm or between runs of different algorithms.
    The algorithm itself contains only its parameters. 

    Parameters of an algorithm may contain its slave algorithms which used by it. Therefore, 
    the algoirthm tree is formed, in which the root is the algorithm called to solver the model 
    (root algorithm should be an optimization algorithm, see below). 

    Algorithms are divided into two types : "manager algorithms" and "worker algorithms". 
    Worker algorithms just continue the calculation. They do not store and restore storages 
    as they suppose it is done by their master algorithms (the only exception is when they have 
    slave manager algorithms, see below). Manager algorithms may divide the calculation
    flow into parts. Therefore, they store and restore storages to make sure that their 
    slave worker algorithms have storages prepared.

    Examples of manager algorithms : TreeSearchAlgorithm (which covers both BCP algorithm and 
    diving algorithm), strong branching, branching rule algorithms (which create child nodes). 
    Examples of worker algorithm : conquer algorithms, column generation, SolveIpForm, 
    SolveLpForm, cut separation, pricing algorithms, etc.

    If an algorithm A has a slave manager algorithm M, A should store the current storage states 
    before calling M and restore storages used by A after calling M. This is not needed if A does 
    not use any storages after calling M. In this case, if A is a worker algorithm, it should 
    receive in input the information about the storages it uses in order to i) restore only used storages, 
    ii) not to recalculate each time which storages are used. An example here is a conquer algorithm A 
    which uses diving algorithm M.

"""

"""
    AbstractInput

Input of an algorithm.     
"""
abstract type AbstractInput end 

struct EmptyInput <: AbstractInput end

"""
    AbstractOutput

Output of an algorithm.     
"""
abstract type AbstractOutput end 

"""
    AbstractAlgorithm

"""
abstract type AbstractAlgorithm end

ismanager(algo::AbstractAlgorithm) = false

# """
#     get_storages_usage(::AbstractAlgorithm, ::AbstractModel)

#     Every algorithm should communicate all storages it and its slave algorithms use.
    
#     Function add_storage!(::StoragesUsageDict, ::AbstractModel, ::StorageTypePair)
#     should be used to add elements to the dictionary
# """
# get_storages_usage!(algo::AbstractAlgorithm, model::AbstractModel, storages_usage::StoragesUsageDict) = nothing

"""
    get_slave_algorithms(::AbstractAlgorithm, ::AbstractModel)::Vector{Tuple{AbstractAlgorithm, AbstractModel}}

    Every algorithm should communicate its slave algorithms and the model to which 
    each slave algorithm is applied. 
    
    Function add_storage!(::StoragesUsageDict, ::AbstractModel, ::StorageTypePair)
    should be used to add elements to the dictionary
"""
get_slave_algorithms(::AbstractAlgorithm, ::AbstractModel) = Tuple{AbstractAlgorithm, AbstractModel}[]

"""
    get_storages_usage(algo::AbstractAlgorithm, model::AbstractModel)::Vector{Tuple{AbstractModel, StorageTypePair, StorageAccessMode}}

    Every algorithm should communicate the storages it uses (so that these storages 
    are created in the beginning) and the usage mode (read only or read-and-write). Usage mode is needed for 
    in order to restore storages before running a worker algorithm.
    
    Function add_storage!(::StoragesToRestoreDict, ::AbstractModel, ::StorageTypePair, ::StorageAccessMode)
    should be used to add elements to the dictionary
"""
get_storages_usage(algo::AbstractAlgorithm, model::AbstractModel) = Tuple{AbstractModel, StorageTypePair, StorageAccessMode}[] 

"""
    run!(algo::AbstractAlgorithm, model::AbstractData, input::AbstractInput)::AbstractOutput

    Runs the algorithm. The storage of the algorithm can be obtained from the data
    Returns algorithm's output.    
"""
function run!(algo::AbstractAlgorithm, data::AbstractData, input::AbstractInput)::AbstractOutput
    error("run! not defined for algorithm $(typeof(algo)), data $(typeof(data)), and input $(typeof(input)).")
end

"""
    OptimizationInput

    Contains OptimizationResult
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

# this function collects storages to restore for an algorithm and all its slave worker algorithms,
# slave manager algorithms are skipped, as their restore storages themselves
function collect_storages_to_restore!(
    global_storages_usage::StoragesUsageDict, algo::AbstractAlgorithm, model::AbstractModel
)
    ismanager(algo) && return

    local_storages_usage = get_storages_usage(algo, model)
    for (stor_model, stor_pair, stor_usage) in local_storages_usage
        add_storage_pair_usage!(global_storages_usage, stor_model, stor_pair, stor_usage)
    end

    slave_algos = get_slave_algorithms(algo, model)
    for (slavealgo, slavemodel) in slave_algos
        !ismanager(slavealgo) && collect_storages_usage!(global_storages_usage, slavealgo, slavemodel)
    end
end

# this function collects storages usage for an algorithm and all its slave algorithms
# this function is used only the function initialize_storages() below
function collect_storages_usage!(
    global_storages_usage::StoragesUsageDict, algo::AbstractAlgorithm, model::AbstractModel
)
    local_storages_usage = get_storages_usage(algo, model)
    for (stor_model, stor_pair, stor_usage) in local_storages_usage
        add_storage_pair_usage!(global_storages_usage, stor_model, stor_pair, stor_usage)
    end

    slave_algos = get_slave_algorithms(algo, model)
    for (slavealgo, slavemodel) in slave_algos
        collect_storages_usage!(global_storages_usage, slavealgo, slavemodel)
    end
end

# this function initializes all the storages
function initialize_storages(data::AbstractData, algo::AbstractOptimizationAlgorithm)
    storages_usage = StoragesUsageDict()
    datamodel = getmodel(data)
    collect_storages_usage!(storages_usage, algo, datamodel) 

    for (model, type_pair_set) in storages_usage
        ModelType = typeof(model)
        storagedict = get_model_storage_dict(data, model)
        if storagedict === nothing
            error(string("Model of type $(typeof(model)) with id $(getuid(model)) ",
                         "is not contained in $(getnicename(data))")                        
            )
        end   
        for type_pair in type_pair_set
            (StorageType, StorageStateType) = type_pair
            storagedict[type_pair] = 
                StorageContainer{ModelType, StorageType, StorageStateType}(model)
        end
    end
end

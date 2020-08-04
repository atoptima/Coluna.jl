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

    An algorithm is a procedure with a known interface (input and output) applied to a data.
    An algorithm can use storages inside the data to keep its computed data.
    The algorithm itself contains only its parameters. 
"""
abstract type AbstractAlgorithm end

"""
    run!(algo::AbstractAlgorithm, model::AbstractModel, input::AbstractInput)::AbstractOutput

    Runs the algorithm. The storage of the algorithm can be obtained by asking
    the formulation. Returns algorithm's output.    
"""
function run!(algo::AbstractAlgorithm, data::AbstractData, input::AbstractInput)::AbstractOutput
    error("run! not defined for algorithm $(typeof(algo)), data $(typeof(data)), and input $(typeof(input)).")
end

"""
    get_storages_usage(::AbstractAlgorithm, ::AbstractModel)

    Every algorithm should communicate all storages it and its slave algorithms use.
    
    Function add_storage!(::StoragesUsageDict, ::AbstractModel, ::StorageTypePair)
    should be used to add elements to the dictionary
"""
get_storages_usage!(algo::AbstractAlgorithm, model::AbstractModel, storages_usage::StoragesUsageDict) = nothing

"""
    get_storages_to_restore(algo::AbstractAlgorithm, model::AbstractModel)

    Every algorithm should also communicate which storages should be restored before running the algorithm, 
    and also the access mode for each such storage (read only or read-and-write)
    
    Function add_storage!(::StoragesToRestoreDict, ::AbstractModel, ::StorageTypePair, ::StorageAccessMode)
    should be used to add elements to the dictionary
"""
get_storages_to_restore!(algo::AbstractAlgorithm, model::AbstractModel, storages_to_restore::StoragesToRestoreDict) = nothing

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

    This type of algorithm is used to "bound" a formulation, i.e. to improve primal
    and dual bounds of the formulation. Solving to optimality is a special case of "bounding".
    The input of such algorithm should be of type Incumbents.    
    The output of such algorithm should be of type OptimizationState.    
"""
abstract type AbstractOptimizationAlgorithm <: AbstractAlgorithm end

exploits_primal_solutions(algo::AbstractOptimizationAlgorithm) = false

# this function initializes all the storages
function initialize_storages(data::AbstractData, algo::AbstractOptimizationAlgorithm)
    storages_usage = StoragesUsageDict()
    datamodel = getmodel(data)
    get_storages_usage!(algo, datamodel, storages_usage) 

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

# Interface to get benchmarks from algorithms (or only the top algorithm) (TODO)
# abstract type AbstractBenchmark end

# struct NodeCount <: AbstractBenchmark end

# function get_benchmark_from_algo(::A, ::B) where {A <: AbstractAlgorithm, B <: AbstractBenchmark}
#     return error("Algorithm $A cannot return benchmark $B.")
# end
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
"""

get_storages_usage!(algo::AbstractAlgorithm, model::AbstractModel, storages_usage::StoragesUsageDict) = nothing

"""
    get_storages_to_restore(algo::AbstractAlgorithm, model::AbstractModel)

    Every algorithm should also communicate which storages should be restored before running the algorithm, 
    and also the access mode for each such storage (read only or read-and-write)
    
    Function add!(::StoragesToRestoreDict, ::AbstractModel, ::FullStorageType, ::StorageAccessMode)
    should be used to add elements to the dictionary

"""

get_storages_to_restore!(algo::AbstractAlgorithm, model::AbstractModel, storages_to_restore::StoragesToRestoreDict) = nothing


# """
#     get_storages_vector(algo::AbstractAlgorithm, model::AbstractModel)::Vector{Tuple{StorageType, StorageAccessMode}}

#     Every algorithm should communicate all storage types it uses and the access mode (read-write, ready only)
# """
# get_storages_vector(algo::AbstractAlgorithm, model::AbstractModel) = Vector{StorageUsageTuple}()

# """
#     getstorage!(Algorithm, Formulation, Vector{Tuple{Formulation, AlgorithmType})

#     Every algorithm should communicate its slave algorithms together with models
#     to which they are applied    
# """
# getslavealgorithms!(
#     algo::AbstractAlgorithm, model::AbstractModel, 
#     slaves::Vector{Tuple{AbstractModel, AbstractAlgorithm}}) = nothing

# function get_all_storages_dict(algo::AbstractAlgorithm, model::AbstractModel, storages::StoragesUsageDict, skiptreesearchslaves::Bool) 
#     slaves = Vector{Tuple{AbstractModel, AbstractAlgorithm}}()
#     push!(slaves, (model, algo))
#     getslavealgorithms!(algo, model, slaves)

#     for (sl_model, sl_algo) in slaves
#         if skiptreesearchslaves && ( typeof(sl_algo) <: AbstractConquerAlgorithm || typeof(sl_algo) <: AbstractDivideAlgorithm)
#             continue
#         end
#         algo_storages::Vector{StorageUsageTuple} = get_storages_vector(sl_model, sl_algo)
#         for (stor_model, StorageType, accessmode) in algo_storages
#             if !haskey(storages, (stor_model, StorageType))
#                 storages[(stor_model, StorageType)] = accessmode
#             else
#                 if accessmode == READ_AND_WRITE && storages[(stor_model, StorageType)] == READ_ONLY
#                     storages[(stor_model, StorageType)] = READ_AND_WRITE
#                 end    
#             end
#         end  
#     end    
# end

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
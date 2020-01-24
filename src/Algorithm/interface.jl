using ..Coluna # to remove when merging to the master branch


"""
    AbstractAlgorithm

    An algorithm is a procedure with a known interface (input and output) applied on a formulation.
    Input of an algorithm is put to its storage before running it.
    The algorithm itself contains only its parameters. 
    Other data used by the algorithm is contained in its storage. 
    The same storage can be used by different algorithms 
    or different copies of the same algorithm (same algorithm with different parameters).
"""
abstract type AbstractAlgorithm end

"""
    construct(Algorithm)::Storage

    Every algorithm should know how to initialize its storage.
    Initialization happens when the formulation, on which the algoirithm is applied, is known.
    By default, the storage is empty.    
"""
function construct(algo::AbstractAlgorithm, form::AbstractFormulation)::AbstractStorage
    return EmptyStorage()
end

"""
    run!(Algorithm, Storage)::Output

    Runs the algorithm using its storage. Returns algorithm's output.    
"""
function run!(algo::AbstractAlgorithm, storage::AbstractStorage)::AbstractOutput
    return EmptyOutput()
end


# """
#     AbstractOptimizationOutput

#     Should be able to communicate OptimizationResult.
# """
# abstract type AbstractOptimizationOutput end

# getoptimizationresult(output::AbstractOptimizationOutput)::OptimizationResult = nothing


"""
    AbstractOptimizationAlgorithm

    This type of algorithm is used to "bound" a formulation, i.e. to improve primal
    and dual bounds of the formulation. Solving to optimality is a special case of "bounding".
    The storage of such algorithm should contain AbstractFormulation.
    The output of such algorithm should be of type AbstractReformulationAlgorithmOutput.    
"""
abstract type AbstractOptimizationAlgorithm <: AbstractAlgorithm end




# abstract type AbstractNode end

# """
#     AbstractStrategy

# A strategy is a type used to define Coluna's behaviour in its algorithmic parts.
# """
# abstract type AbstractStrategy end

# # Temporary abstract (to be deleted)
# abstract type AbstractGlobalStrategy <: AbstractStrategy end
# struct EmptyGlobalStrategy <: AbstractGlobalStrategy end

# """
#     AbstractAlgorithmResult

# Stores the computational results after the end of an algorithm execution.
# These data can be used to initialize another execution of the same algorithm or in 
# setting the transition to another algorithm.
# """
# # TO DO : replace by AbstractAlgorithm Output
# abstract type AbstractAlgorithmResult end

# """
#     prepare!(Algorithm, formulation, node)

# Prepares the `formulation` in the `node` to be optimized by algorithm `Algorithm`.
# """
# function prepare! end

# """
#     run!(Algorithm, formulation, node)

# Runs the algorithm `Algorithm` on the `formulation` in a `node`.
# """
# function run! end

# # Fallbacks
# function prepare!(algo::AbstractAlgorithm, formulation, node)
#     algotype = typeof(algo)
#     error("prepare! method not implemented for algorithm $(algotype).")
# end

# function run!(algo::AbstractAlgorithm, formulation, node)
#     algotype = typeof(algo)
#     error("run! method not implemented for algorithm $(algotype).")
# end

# """
#     apply!(Algorithm, formulation, node)

# Applies the algorithm `Algorithm` on the `formulation` in a `node` with 
# `parameters`.
# """
# function apply!(algo::AbstractAlgorithm, form, node)
#     prepare!(form, node)
#     TO.@timeit Coluna._to string(algo) begin
#         TO.@timeit Coluna._to "prepare" begin
#             prepare!(algo, form, node)
#         end
#         TO.@timeit Coluna._to "run" begin
#             record = run!(algo, form, node)
#         end
#     end
#     set_algorithm_result!(node, algo, record)
#     return record
# end
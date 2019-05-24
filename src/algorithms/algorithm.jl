"""
    AbstractAlgorithmRecord

Stores data after the end of an algorithm execution.
These data can be used to initialize another execution of the same algorithm or in 
setting the transition to another algorithm.
"""
abstract type AbstractAlgorithmRecord end
abstract type AbstractAlgorithmData end

"""
    prepare!(AlgorithmType, formulation, node, strategy_record, parameters)

Prepares the `formulation` in the `node` to be optimized by algorithm `AlgorithmType`.
"""
function prepare! end

"""
run!(AlgorithmType, formulation, node, strategy_record, parameters)

Runs the algorithm `AlgorithmType` on the `formulation` in a `node` with `parameters`.
"""
function run! end

# Fallbacks
function prepare!(T::Type{<:AbstractAlgorithm}, formulation, node, strategy_rec, parameters)
    error("prepare! method not implemented for algorithm $T.")
end

function run!(T::Type{<:AbstractAlgorithm}, formulation, node, strategy_rec, parameters)
    error("run! method not implemented for algorithm $T.")
end

"""
    apply!(AlgorithmType, formulation, node, strategy_record, parameters)

Applies the algorithm `AlgorithmType` on the `formulation` in a `node` with 
`parameters`.
"""
function apply!(S::Type{<:AbstractAlgorithm}, form, node, strategy_rec,
                params)
    prepare!(form, node)
    setalgorithm!(strategy_rec, S)
    TO.@timeit _to string(S) begin
        TO.@timeit _to "prepare" begin
            prepare!(S, form, node, strategy_rec, params)
        end
        TO.@timeit _to "run" begin
            record = run!(S, form, node, strategy_rec, params)
        end
    end
    set_algorithm_record!(node, S, record)
    return record
end

"""
    StartNode

Fake algorithm that indicates the start of the node treatment.
"""
struct StartNode <: AbstractAlgorithm end

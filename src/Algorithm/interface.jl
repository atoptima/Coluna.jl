abstract type AbstractNode end

"""
    AbstractStrategy

A strategy is a type used to define Coluna's behaviour in its algorithmic parts.
"""
abstract type AbstractStrategy end
"""
    AbstractAlgorithm

An algorithm is a 'text-book' algorithm applied to a formulation in a node.
"""
abstract type AbstractAlgorithm end

# Temporary abstract (to be deleted)
abstract type AbstractGlobalStrategy <: AbstractStrategy end
struct EmptyGlobalStrategy <: AbstractGlobalStrategy end

"""
    AbstractAlgorithmResult

Stores the computational results after the end of an algorithm execution.
These data can be used to initialize another execution of the same algorithm or in 
setting the transition to another algorithm.
"""
abstract type AbstractAlgorithmResult end

"""
    prepare!(Algorithm, formulation, node)

Prepares the `formulation` in the `node` to be optimized by algorithm `Algorithm`.
"""
function prepare! end

"""
    run!(Algorithm, formulation, node)

Runs the algorithm `Algorithm` on the `formulation` in a `node`.
"""
function run! end

# Fallbacks
function prepare!(algo::AbstractAlgorithm, formulation, node)
    algotype = typeof(algo)
    error("prepare! method not implemented for algorithm $(algotype).")
end

function run!(algo::AbstractAlgorithm, formulation, node)
    algotype = typeof(algo)
    error("run! method not implemented for algorithm $(algotype).")
end

"""
    apply!(Algorithm, formulation, node)

Applies the algorithm `Algorithm` on the `formulation` in a `node` with 
`parameters`.
"""
function apply!(algo::AbstractAlgorithm, form, node)
    prepare!(form, node)
    TO.@timeit Coluna._to string(algo) begin
        TO.@timeit Coluna._to "prepare" begin
            prepare!(algo, form, node)
        end
        TO.@timeit Coluna._to "run" begin
            record = run!(algo, form, node)
        end
    end
    set_algorithm_result!(node, algo, record)
    return record
end
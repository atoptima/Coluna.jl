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
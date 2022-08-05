"""
Input of a divide algorithm used by the tree search algorithm.
Contains the parent node in the search tree for which children should be generated.
"""
struct DivideInput <: AbstractInput
    parent::Node
    optstate::OptimizationState
end

getparent(input::DivideInput) = input.parent
getoptstate(input::DivideInput) = input.optstate

"""
Output of a divide algorithm used by the tree search algorithm.
Should contain the vector of generated nodes.
"""
struct DivideOutput <: AbstractOutput 
    children::Vector{SbNode}
    optstate::OptimizationState
end

getchildren(output::DivideOutput) = output.children
getoptstate(output::DivideOutput) = output.optstate

"""
This algorithm type is used by the tree search algorithm to generate nodes.
"""
abstract type AbstractDivideAlgorithm <: AbstractAlgorithm end

# divide algorithms are always manager algorithms (they manage storing and restoring units)
ismanager(algo::AbstractDivideAlgorithm) = true

run!(algo::AbstractDivideAlgorithm, ::Env, model::AbstractModel, input::DivideInput) = 
    error("Method run! in not defined for divide algorithm $(typeof(algo)), model $(typeof(model)), and input $(typeof(input)).") 

# this function is needed to check whether the best primal solution should be copied to the node optimization state
exploits_primal_solutions(algo::AbstractDivideAlgorithm) = false

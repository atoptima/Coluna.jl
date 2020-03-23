abstract type AbstractModel end
abstract type AbstractProblem end

abstract type AbstractSense end
abstract type AbstractMinSense <: AbstractSense end
abstract type AbstractMaxSense <: AbstractSense end

abstract type AbstractSpace end
abstract type AbstractPrimalSpace <: AbstractSpace end
abstract type AbstractDualSpace <: AbstractSpace end

"""
    AbstractInput

Input of an algorithm.     
"""
abstract type AbstractInput end 

"""
    AbstractOutput

Output of an algorithm.     
"""
abstract type AbstractOutput end 

"""
    AbstractAlgorithm

An algorithm is a procedure with a known interface (input and output) applied to a formulation.
An algorithm can use an additional storage to keep its computed data.
Input of an algorithm is put to its storage before running it.
The algorithm itself contains only its parameters. 
Other data used by the algorithm is contained in its storage. 
The same storage can be used by different algorithms 
or different copies of the same algorithm (same algorithm with different parameters).
"""
abstract type AbstractAlgorithm end

"""
    run!(algo::AbstractAlgorithm, model::AbstractModel, input::AbstractInput)::AbstractOutput

Runs the algorithm. The storage of the algorithm can be obtained by asking
the formulation. Returns algorithm's output.    
"""
function run!(algo::AbstractAlgorithm, model::AbstractModel, input::AbstractInput)::AbstractOutput
    error("run! not defined for algorithm $(typeof(algo)), model $(typeof(model)), and input $(typeof(input)).")
end
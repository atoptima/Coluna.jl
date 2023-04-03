############################################################################################
# Algorithm API
############################################################################################
module APITMP 

include("MustImplement/MustImplement.jl")
using .MustImplement

include("ColunaBase/ColunaBase.jl")
using .ColunaBase

"Supertype for algorithms parameters."
abstract type AbstractAlgorithm end

"""
    run!(algo::AbstractAlgorithm, env, model, input)
Runs an algorithm. 
"""
@mustimplement "Algorithm" run!(algo::AbstractAlgorithm, env, model, input) = nothing


"""
Contains the definition of the problem tackled by the tree search algorithm and how the
nodes and transitions of the tree search space will be explored.
"""
abstract type AbstractSearchSpace end

"Algorithm that chooses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end


############################################################################################
# Divide Algorithm API
############################################################################################

"""
Input of a divide algorithm used by the tree search algorithm.
Contains the parent node in the search tree for which children should be generated.
"""
abstract type AbstractDivideInput end

@mustimplement "DivideInput" get_parent(i::AbstractDivideInput) = nothing
@mustimplement "DivideInput" get_opt_state(i::AbstractDivideInput) = nothing

"""
Output of a divide algorithm used by the tree search algorithm.
Should contain the vector of generated nodes.
"""
abstract type AbstractDivideOutput end

@mustimplement "DivideOutput" get_children(output::AbstractDivideOutput) = nothing
@mustimplement "DivideOutput" get_opt_state(output::AbstractDivideOutput) = nothing


"""
This algorithm type is used by the tree search algorithm to generate nodes.
"""
abstract type AbstractDivideAlgorithm <: AbstractAlgorithm end

# divide algorithms are always manager algorithms (they manage storing and restoring units)
ismanager(algo::AbstractDivideAlgorithm) = true

@mustimplement "DivideAlgorithm" run!(::AbstractDivideAlgorithm, env, model, ::AbstractDivideInput)  = nothing



export AbstractAlgorithm, AbstractSearchSpace, AbstractExploreStrategy, AbstractNode

end


############################################################################################
# Algorithm API
############################################################################################
module AlgoAPI

include("MustImplement/MustImplement.jl")
using .MustImplement

include("ColunaBase/ColunaBase.jl")
using .ColunaBase

"
Supertype for algorithms parameters.
Data structures that inherit from this type are intented for the users.
The convention is to define the data structure together with a constructor that contains
only kw args.

For instance:
    
        struct MyAlgorithmParams <: AbstractAlgorithmParams
            param1::Int
            param2::Int
            MyAlgorithmParams(; param1::Int = 1, param2::Int = 2) = new(param1, param2)
        end
"
abstract type AbstractAlgorithm end

"""
    run!(algo::AbstractAlgorithm, env, model, input)

Default method to call an algorithm.
"""
@mustimplement "Algorithm" run!(algo::AbstractAlgorithm, env, model, input) = nothing

@mustimplement "Algorithm" ismanager(algo::AbstractAlgorithm) = false

"""
Returns `true` if the algorithm will perform changes on the formulation that must be 
reverted at the end of the execution of the algorithm; `false` otherwise.
"""
@mustimplement "Algorithm" change_model_state(algo::AbstractAlgorithm) = false

############################################################################################
# Divide Algorithm API
############################################################################################

"""
This algorithm type is used by the tree search algorithm to generate nodes.
"""
abstract type AbstractDivideAlgorithm <: AbstractAlgorithm end

# divide algorithms are always manager algorithms (they manage storing and restoring units)
ismanager(algo::AbstractDivideAlgorithm) = true

#####
# Default tolerances
###
default_opt_atol() = 1e-6
default_opt_rtol() = 1e-5

end


module Heuristic

!true && include("../MustImplement/MustImplement.jl") # linter
using ..MustImplement

!true && include("../interface.jl") # linter
using ..AlgoAPI

"Supertype for heuristic."
abstract type AbstractHeuristic <: AlgoAPI.AbstractAlgorithm end

"""
Output of a heuristic algorithm.
"""
abstract type AbstractHeuristicOutput end

"Returns a collection of primal solutions found by the heuristic."
@mustimplement "HeuristicOutput" get_primal_sols(::AbstractHeuristicOutput) = nothing

"""
run the heuristic using following arguments:
- `form`: a formulation (or any representation) of the problem
- `cur_inc_primal_sol`: current incumbent primal solution

and returns an `AbstractHeuristicOutput` object.
"""
@mustimplement "Heuristic" run(::AbstractHeuristic, env, form, cur_inc_primal_sol) = nothing

end
module Branching

using ..MustImplement

include("candidate.jl")
include("rule.jl")
include("selection.jl")
include("score.jl")

############################################################################################
# Branching API
############################################################################################

"Supertype for divide algorithm contexts."
abstract type AbstractDivideContext end

"Returns the number of candidates that the candidates selection step must return."
@mustimplement "Branching" get_selection_nb_candidates(::AbstractDivideAlgorithm)

"Returns the type of context required by the algorithm parameters."
@mustimplement "Branching" branching_context_type(::AbstractDivideAlgorithm)

"Creates a context."
@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::AbstractDivideAlgorithm, reform)

"Advanced candidates selection that selects candidates by evaluating their children."
@mustimplement "Branching" advanced_select!(::AbstractDivideContext, candidates, env, reform, input::AbstractDivideInput)

"Returns integer tolerance."
@mustimplement "Branching" get_int_tol(::AbstractDivideContext)

"Returns branching rules."
@mustimplement "Branching" get_rules(::AbstractDivideContext)

"Returns the selection criterion."
@mustimplement "Branching" get_selection_criterion(::AbstractDivideContext)

end
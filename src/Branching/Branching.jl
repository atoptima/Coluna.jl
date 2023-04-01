module Branching

!true && include("../MustImplement/MustImplement.jl") # linter
using ..MustImplement

!true && include("../interface.jl") # linter
using ..APITMP

include("candidate.jl")
include("criteria.jl")
include("rule.jl")
include("score.jl")

############################################################################################
# Branching API
############################################################################################

"Supertype for divide algorithm contexts."
abstract type AbstractDivideContext end

"Returns the number of candidates that the candidates selection step must return."
@mustimplement "Branching" get_selection_nb_candidates(::APITMP.AbstractDivideAlgorithm) = nothing

"Returns the type of context required by the algorithm parameters."
@mustimplement "Branching" branching_context_type(::APITMP.AbstractDivideAlgorithm) = nothing

"Creates a context."
@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::APITMP.AbstractDivideAlgorithm, reform) = nothing

# TODO: can have a default implemntation when strong branching will be generic.
"Advanced candidates selection that selects candidates by evaluating their children."
@mustimplement "Branching" advanced_select!(::AbstractDivideContext, candidates, env, reform, input::APITMP.AbstractDivideInput) = nothing

"Returns integer tolerance."
@mustimplement "Branching" get_int_tol(::AbstractDivideContext) = nothing

"Returns branching rules."
@mustimplement "Branching" get_rules(::AbstractDivideContext) = nothing

"Returns the selection criterion."
@mustimplement "Branching" get_selection_criterion(::AbstractDivideContext) = nothing

# Default implementations.
"Candidates selection for branching algorithms."
function select!(rule::AbstractBranchingRule, env, reform, input::Branching.BranchingRuleInput)
    candidates = apply_branching_rule(rule, env, reform, input)
    local_id = input.local_id + length(candidates)
    select_candidates!(candidates, input.criterion, input.max_nb_candidates)

    for candidate in candidates
        children = generate_children!(candidate, env, reform, input.parent)
        set_children!(candidate, children)
    end
    return BranchingRuleOutput(local_id, candidates)
end

############################################################################################
# Strong branching API
############################################################################################

# Implementation
"Supertype for the branching contexts."
abstract type AbstractStrongBrContext <: AbstractDivideContext end

"Supertype for the branching phase contexts."
abstract type AbstractStrongBrPhaseContext end

"Creates a context for the branching phase."
@mustimplement "StrongBranching" new_phase_context(::Type{<:AbstractDivideContext}, phase, reform, phase_index) = nothing

"""
Returns the storage units that must be restored by the conquer algorithm called by the
strong branching phase.
"""
@mustimplement "StrongBranching" get_units_to_restore_for_conquer(::AbstractStrongBrPhaseContext) = nothing

"Returns all phases context of the strong branching algorithm."
@mustimplement "StrongBranching" get_phases(::AbstractStrongBrContext) = nothing

"Returns the type of score used to rank the candidates at a given strong branching phase."
@mustimplement "StrongBranching" get_score(::AbstractStrongBrPhaseContext) = nothing

"Returns the conquer algorithm used to evaluate the candidate's children at a given strong branching phase."
@mustimplement "StrongBranching" get_conquer(::AbstractStrongBrPhaseContext) = nothing

"Returns the maximum number of candidates kept at the end of a given strong branching phase."
@mustimplement "StrongBranching" get_max_nb_candidates(::AbstractStrongBrPhaseContext) = nothing

# TODO: we can make the perform strong branching method generic by just removing the explicit
# use of the OptimizationState from its current implementation.
# When we do this, we'll have to write good unit tests to make the sure the generic implemntation is correct.
# Current almost generic implementation is in: _perform_strong_branching!
# perform_strong_branching!(ctx, env, reform, input, candidates) -> OptimizationState

# TODO: make the default implementation generic.
"Performs a branching phase."
@mustimplement "StrongBranching" perform_branching_phase!(candidates, phase, sb_state, env, reform) = nothing

"Evaluates a candidate."
function eval_children_of_candidate!(children, phase::AbstractStrongBrPhaseContext, sb_state, env, reform)
    for child in children
        eval_child_of_candidate!(child, phase, sb_state, env, reform)
    end
    return
end

"Evaluate children of a candidate."
@mustimplement "StrongBranching" eval_child_of_candidate!(child, phase, sb_state, env, reform) = nothing

end
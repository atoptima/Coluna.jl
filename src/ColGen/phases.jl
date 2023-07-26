"""
A phase of the column generation.
Each phase is associated with a specific set up of the reformulation.
"""
abstract type AbstractColGenPhase end

"""
An iterator that indicates how phases follow each other.
"""
abstract type AbstractColGenPhaseIterator end

"Returns a new phase iterator."
@mustimplement "ColGenPhase" new_phase_iterator(::AbstractColGenContext) = nothing

"Returns the phase with which the column generation algorithm must start." 
@mustimplement "ColGenPhase" initial_phase(::AbstractColGenPhaseIterator) = nothing

"""
Returns the next phase of the column generation algorithm.
Returns `nothing` if the algorithm must stop.
"""
@mustimplement "ColGenPhase" next_phase(::AbstractColGenPhaseIterator, ::AbstractColGenPhase, output) = nothing

"Setup the reformulation for the given phase."
@mustimplement "ColGenPhase" setup_reformulation!(reform, ::AbstractColGenPhase) = nothing

"Setup the context for the given phase."
@mustimplement "ColGenPhase" setup_context!(context, ::AbstractColGenPhase) = nothing

"Returns `true` if the column generation phase must stop."
@mustimplement "ColGenPhase" stop_colgen_phase(context, phase, env, colgen_iter_output, inc_dual_bound, ip_primal_sol, colgen_iteration) = nothing

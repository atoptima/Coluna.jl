"""
A phase of the column generation.
Each phase is associated with a specific set up of the reformulation.
"""
abstract type AbstractColGenPhase end

"""
An iterator that indicates how a set of phases follow each other.
"""
abstract type AbstractColGenPhaseIterator end

"Returns the phase with which the column generation algorithm must start." 
@mustimplement "ColGenPhase" initial_phase(::AbstractColGenContext)

"""
Returns the next phase of the column generation algorithm.
Returns `nothing` if the algorithm must stop.
"""
@mustimplement "ColGenPhase" next_phase(::AbstractColGenContext, ::AbstractColGenPhase, ctx::AbstractColGenContext)

"Setup the reformulation for the given phase."
@mustimplement "ColGenPhase" setup_reformulation!(reform, ::AbstractColGenPhase)

"Returns `true` if the column generation phase must stop."
@mustimplement "ColGenPhase" stop_colgen_phase(ctx, phase, reform)

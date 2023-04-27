"""
A stage of the column generation algorithm.
Each stage is associated to a specific solver for each pricing subproblem.
"""
abstract type AbstractColGenStage end

"An iterator that indicates how a set of stages follow each other."
abstract type AbstractColGenStageIterator end

"Returns a new stage iterator."
@mustimplement "ColGenStage" new_stage_iterator(::AbstractColGenContext) = nothing

"Returns the stage at which the column generation algorithm must start."
@mustimplement "ColGenStage" initial_stage(::AbstractColGenStageIterator) = nothing

@mustimplement "ColGenStage" next_stage(::AbstractColGenStageIterator, stage, phase_output) = nothing

"""
Returns the next stage.
Returns `nothing` if the algorithm has already reached the exact phase (last phase).
"""
@mustimplement "ColGenStage" decrease_stage(::AbstractColGenStageIterator,  ::AbstractColGenStage, output) = nothing

"Setup the context for the given stage."
@mustimplement "ColGenStage" setup_context!(context, ::AbstractColGenStage) = nothing

@mustimplement "ColGenStage" get_pricing_subprob_optimizer(::AbstractColGenStage, form) = nothing

@mustimplement "ColGenStage" stage_id(::AbstractColGenStage) = nothing

@mustimplement "ColGenStage" is_exact_stage(::AbstractColGenStage) = nothing
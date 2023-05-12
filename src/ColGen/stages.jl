"""
A stage of the column generation algorithm.
Each stage is associated to a specific solver for each pricing subproblem.
"""
abstract type AbstractColGenStage end

"An iterator that indicates how stages follow each other."
abstract type AbstractColGenStageIterator end

"Returns a new stage iterator."
@mustimplement "ColGenStage" new_stage_iterator(::AbstractColGenContext) = nothing

"Returns the stage at which the column generation algorithm must start."
@mustimplement "ColGenStage" initial_stage(::AbstractColGenStageIterator) = nothing

"""
Returns the next stage involving a "more exact solver" than the current one.
Returns `nothing` if the algorithm has already reached the exact phase (last phase).
"""
@mustimplement "ColGenStage" decrease_stage(::AbstractColGenStageIterator, stage, phase_output) = nothing

"""
Returns the next stage that column generation must use.
"""
@mustimplement "ColGenStage" next_stage(::AbstractColGenStageIterator, stage, phase_output) = nothing

"Returns the optimizer for the pricing subproblem associated to the given stage."
@mustimplement "ColGenStage" get_pricing_subprob_optimizer(::AbstractColGenStage, form) = nothing

"Returns the id of the stage."
@mustimplement "ColGenStage" stage_id(::AbstractColGenStage) = nothing

"Returns `true` if the stage uses an exact solver for the pricing subproblem; `false` otherwise."
@mustimplement "ColGenStage" is_exact_stage(::AbstractColGenStage) = nothing
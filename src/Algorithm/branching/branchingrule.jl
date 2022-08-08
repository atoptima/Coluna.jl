############################################################################################
# Selection Criteria of branching candidates
############################################################################################

"""
Supertype of selection criteria of branching candidates.

A selection criterion provides a way to keep only the most promising branching
candidates. To create a new selection criterion, one needs to create a subtype of
`AbstractSelectionCriterion` and implements the method `select_candidates!`.
"""
abstract type AbstractSelectionCriterion end

"""
    select_candidates!(branching_candidates, selection_criterion, max_nb_candidates)

Sort branching candidates according to the selection criterion and remove excess ones.
"""
select_candidates!(::Vector{BranchingGroup}, selection::AbstractSelectionCriterion, ::Int) =
    error("select_candidates! not defined for branching selection rule $(typeof(selection)).")

# Criterion 1
"""
Select the branching candidates that have been generated first (sort by `local_id`).
"""
struct FirstFoundCriterion <: AbstractSelectionCriterion end

function select_candidates!(
    candidates::Vector{BranchingGroup}, ::FirstFoundCriterion, max_nb_candidates::Int
)
    sort!(candidates, by = x -> x.local_id)
    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end
    return candidates
end

# Criterion 2
"""
Select the most fractional branching candidates.
"""
struct MostFractionalCriterion <: AbstractSelectionCriterion end

_get_lhs_distance_to_integer(group::BranchingGroup) = 
    min(group.lhs - floor(group.lhs), ceil(group.lhs) - group.lhs)

function select_candidates!(
    candidates::Vector{BranchingGroup}, ::MostFractionalCriterion, max_nb_candidates::Int
)
    sort!(candidates, rev = true, by = x -> _get_lhs_distance_to_integer(x))
    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end
    return candidates
end


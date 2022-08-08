
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


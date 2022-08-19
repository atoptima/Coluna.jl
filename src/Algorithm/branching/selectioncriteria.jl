
# Criterion 1
"""
Select the branching candidates that have been generated first (sort by `local_id`).
"""
struct FirstFoundCriterion <: AbstractSelectionCriterion end

function select_candidates!(
    candidates::Vector{C}, ::FirstFoundCriterion, max_nb_candidates::Int
) where {C <: AbstractBranchingCandidate}
    sort!(candidates, by = c -> get_local_id(c))
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

function select_candidates!(
    candidates::Vector{C}, ::MostFractionalCriterion, max_nb_candidates::Int
) where {C <: AbstractBranchingCandidate}
    sort!(candidates, rev = true, by = c -> dist_to_int(get_lhs(c)))
    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end
    return candidates
end


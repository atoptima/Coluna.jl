
# Criterion 1
"""
Select the branching candidates that have been generated first (sort by `local_id`).
"""
struct FirstFoundCriterion <: Branching.AbstractSelectionCriterion end

function Branching.select_candidates!(
    candidates::Vector{C}, ::FirstFoundCriterion, max_nb_candidates::Int
) where {C <: Branching.AbstractBranchingCandidate}
    sort!(candidates, by = c -> Branching.get_local_id(c))
    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end
    return candidates
end

# Criterion 2
"""
Select the most fractional branching candidates.
"""
struct MostFractionalCriterion <: Branching.AbstractSelectionCriterion end

function Branching.select_candidates!(
    candidates::Vector{C}, ::MostFractionalCriterion, max_nb_candidates::Int
) where {C <: Branching.AbstractBranchingCandidate}
    sort!(candidates, rev = true, by = c -> dist_to_int(Branching.get_lhs(c)))
    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end
    return candidates
end

"""
Select the candidate with the smallest distance to the closest non-zero integer.
"""
struct LeastFractionalCriterion <: Branching.AbstractSelectionCriterion end

function Branching.select_candidates!(
    candidates::Vector{C}, ::LeastFractionalCriterion, max_nb_candidates::Int
) where {C <: Branching.AbstractBranchingCandidate}
    sort!(candidates, by = c -> dist_to_int(Branching.get_lhs(c)))
    filter!(c -> !iszero(round(Branching.get_lhs(c))), candidates)
    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end
    return candidates
end


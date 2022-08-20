function print_bounds_and_score(
    candidate::SingleVarBranchingCandidate, phase_index::Int64, max_description_length::Int64, score
)
    lhs = get_lhs(candidate)
    lengthdiff = max_description_length - length(getdescription(candidate))
    print("SB phase ", phase_index, " branch on ", getdescription(candidate))
    @printf " (lhs=%.4f)" lhs
    print(repeat(" ", lengthdiff), " : [")
    for (node_index, node) in enumerate(get_children(candidate))
        node_index > 1 && print(",")            
        @printf "%10.4f" getvalue(get_lp_primal_bound(get_opt_state(node)))
    end
    @printf "], score = %10.4f\n" score
    return
end

struct BranchingPrinter{StrongBrContext<:Branching.AbstractStrongBrContext} <: Branching.AbstractStrongBrContext
    inner::StrongBrContext
end

Branching.get_rules(ctx::BranchingPrinter) = Branching.get_rules(ctx.inner)
Branching.get_int_tol(ctx::BranchingPrinter) = Branching.get_int_tol(ctx.inner)
Branching.get_selection_criterion(ctx::BranchingPrinter) = Branching.get_selection_criterion(ctx.inner)
Branching.get_selection_nb_candidates(ctx::BranchingPrinter) = Branching.get_selection_nb_candidates(ctx.inner)
Branching.get_phases(ctx::BranchingPrinter) = Branching.get_phases(ctx.inner)

struct PhasePrinter{PhaseContext<:Branching.AbstractStrongBrPhaseContext} <: Branching.AbstractStrongBrPhaseContext
    inner::PhaseContext
    phase_index::Int
end

Branching.get_max_nb_candidates(ctx::PhasePrinter) = Branching.get_max_nb_candidates(ctx.inner)
Branching.get_score(ctx::PhasePrinter) = Branching.get_score(ctx.inner)

function new_context(
    ::Type{BranchingPrinter{StrongBrContext}}, algo::AlgoAPI.AbstractDivideAlgorithm, reform
) where {StrongBrContext<:Branching.AbstractStrongBrContext}
    inner_ctx = new_context(StrongBrContext, algo, reform)
    return BranchingPrinter(inner_ctx)
end

function new_phase_context(
    ::Type{PhasePrinter{PhaseContext}}, phase, reform, phase_index
) where {PhaseContext<:Branching.AbstractStrongBrPhaseContext}
    inner_ctx = new_phase_context(PhaseContext, phase, reform, phase_index)
    return PhasePrinter(inner_ctx, phase_index)
end

function Branching.perform_branching_phase!(candidates, cand_children, phase::PhasePrinter, sb_state, env, reform, input)
    println("**** Strong branching phase ", phase.phase_index, " is started *****");
    scores = Branching.perform_branching_phase_inner!(cand_children, phase, sb_state, env, reform, input)
    for (candidate, children, score) in Iterators.zip(candidates, cand_children, scores)
        @printf "SB phase %i branch on %+10s" phase.phase_index  Branching.getdescription(candidate)
        @printf " (lhs=%.4f) : [" Branching.get_lhs(candidate)
        for (node_index, node) in enumerate(children)
            node_index > 1 && print(",")            
            @printf "%10.4f" getvalue(get_lp_primal_bound(node.conquer_output))
        end
        @printf "], score = %10.4f\n" score
    end
    return scores
end

Branching.eval_child_of_candidate!(node, phase::PhasePrinter, env, reform) =
    Branching.eval_child_of_candidate!(node, phase.inner, env, reform)

Branching.get_units_to_restore_for_conquer(phase::PhasePrinter) =
    Branching.get_units_to_restore_for_conquer(phase.inner)

Branching.get_conquer(phase::PhasePrinter) = Branching.get_conquer(phase.inner)
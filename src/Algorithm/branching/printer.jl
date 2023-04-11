struct BranchingPrinter{StrongBrContext<:Branching.AbstractStrongBrContext} <: Branching.AbstractStrongBrContext
    inner::StrongBrContext
end

Branching.get_rules(ctx::BranchingPrinter) = Branching.get_rules(ctx.inner)
Branching.get_int_tol(ctx::BranchingPrinter) = Branching.get_int_tol(ctx.inner)
Branching.get_selection_criterion(ctx::BranchingPrinter) = Branching.get_selection_criterion(ctx.inner)
Branching.get_selection_nb_candidates(ctx::BranchingPrinter) = Branching.get_selection_nb_candidates(ctx.inner)
Branching.get_phases(ctx::BranchingPrinter) = Branching.get_phases(ctx.inner)
Branching.new_ip_primal_sols_pool(ctx::BranchingPrinter, reform, input) = Branching.new_ip_primal_sols_pool(ctx.inner, reform, input)

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

function Branching.perform_branching_phase!(candidates, phase::PhasePrinter, sb_state, env, reform)
    println("**** Strong branching phase ", phase.phase_index, " is started *****");
    scores = Branching.perform_branching_phase_inner!(candidates, phase, sb_state, env, reform)
    for (candidate, score) in Iterators.zip(candidates, scores)
        @printf "SB phase %i branch on %+10s" phase.phase_index  Branching.getdescription(candidate)
        @printf " (lhs=%.4f) : [" Branching.get_lhs(candidate)
        for (node_index, node) in enumerate(Branching.get_children(candidate))
            node_index > 1 && print(",")            
            @printf "%10.4f" getvalue(get_lp_primal_bound(TreeSearch.get_opt_state(node)))
        end
        @printf "], score = %10.4f\n" score
    end
    return scores
end

function Branching.eval_child_of_candidate!(child, phase::PhasePrinter, sb_state, env, reform)
    _eval_child_of_candidate!(child, phase.inner, sb_state, env, reform)
    @printf "**** SB Phase %i evaluation of candidate %+10s" phase.phase_index get_var_name(child)
    @printf " (branch %+20s), value = %6.2f\n" TreeSearch.get_branch_description(child) getvalue(get_lp_primal_bound(TreeSearch.get_opt_state(child)))
    return
end
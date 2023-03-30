struct BranchingPrinter{StrongBrContext<:AbstractStrongBrContext} <: AbstractStrongBrContext
    inner::StrongBrContext
end

get_rules(ctx::BranchingPrinter) = get_rules(ctx.inner)
get_int_tol(ctx::BranchingPrinter) = get_int_tol(ctx.inner)
get_selection_criterion(ctx::BranchingPrinter) = get_selection_criterion(ctx.inner)
get_selection_nb_candidates(ctx::BranchingPrinter) = get_selection_nb_candidates(ctx.inner)
get_phases(ctx::BranchingPrinter) = get_phases(ctx.inner)

struct PhasePrinter{PhaseContext<:AbstractStrongBrPhaseContext} <: AbstractStrongBrPhaseContext
    inner::PhaseContext
    phase_index::Int
end

get_max_nb_candidates(ctx::PhasePrinter) = get_max_nb_candidates(ctx.inner)
get_score(ctx::PhasePrinter) = get_score(ctx.inner)

function new_context(
    ::Type{BranchingPrinter{StrongBrContext}}, algo::AbstractDivideAlgorithm, reform
) where {StrongBrContext<:AbstractStrongBrContext}
    inner_ctx = new_context(StrongBrContext, algo, reform)
    return BranchingPrinter(inner_ctx)
end

function new_phase_context(
    ::Type{PhasePrinter{PhaseContext}}, phase, reform, phase_index
) where {PhaseContext<:AbstractStrongBrPhaseContext}
    inner_ctx = new_phase_context(PhaseContext, phase, reform, phase_index)
    return PhasePrinter(inner_ctx, phase_index)
end

function perform_branching_phase!(candidates, phase::PhasePrinter, sb_state, env, reform)
    println("**** Strong branching phase ", phase.phase_index, " is started *****");
    scores = _perform_branching_phase!(candidates, phase, sb_state, env, reform)
    for (candidate, score) in Iterators.zip(candidates, scores)
        @printf "SB phase %i branch on %+10s" phase.phase_index  getdescription(candidate)
        @printf " (lhs=%.4f) : [" get_lhs(candidate)
        for (node_index, node) in enumerate(get_children(candidate))
            node_index > 1 && print(",")            
            @printf "%10.4f" getvalue(get_lp_primal_bound(TreeSearch.get_opt_state(node)))
        end
        @printf "], score = %10.4f\n" score
    end
    return scores
end

function eval_child_of_candidate!(child, phase::PhasePrinter, sb_state, env, reform)
    _eval_child_of_candidate!(child, phase.inner, sb_state, env, reform)
    @printf "**** SB Phase %i evaluation of candidate %+10s" phase.phase_index get_var_name(child)
    @printf " (branch %+20s), value = %6.2f\n" get_branch_description(child) getvalue(get_lp_primal_bound(TreeSearch.get_opt_state(child)))
    return
end
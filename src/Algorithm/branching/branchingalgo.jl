

############################################################################################
# AbstractConquerInput implementation for the strong branching.
############################################################################################
"Conquer input object created by the strong branching algorithm."
struct ConquerInputFromSb <: AbstractConquerInput
    children_candidate::SbNode
    children_units_to_restore::UnitsUsage
end

get_node(i::ConquerInputFromSb) = i.children_candidate
get_units_to_restore(i::ConquerInputFromSb) = i.children_units_to_restore
run_conquer(::ConquerInputFromSb) = true

############################################################################################
# NoBranching
############################################################################################

"""
    NoBranching

Divide algorithm that does nothing. It does not generate any child.
"""
struct NoBranching <: APITMP.AbstractDivideAlgorithm end

function run!(::NoBranching, ::Env, reform::Reformulation, ::APITMP.AbstractDivideInput)
    return DivideOutput([], OptimizationState(getmaster(reform)))
end

############################################################################################
# Branching API implementation for the (classic) branching
############################################################################################

"""
    ClassicBranching(
        selection_criterion = MostFractionalCriterion()
        rules = [Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)]
    )

Chooses the best candidate according to a selection criterion and generates the two children.
"""
struct ClassicBranching <: APITMP.AbstractDivideAlgorithm
    selection_criterion::Branching.AbstractSelectionCriterion
    rules::Vector{Branching.PrioritisedBranchingRule}
    int_tol::Float64
    ClassicBranching(;
        selection_criterion = MostFractionalCriterion(),
        rules = [Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)],
        int_tol = 1e-6
    ) = new(selection_criterion, rules, int_tol)
end

Branching.get_selection_nb_candidates(::ClassicBranching) = 1

struct BranchingContext{SelectionCriterion<:Branching.AbstractSelectionCriterion} <: Branching.AbstractDivideContext
    selection_criterion::SelectionCriterion
    rules::Vector{Branching.PrioritisedBranchingRule}
    int_tol::Float64
end

branching_context_type(::ClassicBranching) = BranchingContext

function new_context(::Type{<:BranchingContext}, algo::ClassicBranching, _)
    return BranchingContext(algo.selection_criterion, algo.rules, algo.int_tol)
end

Branching.get_int_tol(ctx::BranchingContext) = ctx.int_tol
Branching.get_selection_criterion(ctx::BranchingContext) = ctx.selection_criterion
Branching.get_rules(ctx::BranchingContext) = ctx.rules

function advanced_select!(::BranchingContext, candidates, _, reform, _::APITMP.AbstractDivideInput)
    children = Branching.get_children(first(candidates))
    return DivideOutput(children, OptimizationState(getmaster(reform)))
end

############################################################################################
# Branching API implementation for the strong branching
############################################################################################
"""
    BranchingPhase(max_nb_candidates, conquer_algo)

Define a phase in strong branching. It contains the maximum number of candidates
to evaluate and the conquer algorithm which does evaluation.
"""
struct BranchingPhase
    max_nb_candidates::Int64
    conquer_algo::AbstractConquerAlgorithm
    score::Branching.AbstractBranchingScore
end

"""
    StrongBranching

The algorithm that performs a (multi-phase) (strong) branching in a tree search algorithm.

Strong branching is a procedure that heuristically selects a branching constraint that
potentially gives the best progress of the dual bound. The procedure selects a collection 
of branching candidates based on their branching rule and their score.
Then, the procedure evaluates the progress of the dual bound in both branches of each branching
candidate by solving both potential children using a conquer algorithm.
The candidate that has the largest product of dual bound improvements in the branches 
is chosen to be the branching constraint.

When the dual bound improvement produced by the branching constraint is difficult to compute
(e.g. time-consuming in the context of column generation), one can let the branching algorithm
quickly estimate the dual bound improvement of each candidate and retain the most promising
branching candidates. This is called a **phase**. The goal is to first evaluate a large number
of candidates with a very fast conquer algorithm and retain a certain number of promising ones. 
Then, over the phases, it evaluates the improvement with a more precise conquer algorithm and
restrict the number of retained candidates until only one is left.
"""
struct StrongBranching <: APITMP.AbstractDivideAlgorithm
    phases::Vector{BranchingPhase}
    rules::Vector{Branching.PrioritisedBranchingRule}
    selection_criterion::Branching.AbstractSelectionCriterion
    verbose::Bool
    int_tol::Float64
    StrongBranching(;
        phases = [],
        rules = [],
        selection_criterion = MostFractionalCriterion(),
        verbose = true,
        int_tol = 1e-6
    ) = new(phases, rules, selection_criterion, verbose, int_tol)
end

## Implementation of Algorithm API.

# StrongBranching does not use any storage unit itself, 
# therefore get_units_usage() is not defined for it

function get_child_algorithms(algo::StrongBranching, reform::Reformulation) 
    child_algos = Tuple{AbstractAlgorithm, AbstractModel}[]
    for phase in algo.phases
        push!(child_algos, (phase.conquer_algo, reform))
    end
    for prioritised_rule in algo.rules
        push!(child_algos, (prioritised_rule.rule, reform))
    end
    return child_algos
end

# Implementation of the strong branching API.
struct StrongBranchingPhaseContext <: Branching.AbstractStrongBrPhaseContext
    phase_params::BranchingPhase
    units_to_restore_for_conquer::UnitsUsage
end

Branching.get_score(ph::StrongBranchingPhaseContext) = ph.phase_params.score
Branching.get_conquer(ph::StrongBranchingPhaseContext) = ph.phase_params.conquer_algo
Branching.get_units_to_restore_for_conquer(ph::StrongBranchingPhaseContext) = ph.units_to_restore_for_conquer
Branching.get_max_nb_candidates(ph::StrongBranchingPhaseContext) = ph.phase_params.max_nb_candidates

function new_phase_context(::Type{StrongBranchingPhaseContext}, phase::BranchingPhase, reform, _)
    units_to_restore_for_conquer = collect_units_to_restore!(phase.conquer_algo, reform)
    return StrongBranchingPhaseContext(phase, units_to_restore_for_conquer)
end

struct StrongBranchingContext{
    PhaseContext<:Branching.AbstractStrongBrPhaseContext,
    SelectionCriterion<:Branching.AbstractSelectionCriterion
} <: Branching.AbstractStrongBrContext
    phases::Vector{PhaseContext}
    rules::Vector{Branching.PrioritisedBranchingRule}
    selection_criterion::SelectionCriterion
    int_tol::Float64
end

Branching.get_selection_nb_candidates(algo::StrongBranching) = first(algo.phases).max_nb_candidates
Branching.get_rules(ctx::StrongBranchingContext) = ctx.rules
Branching.get_selection_criterion(ctx::StrongBranchingContext) = ctx.selection_criterion
Branching.get_int_tol(ctx::StrongBranchingContext) = ctx.int_tol
Branching.get_phases(ctx::StrongBranchingContext) = ctx.phases

function branching_context_type(algo::StrongBranching)
    select_crit_type = typeof(algo.selection_criterion)
    if algo.verbose
        return BranchingPrinter{StrongBranchingContext{PhasePrinter{StrongBranchingPhaseContext},select_crit_type}}
    end
    return StrongBranchingContext{StrongBranchingPhaseContext,select_crit_type}
end

function new_context(
    ::Type{StrongBranchingContext{PhaseContext, SelectionCriterion}}, algo::StrongBranching, reform
) where {PhaseContext<:Branching.AbstractStrongBrPhaseContext,SelectionCriterion<:Branching.AbstractSelectionCriterion}
    if isempty(algo.rules)
        error("Strong branching: no branching rule is defined.")
    end

    if isempty(algo.phases)
        error("Strong branching: no branching phase is defined.")
    end

    phases = map(((i, phase),) -> new_phase_context(PhaseContext, phase, reform, i), enumerate(algo.phases))
    return StrongBranchingContext(
        phases, algo.rules, algo.selection_criterion, algo.int_tol
    )
end

function _eval_child_of_candidate!(child, phase::Branching.AbstractStrongBrPhaseContext, sb_state, env, reform)
    child_state = TreeSearch.get_opt_state(child)
    update_ip_primal_bound!(child_state, get_ip_primal_bound(sb_state))

    # TODO: We consider that all branching algorithms don't exploit the primal solution 
    # at the moment.
    # best_ip_primal_sol = get_best_ip_primal_sol(sbstate)
    # if !isnothing(best_ip_primal_sol)
    #     set_ip_primal_sol!(nodestate, best_ip_primal_sol)
    # end
    
    child_state = TreeSearch.get_opt_state(child)
    if !ip_gap_closed(child_state)
        input = ConquerInputFromSb(child, Branching.get_units_to_restore_for_conquer(phase))
        run!(Branching.get_conquer(phase), env, reform, input)
        TreeSearch.set_records!(child, create_records(reform))
    end
    child.conquerwasrun = true 
    add_ip_primal_sols!(sb_state, get_ip_primal_sols(child_state)...)
    return
end

function _perform_branching_phase!(
    candidates::Vector{C}, phase::Branching.AbstractStrongBrPhaseContext, sb_state, env, reform
) where {C<:Branching.AbstractBranchingCandidate}
    return map(candidates) do candidate
        children = sort(Branching.get_children(candidate), by = child -> get_lp_primal_bound(TreeSearch.get_opt_state(child)))
        Branching.eval_children_of_candidate!(children, phase, sb_state, env, reform)
        return Branching.compute_score(Branching.get_score(phase), candidate)
    end
end

function _perform_strong_branching!(
    ctx::Branching.AbstractStrongBrContext, env::Env, reform::Reformulation, input::APITMP.AbstractDivideInput, candidates::Vector{C}
)::OptimizationState where {C<:Branching.AbstractBranchingCandidate}
    # TODO: We consider that conquer algorithms in the branching algo don't exploit the
    # primal solution at the moment (3rd arg).
    sb_state = OptimizationState( # TODO: remove explicit use of OptimizationState
        getmaster(reform), APITMP.get_opt_state(input), false, false
    )

    phases = Branching.get_phases(ctx)
    for (phase_index, current_phase) in enumerate(phases)
        nb_candidates_for_next_phase = 1
        if phase_index < length(phases)
            nb_candidates_for_next_phase = Branching.get_max_nb_candidates(phases[phase_index + 1])
            if length(candidates) <= nb_candidates_for_next_phase
                # If at the current phase, we have less candidates than the number of candidates
                # we want to evaluate at the next phase, we skip the current phase.
                continue
            end
            # In phase 1, we make sure that the number of candidates for the next phase is 
            # at least equal to the number of initial candidates.
            nb_candidates_for_next_phase = min(nb_candidates_for_next_phase, length(candidates))
        end

        scores = Branching.perform_branching_phase!(candidates, current_phase, sb_state, env, reform)

        perm = sortperm(scores, rev=true)
        permute!(candidates, perm)

        # The case where one/many candidate is conquered is not supported yet.
        # In this case, the number of candidates for next phase is one.
    
        # before deleting branching candidates which are not kept for the next phase
        # we need to remove record kept in these nodes

        resize!(candidates, nb_candidates_for_next_phase)
    end
    return sb_state
end

# TODO: make generic.
function advanced_select!(ctx::Branching.AbstractStrongBrContext, candidates, env::Env, reform::Reformulation, input::APITMP.AbstractDivideInput)
    sb_state = _perform_strong_branching!(ctx, env, reform, input, candidates)
    children = Branching.get_children(first(candidates))
    return DivideOutput(children, sb_state)
end

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
struct NoBranching <: AbstractDivideAlgorithm end

function run!(::NoBranching, ::Env, reform::Reformulation, ::AbstractDivideInput)
    return DivideOutput([], OptimizationState(getmaster(reform)))
end

############################################################################################
# Branching API
############################################################################################
abstract type AbstractDivideContext end

@mustimplement "Branching" get_max_nb_candidates(::AbstractDivideAlgorithm)

@mustimplement "Branching" branching_context_type(::AbstractDivideAlgorithm)

@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::AbstractDivideAlgorithm)

@mustimplement "Branching" branch!(::AbstractDivideContext, candidates, env, reform, input::AbstractDivideInput)

@mustimplement "Branching" get_int_tol(::AbstractDivideContext)

@mustimplement "Branching" get_rules(::AbstractDivideContext)

@mustimplement "Branching" get_selection_criterion(::AbstractDivideContext)

function _get_extended_and_original_sols(reform, opt_state)
    master = getmaster(reform)
    original_sol = nothing
    extended_sol = get_best_lp_primal_sol(opt_state)
    if !isnothing(extended_sol)
        original_sol = if projection_is_possible(master)
            proj_cols_on_rep(extended_sol, master)
        else
            get_best_lp_primal_sol(opt_state) # it means original_sol equals extended_sol(requires discussion)
        end
    end
    return extended_sol, original_sol
end

# TODO: unit tests for
# - fractional priorities
# - stopping criterion
# - what happens when original_solution or extended_solution are nothing
function _candidates_selection(ctx::AbstractDivideContext, max_nb_candidates, reform, env, parent)
    extended_sol, original_sol = _get_extended_and_original_sols(reform, get_opt_state(parent))

    if isnothing(extended_sol)
        error("Error") #TODO (talk with Ruslan.)
    end
    
    # We sort branching rules by their root/non-root priority.
    sorted_rules = sort(get_rules(ctx), rev = true, by = x -> getpriority(x, isroot(parent)))
    
    kept_branch_candidates = AbstractBranchingCandidate[]

    local_id = 0 # TODO: this variable needs an explicit name.
    priority_of_last_gen_candidates = nothing

    for prioritised_rule in sorted_rules
        rule = prioritised_rule.rule

        # Priority of the current branching rule.
        priority = getpriority(prioritised_rule, isroot(parent))
    
        nb_candidates_found = length(kept_branch_candidates)

        # Before selecting new candidates with the current branching rule, check if generation
        # of candidates stops. Generation of candidates stops when:
        # 1. at least one candidate was generated, and its priority rounded down is stricly greater 
        #    than priorities of not yet considered branching rules; (TODO: example? use case?)
        # 2. all needed candidates were generated and their smallest priority is strictly greater
        #    than priorities of not yet considered branching rules.
        stop_gen_condition_1 = !isnothing(priority_of_last_gen_candidates) &&
            nb_candidates_found > 0 && priority < floor(priority_of_last_gen_candidates)

        stop_gen_condition_2 = !isnothing(priority_of_last_gen_candidates) && 
            nb_candidates_found >= max_nb_candidates && priority < priority_of_last_gen_candidates
    
        if stop_gen_condition_1 || stop_gen_condition_2
            break
        end

        # Generate candidates.
        output = select!(
            rule, env, reform, BranchingRuleInput(
                original_sol, true, max_nb_candidates, get_selection_criterion(ctx),
                local_id, get_int_tol(ctx), priority, parent
            )
        )
        append!(kept_branch_candidates, output.candidates)
        local_id = output.local_id

        if projection_is_possible(getmaster(reform)) && !isnothing(extended_sol)
            output = select!(
                rule, env, reform, BranchingRuleInput(
                    extended_sol, false, max_nb_candidates, get_selection_criterion(ctx),
                    local_id, get_int_tol(ctx), priority, parent
                )
            )
            append!(kept_branch_candidates, output.candidates)
            local_id = output.local_id
        end
        select_candidates!(kept_branch_candidates, get_selection_criterion(ctx), max_nb_candidates)
        priority_of_last_gen_candidates = priority
    end
    return kept_branch_candidates
end

function run!(algo::AbstractDivideAlgorithm, env::Env, reform::Reformulation, input::AbstractDivideInput)
    ctx = new_context(branching_context_type(algo), algo, reform)

    parent = get_parent(input)
    optstate = get_opt_state(parent)
    nodestatus = getterminationstatus(optstate)

    # We don't run the branching algorithm if the node is already conquered
    if nodestatus == OPTIMAL || nodestatus == INFEASIBLE || ip_gap_closed(optstate)             
        #println("Node is already conquered. No children will be generated.")
        return DivideOutput(SbNode[], optstate)
    end

    max_nb_candidates = get_max_nb_candidates(algo)
    candidates = _candidates_selection(ctx, max_nb_candidates, reform, env, parent)

    return branch!(ctx, candidates, env, reform, input)
end

############################################################################################
# Branching API implementation for the (classic) branching
############################################################################################

"""
    Branching(
        selection_criterion = MostFractionalCriterion()
        rules = [PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)]
    )

Chooses the best candidate according to a selection criterion and generates the two children.
"""
@with_kw struct Branching <: AbstractDivideAlgorithm
    selection_criterion::AbstractSelectionCriterion = MostFractionalCriterion()
    rules = [PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)]
    int_tol = 1e-6
end

get_max_nb_candidates(::Branching) = 1

struct BranchingContext{SelectionCriterion<:AbstractSelectionCriterion} <: AbstractDivideContext
    selection_criterion::SelectionCriterion
    rules::Vector{PrioritisedBranchingRule}
    int_tol::Float64
end

function branching_context_type(::Branching)
    return BranchingContext
end

function new_context(::Type{<:BranchingContext}, algo::Branching, _)
    return BranchingContext(algo.selection_criterion, algo.rules, algo.int_tol)
end

get_int_tol(ctx::BranchingContext) = ctx.int_tol
get_selection_criterion(ctx::BranchingContext) = ctx.selection_criterion
get_rules(ctx::BranchingContext) = ctx.rules

function branch!(::BranchingContext, candidates, _, reform, _::AbstractDivideInput)
    children = get_children(first(candidates))
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
    score::AbstractBranchingScore
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
@with_kw struct StrongBranching <: AbstractDivideAlgorithm
    phases::Vector{BranchingPhase} = []
    rules::Vector{PrioritisedBranchingRule} = []
    selection_criterion::AbstractSelectionCriterion = MostFractionalCriterion()
    verbose = true
    int_tol = 1e-6
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

# Implementation

abstract type AbstractStrongBrContext <: AbstractDivideContext end
abstract type AbstractStrongBrPhaseContext end

@mustimplement "StrongBranching" get_units_to_restore_for_conquer(::AbstractStrongBrPhaseContext)

@mustimplement "StrongBranching" get_phases(::AbstractStrongBrContext)

@mustimplement "StrongBranching" get_score(::AbstractStrongBrPhaseContext)

@mustimplement "StrongBranching" get_conquer(::AbstractStrongBrPhaseContext)

@mustimplement "StrongBranching" get_max_nb_candidates(::AbstractStrongBrPhaseContext)

# Following methods are part of the strong branching API but we advise to not redefine them.
# They depends on each other:
# - default implementation of first method calls the second;
# - default implementation of second method calls the third.
perform_branching_phase!(candidates, phase, sb_state, env, reform) =
    _perform_branching_phase!(candidates, phase, sb_state, env, reform)

eval_children_of_candidate!(children, phase, sb_state, env, reform) =
    _eval_children_of_candidate!(children, phase, sb_state, env, reform)

eval_child_of_candidate!(child, phase, sb_state, env, reform) =
    _eval_child_of_candidate!(child, phase, sb_state, env, reform)

# Implementation of the strong branching API.
struct StrongBranchingPhaseContext <: AbstractStrongBrPhaseContext
    phase_params::BranchingPhase
    units_to_restore_for_conquer::UnitsUsage
end

get_score(ph::StrongBranchingPhaseContext) = ph.phase_params.score
get_conquer(ph::StrongBranchingPhaseContext) = ph.phase_params.conquer_algo
get_units_to_restore_for_conquer(ph::StrongBranchingPhaseContext) = ph.units_to_restore_for_conquer
get_max_nb_candidates(ph::StrongBranchingPhaseContext) = ph.phase_params.max_nb_candidates

struct StrongBranchingContext{
    PhaseContext<:AbstractStrongBrPhaseContext,
    SelectionCriterion<:AbstractSelectionCriterion
} <: AbstractStrongBrContext
    phases::Vector{PhaseContext}
    rules::Vector{PrioritisedBranchingRule}
    selection_criterion::SelectionCriterion
    int_tol::Float64
end

get_max_nb_candidates(algo::StrongBranching) = first(algo.phases).max_nb_candidates
get_rules(ctx::StrongBranchingContext) = ctx.rules
get_selection_criterion(ctx::StrongBranchingContext) = ctx.selection_criterion
get_int_tol(ctx::StrongBranchingContext) = ctx.int_tol
get_phases(ctx::StrongBranchingContext) = ctx.phases

function branching_context_type(algo::StrongBranching)
    return StrongBranchingContext
end

function new_context(::Type{<:StrongBranchingContext}, algo::StrongBranching, reform)
    if isempty(algo.rules)
        error("Strong branching: no branching rule is defined.")
    end

    if isempty(algo.phases)
        error("Strong branching: no branching phase is defined.")
    end

    phases = map(algo.phases) do phase
        units_to_restore_for_conquer = collect_units_to_restore!(phase.conquer_algo, reform)
        return StrongBranchingPhaseContext(phase, units_to_restore_for_conquer)
    end
    return StrongBranchingContext(
        phases, algo.rules, algo.selection_criterion, algo.int_tol
    )
end

function _eval_child_of_candidate!(child, phase, sb_state, env, reform)
    child_state = get_opt_state(child)
    update_ip_primal_bound!(child_state, get_ip_primal_bound(sb_state))

    # TODO: We consider that all branching algorithms don't exploit the primal solution 
    # at the moment.
    # best_ip_primal_sol = get_best_ip_primal_sol(sbstate)
    # if !isnothing(best_ip_primal_sol)
    #     set_ip_primal_sol!(nodestate, best_ip_primal_sol)
    # end
    
    child_state = get_opt_state(child)
    if !ip_gap_closed(child_state)
        input = ConquerInputFromSb(child, get_units_to_restore_for_conquer(phase))
        run!(get_conquer(phase), env, reform, input)
        set_records!(child, create_records(reform))
    end
    child.conquerwasrun = true 
    add_ip_primal_sols!(sb_state, get_ip_primal_sols(child_state)...)
    return
end

function _eval_children_of_candidate!(
    children::Vector{SbNode}, phase::AbstractStrongBrPhaseContext,
    sb_state, env, reform
)
    for child in children
        eval_child_of_candidate!(child, phase, sb_state, env, reform)
    end
    return
end

function _perform_branching_phase!(
    candidates::Vector{C}, phase, sb_state, env, reform
) where {C<:AbstractBranchingCandidate}
    return map(candidates) do candidate
        children = sort(get_children(candidate), by = child -> get_lp_primal_bound(get_opt_state(child)))
        eval_children_of_candidate!(children, phase, sb_state, env, reform)
        return compute_score(get_score(phase), candidate)
    end
end

function _perform_strong_branching!(
    ctx::StrongBranchingContext, env::Env, reform::Reformulation, input::AbstractDivideInput, candidates::Vector{C}
)::OptimizationState where {C<:AbstractBranchingCandidate}
    # TODO: We consider that conquer algorithms in the branching algo don't exploit the
    # primal solution at the moment (3rd arg).
    sb_state = OptimizationState(
        getmaster(reform), get_opt_state(input), false, false
    )

    phases = get_phases(ctx)
    for (phase_index, current_phase) in enumerate(phases)
        nb_candidates_for_next_phase = 1
        if phase_index < length(phases)
            nb_candidates_for_next_phase = get_max_nb_candidates(phases[phase_index + 1])
            if length(candidates) <= nb_candidates_for_next_phase
                # If at the current phase, we have less candidates than the number of candidates
                # we want to evaluate at the next phase, we skip the current phase.
                continue
            end
            # In phase 1, we make sure that the number of candidates for the next phase is 
            # at least equal to the number of initial candidates.
            nb_candidates_for_next_phase = min(nb_candidates_for_next_phase, length(candidates))
        end

        # TODO: separate printing logic from algo logic.
        println("**** Strong branching phase ", phase_index, " is started *****");

        scores = perform_branching_phase!(candidates, current_phase, sb_state, env, reform)

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

function branch!(ctx::StrongBranchingContext, candidates, env::Env, reform::Reformulation, input::AbstractDivideInput)
    sb_state = _perform_strong_branching!(ctx, env, reform, input, candidates)
    children = get_children(first(candidates))
    return DivideOutput(children, sb_state)
end

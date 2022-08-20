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

@mustimplement "Branching" branching_context_type(::AbstractDivideAlgorithm)

@mustimplement "Branching" get_max_nb_candidates(::AbstractDivideAlgorithm)

@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::AbstractDivideAlgorithm)

@mustimplement "Branching" branch!(::AbstractDivideContext, candidates, env, reform, input::AbstractDivideInput)

@mustimplement "Branching" get_int_tol(::AbstractDivideContext)

@mustimplement "Branching" get_rules(::AbstractDivideContext)

@mustimplement "Branching" get_selection_criterion(::AbstractDivideContext)

function _get_extended_and_original_sols(reform, optstate)
    master = getmaster(reform)
    original_sol = nothing
    extended_sol = get_best_lp_primal_sol(optstate)
    if !isnothing(extended_sol)
        original_sol = if projection_is_possible(master)
            proj_cols_on_rep(extended_sol, master)
        else
            get_best_lp_primal_sol(optstate) # it means original_sol equals extended_sol(requires discussion)
        end
    end
    return extended_sol, original_sol
end

# TODO: unit tests for
# - fractional priorities
# - stopping criterion
# - what happens when original_solution or extended_solution are nothing
function _candidates_selection(ctx::AbstractDivideContext, max_nb_candidates, reform, env, parent)
    extended_sol, original_sol = _get_extended_and_original_sols(reform, optstate)

    if isnothing(extended_sol)
        error("Error") #TODO
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

function run!(algo::AbstractDivideBranching, env::Env, reform::Reformulation, input::AbstractDivideInput)
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
        selection_criteria = MostFractionalCriterion()
    )

Chooses the best candidate according to a selection criterion and generates the two children.
"""
@with_kw struct Branching <: AbstractDivideAlgorithm
    selection_criteria::AbstractSelectionCriterion = MostFractionalCriterion()
end

# # default parameterisation corresponds to simple branching (no strong branching phases)
# function SimpleBranching()
#     algo = StrongBranching()
#     push!(algo.rules, PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0))
#     return algo
# end


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
    PrioritisedBranchingRule

A branching rule with root and non-root priorities.
"""
struct PrioritisedBranchingRule
    rule::AbstractBranchingRule
    root_priority::Float64
    nonroot_priority::Float64
end

function getpriority(rule::PrioritisedBranchingRule, isroot::Bool)::Float64
    return isroot ? rule.root_priority : rule.nonroot_priority
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

@mustimplement "StrongBranching" get_units_to_restore_for_conquer(::AbstractBrPhaseContext)

@mustimplement "StrongBranching" get_phases(::AbstractStrongBrContext)

@mustimplement "StrongBranching" perform_branching_phase!(candidates, ::StrongBranchingPhaseContext, sb_state, env, reform)

@mustimplement "StrongBranching" eval_children_of_candidate!(children, phase, sb_state, env, reform)

@mustimplement "StrongBranching" eval_child_of_candidate!(child, phase, sb_state, phase, env, reform)

@mustimplement "StrongBranching" get_score(::AbstractStrongBrPhaseContext)

@mustimplement "StrongBranching" get_conquer(::AbstractStrongBrPhaseContext)

struct StrongBranchingPhaseContext <: AbstractStrongBrPhaseContext
    phase_params::BranchingPhase
    units_to_restore_for_conquer::UnitsUsage
end

struct StrongBranchingContext{
    PhaseContext<:AbstractStrongBrPhaseContext,
    SelectionCriterion<:AbstractSelectionCriterion
} <: AbstractStrongBrContext
    phases::Vector{PhaseContext}
    rules::Vector{PrioritisedBranchingRule}
    selection_criterion::SelectionCriterion
    int_tol::Float64
end


struct BranchingContext{SelectionCriterion<:AbstractSelectionCriterion}
    selection_criterion::SelectionCriterion
    int_tol::Float64
end

function branching_context_type(algo::StrongBranching)
    return StrongBranchingContext
end

function new_context(::Type{StrongBranchingContext{P,S}}, algo::StrongBranching, reform)
    # TODO: throws error if no branching rule defined.
    if isempty(algo.rules)
        error("No branching rule is defined.")
    end

    phases = map(algo.phases) do phase
        units_to_restore_for_conquer = collect_units_to_restore!(phase.conquer_algo, reform)
        return StrongBranchingPhaseContext(phase, units_to_restore_for_conquer)
    end
    return StrongBranchingContext(
        phases, algo.rules, algo.selection_criterion, algo.int_tol
    )
end

get_max_nb_candidates(algo::StrongBranching) = first(algo.phases).max_nb_candidates

# # This is only for strong branching
# # returns the optimization part of the output of the conquer algorithm
# function _apply_conquer_alg_to_child!(
#     child::SbNode, algo::AbstractConquerAlgorithm, env::Env, reform::Reformulation, 
#     units_to_restore::UnitsUsage, opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL, 
#     opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
# )
#     child_state = get_opt_state(child)
#     if ip_gap_closed(child_state, rtol = opt_rtol, atol = opt_atol)
#         @info "IP Gap is closed: $(ip_gap(child_state)). Abort treatment."
#     else
#         run!(algo, env, reform, ConquerInputFromSb(child, units_to_restore))
#         child.records = create_records(reform)
#     end
#     child.conquerwasrun = true
#     return
# end


eval_child_of_candidate!(child, phase, sb_state, env, reform) =
    _eval_child_of_candidate!(child, phase, sb_state, env, reform)

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

eval_children_of_candidate!(children, phase, sb_state, env, reform) =
    _eval_children_of_candidate!(children, phase, sb_state, env, reform)

function _eval_children_of_candidate!(
    children::Vector{SbNode}, phase::AbstractStrongBrPhaseContext,
    sb_state, env, reform
)
    for child in children
        #### TODO: remove logs from algo logic
        # 

        # if isverbose(phase.conquer_algo)
        #     print(
        #         "**** SB phase ", -1, " evaluation of candidate ", 
        #         candidate.varname, " (branch ", child_index, " : ", child.branchdescription
        #     )
        #     @printf "), value = %6.2f\n" getvalue(get_lp_primal_bound(get_opt_state(child)))
        # end
        
        eval_child_of_candidate!(child, phase, sb_state, env, reform)
         
        # if to_be_pruned(child) 
        #     if isverbose(phase.conquer_algo)
        #         println("Branch is conquered!")
        #     end
        # end
    end
    return
end

perform_branching_phase!(candidates, phase::StrongBranchingPhaseContext, sb_state, env, reform) =
    _perform_branching_phase!(phase, candidates, sb_state, env, reform)

function _perform_branching_phase!(candidates, phase, sb_state, env, reform)
    return map(candidates) do candidate
        children = sort(get_children(candidate), by = child -> get_lp_primal_bound(get_opt_state(child)))
        eval_children_of_candidate!(children, phase, sb_state, env, reform)
        return compute_score(get_score(phase), candidate)
        # print_bounds_and_score(candidate, -1, 30, score) # TODO: rm
        # return score
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

    for (phase_index, current_phase) in enumerate(get_phases(ctx))
        nb_candidates_for_next_phase = 1
        if phase_index < length(algo.phases)
            nb_candidates_for_next_phase = algo.phases[phase_index + 1].max_nb_candidates
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

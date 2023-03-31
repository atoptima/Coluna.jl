


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
    extended_sol, original_sol = _get_extended_and_original_sols(reform, TreeSearch.get_opt_state(parent))

    if isnothing(extended_sol)
        error("Error") #TODO (talk with Ruslan.)
    end
    
    # We sort branching rules by their root/non-root priority.
    sorted_rules = sort(get_rules(ctx), rev = true, by = x -> getpriority(x, TreeSearch.isroot(parent)))
    
    kept_branch_candidates = AbstractBranchingCandidate[]

    local_id = 0 # TODO: this variable needs an explicit name.
    priority_of_last_gen_candidates = nothing

    for prioritised_rule in sorted_rules
        rule = prioritised_rule.rule

        # Priority of the current branching rule.
        priority = getpriority(prioritised_rule, TreeSearch.isroot(parent))
    
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
    optstate = TreeSearch.get_opt_state(parent)
    nodestatus = getterminationstatus(optstate)

    # We don't run the branching algorithm if the node is already conquered
    if nodestatus == OPTIMAL || nodestatus == INFEASIBLE || ip_gap_closed(optstate)             
        #println("Node is already conquered. No children will be generated.")
        return DivideOutput(SbNode[], optstate)
    end

    max_nb_candidates = get_selection_nb_candidates(algo)
    candidates = _candidates_selection(ctx, max_nb_candidates, reform, env, parent)

    # We stop branching if no candidate generated.
    if length(candidates) == 0
        @warn "No candidate generated. No children will be generated. However, the node is not conquered."
        return DivideOutput(SbNode[], optstate)
    end

    return advanced_select!(ctx, candidates, env, reform, input)
end

############################################################################################
# Strong branching API
############################################################################################

# Implementation
"Supertype for the branching contexts."
abstract type AbstractStrongBrContext <: AbstractDivideContext end

"Supertype for the branching phase contexts."
abstract type AbstractStrongBrPhaseContext end

"Creates a context for the branching phase."
@mustimplement "StrongBranching" new_phase_context(::Type{<:AbstractDivideContext}, phase, reform, phase_index) = nothing

"""
Returns the storage units that must be restored by the conquer algorithm called by the
strong branching phase.
"""
@mustimplement "StrongBranching" get_units_to_restore_for_conquer(::AbstractStrongBrPhaseContext) = nothing

"Returns all phases context of the strong branching algorithm."
@mustimplement "StrongBranching" get_phases(::AbstractStrongBrContext) = nothing

"Returns the type of score used to rank the candidates at a given strong branching phase."
@mustimplement "StrongBranching" get_score(::AbstractStrongBrPhaseContext) = nothing

"Returns the conquer algorithm used to evaluate the candidate's children at a given strong branching phase."
@mustimplement "StrongBranching" get_conquer(::AbstractStrongBrPhaseContext) = nothing

"Returns the maximum number of candidates kept at the end of a given strong branching phase."
@mustimplement "StrongBranching" get_max_nb_candidates(::AbstractStrongBrPhaseContext) = nothing

# Following methods are part of the strong branching API but we advise to not redefine them.
# They depends on each other:
# - default implementation of first method calls the second;
# - default implementation of second method calls the third.

# TODO: needs a better description.
"Performs a branching phase."
perform_branching_phase!(candidates, phase, sb_state, env, reform) =
    _perform_branching_phase!(candidates, phase, sb_state, env, reform)

"Evaluates a candidate."
eval_children_of_candidate!(children, phase, sb_state, env, reform) =
    _eval_children_of_candidate!(children, phase, sb_state, env, reform)

"Evaluate children of a candidate."
eval_child_of_candidate!(child, phase, sb_state, env, reform) =
    _eval_child_of_candidate!(child, phase, sb_state, env, reform)
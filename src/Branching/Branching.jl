module Branching

!true && include("../MustImplement/MustImplement.jl") # linter
using ..MustImplement

!true && include("../interface.jl") # linter
using ..AlgoAPI

include("candidate.jl")
include("criteria.jl")
include("rule.jl")
include("score.jl")

"""
Input of a divide algorithm used by the tree search algorithm.
Contains the parent node in the search tree for which children should be generated.
"""
abstract type AbstractDivideInput end

@mustimplement "DivideInput" get_parent_depth(i::AbstractDivideInput) = nothing
@mustimplement "DivideInput" get_conquer_opt_state(i::AbstractDivideInput) = nothing
@mustimplement "DivideInput" parent_is_root(i::AbstractDivideInput) = nothing
@mustimplement "DivideInput" parent_records(i::AbstractDivideInput) = nothing

"""
Output of a divide algorithm used by the tree search algorithm.
Should contain the vector of generated nodes.
"""
abstract type AbstractDivideOutput end

@mustimplement "DivideOutput" get_children(output::AbstractDivideOutput) = nothing

# TODO: simplify this because we only retrieve ip primal sols found in branching candidates.
@mustimplement "DivideOutput" get_opt_state(output::AbstractDivideOutput) = nothing


############################################################################################
# Branching API
############################################################################################

"Supertype for divide algorithm contexts."
abstract type AbstractDivideContext end

"Returns the number of candidates that the candidates selection step must return."
@mustimplement "Branching" get_selection_nb_candidates(::AlgoAPI.AbstractDivideAlgorithm) = nothing

"Returns the type of context required by the algorithm parameters."
@mustimplement "Branching" branching_context_type(::AlgoAPI.AbstractDivideAlgorithm) = nothing

"Creates a context."
@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::AlgoAPI.AbstractDivideAlgorithm, reform) = nothing

# TODO: can have a default implemntation when strong branching will be generic.
"Advanced candidates selection that selects candidates by evaluating their children."
@mustimplement "Branching" advanced_select!(::AbstractDivideContext, candidates, env, reform, input::AbstractDivideInput) = nothing

"Returns integer tolerance."
@mustimplement "Branching" get_int_tol(::AbstractDivideContext) = nothing

"Returns branching rules."
@mustimplement "Branching" get_rules(::AbstractDivideContext) = nothing

"Returns the selection criterion."
@mustimplement "Branching" get_selection_criterion(::AbstractDivideContext) = nothing

# find better name
@mustimplement "Branching" projection_on_master_is_possible(ctx, reform) = nothing

# branching output
"""
    new_divide_output(children::Union{Vector{N}, Nothing}, ip_primal_sols_found{C, Nothing}) where {N, C} -> AbstractDivideOutput

where:
- `N` is the type of nodes generated by the branching algorithm.
- `C` is the type of the collection that stores all ip primal solutions found by the branching algorithm.

If no nodes nor ip primal solutions are found, the generic implementation may provide `nothing`.
"""
@mustimplement "BranchingOutput" new_divide_output(children, ip_primal_sols_found) = nothing


# Default implementations.
"Candidates selection for branching algorithms."
function select!(rule::AbstractBranchingRule, env, reform, input::Branching.BranchingRuleInput)
    candidates = apply_branching_rule(rule, env, reform, input)
    local_id = input.local_id + length(candidates)
    select_candidates!(candidates, input.criterion, input.max_nb_candidates)

    for candidate in candidates
        children = generate_children!(candidate, env, reform, input.input)
        set_children!(candidate, children)
    end
    return BranchingRuleOutput(local_id, candidates)
end

abstract type AbstractBranchingContext <: AbstractDivideContext end

function advanced_select!(ctx::AbstractBranchingContext, candidates, _, reform, input::AbstractDivideInput)
    children = get_children(first(candidates))
    return new_divide_output(children, nothing)
end

############################################################################################
# Strong branching API
############################################################################################

# Implementation
"Supertype for the strong branching contexts."
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

""
@mustimplement "StrongBranchingOptState" new_ip_primal_sols_pool(ctx, reform, input) = nothing

function advanced_select!(ctx::Branching.AbstractStrongBrContext, candidates, env, reform, input::Branching.AbstractDivideInput)
    ip_primal_sols_found = perform_strong_branching!(ctx, env, reform, input, candidates)
    children = get_children(first(candidates))
    return new_divide_output(children, ip_primal_sols_found)
end

function perform_strong_branching!(
    ctx::AbstractStrongBrContext, env, reform, input::Branching.AbstractDivideInput, candidates::Vector{C}
) where {C<:AbstractBranchingCandidate}
    return perform_strong_branching_inner!(ctx, env, reform, input, candidates)
end

function perform_strong_branching_inner!(
    ctx::AbstractStrongBrContext, env, model, input::Branching.AbstractDivideInput, candidates::Vector{C}
) where {C<:AbstractBranchingCandidate}
    # We will store all the new ip primal solution found during the strong branching in the
    # following data structure.
    ip_primal_sols_found = new_ip_primal_sols_pool(ctx, model, input)

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

        scores = perform_branching_phase!(candidates, current_phase, ip_primal_sols_found, env, model, input)

        perm = sortperm(scores, rev=true)
        permute!(candidates, perm)

        # The case where one/many candidate is conquered is not supported yet.
        # In this case, the number of candidates for next phase is one.
    
        # before deleting branching candidates which are not kept for the next phase
        # we need to remove record kept in these nodes

        resize!(candidates, nb_candidates_for_next_phase)
    end
    return ip_primal_sols_found
end

function perform_branching_phase!(candidates, phase, ip_primal_sols_found, env, reform, input)
    return perform_branching_phase_inner!(candidates, phase, ip_primal_sols_found, env, reform, input)
end

"Performs a branching phase."
function perform_branching_phase_inner!(candidates, phase, ip_primal_sols_found, env, reform, input)
    
    return map(candidates) do candidate
        # TODO; I don't understand why we need to sort the children here.
        # Looks like eval_children_of_candidiate! and the default implementation of
        # eval_child_of_candidate is fully independent of the order of the children.
        # Moreover, given the generic implementation of perform_branching_phase!,
        # it's not clear to me how the order of the children can affect the result.
        # At the end, only the score matters and AFAIK, the score is also independent of the order.

        # The reason of sorting (by Ruslan) : Ideally, we need to estimate the score of the candidate after 
        # the first branch is solved if the score estimation is worse than the best score found so far, we discard the candidate
        # and do not evaluate the second branch. As estimation of score is not implemented, sorting is useless for now. 
        
        # children = sort(
        #     Branching.get_children(candidate),
        #     by = child -> get_lp_primal_bound(TreeSearch.get_opt_state(child))
        # )

        return eval_candidate!(candidate, phase, ip_primal_sols_found, env, reform, input)
    end
end

function eval_candidate!(candidate, phase::AbstractStrongBrPhaseContext, ip_primal_sols_found, env, reform, input)
    return eval_candidate_inner!(candidate, phase, ip_primal_sols_found, env, reform, input)
end

"Evaluates a candidate."
function eval_candidate_inner!(candidate, phase::AbstractStrongBrPhaseContext, ip_primal_sols_found, env, reform, input)
    for child in get_children(candidate)
        eval_child_of_candidate!(child, phase, ip_primal_sols_found, env, reform, input)
    end
    return compute_score(get_score(phase), candidate, input)
end

"Evaluate children of a candidate."
@mustimplement "StrongBranching" eval_child_of_candidate!(child, phase, ip_primal_sols_found, env, reform, input) = nothing

@mustimplement "Branching" isroot(node) = nothing

##############################################################################
# Default implementation of the branching algorithm
##############################################################################
function candidates_selection(ctx::Branching.AbstractDivideContext, max_nb_candidates, reform, env, extended_sol, original_sol, input)
    if isnothing(extended_sol)
        error("Error") #TODO (talk with Ruslan.)
    end
    
    # We sort branching rules by their root/non-root priority.
    sorted_rules = sort(Branching.get_rules(ctx), rev = true, by = x -> Branching.getpriority(x, parent_is_root(input)))
    
    kept_branch_candidates = Branching.AbstractBranchingCandidate[]

    local_id = 0 # TODO: this variable needs an explicit name.
    priority_of_last_gen_candidates = nothing

    for prioritised_rule in sorted_rules
        rule = prioritised_rule.rule

        # Priority of the current branching rule.
        priority = Branching.getpriority(prioritised_rule, parent_is_root(input))
    
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
        output = Branching.select!(
            rule, env, reform, Branching.BranchingRuleInput(
                original_sol, true, max_nb_candidates, Branching.get_selection_criterion(ctx),
                local_id, Branching.get_int_tol(ctx), priority, input
            )
        )
        append!(kept_branch_candidates, output.candidates)
        local_id = output.local_id

        if projection_on_master_is_possible(ctx, reform) && !isnothing(extended_sol)
            output = Branching.select!(
                rule, env, reform, Branching.BranchingRuleInput(
                    extended_sol, false, max_nb_candidates, Branching.get_selection_criterion(ctx),
                    local_id, Branching.get_int_tol(ctx), priority, input
                )
            )
            append!(kept_branch_candidates, output.candidates)
            local_id = output.local_id
        end
        select_candidates!(kept_branch_candidates, Branching.get_selection_criterion(ctx), max_nb_candidates)
        priority_of_last_gen_candidates = priority
    end
    return kept_branch_candidates
end

@mustimplement "Branching" why_no_candidate(reform, input, extended_sol, original_sol) = nothing

function run_branching!(ctx, env, reform, input::Branching.AbstractDivideInput, extended_sol, original_sol)
    max_nb_candidates = get_selection_nb_candidates(ctx)
    candidates = candidates_selection(ctx, max_nb_candidates, reform, env, extended_sol, original_sol, input)

    # We stop branching if no candidate generated.
    if length(candidates) == 0
        @warn "No candidate generated. No children will be generated. However, the node is not conquered."
        why_no_candidate(reform, input, extended_sol, original_sol)
        return new_divide_output(nothing, nothing)
    end

    return advanced_select!(ctx, candidates, env, reform, input)
end

end
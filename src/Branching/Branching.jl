module Branching

!true && include("../MustImplement/MustImplement.jl") # linter
using ..MustImplement

!true && include("../interface.jl") # linter
using ..APITMP

include("candidate.jl")
include("criteria.jl")
include("rule.jl")
include("score.jl")

"""
Input of a divide algorithm used by the tree search algorithm.
Contains the parent node in the search tree for which children should be generated.
"""
abstract type AbstractDivideInput end

@mustimplement "DivideInput" get_parent(i::AbstractDivideInput) = nothing
@mustimplement "DivideInput" get_opt_state(i::AbstractDivideInput) = nothing

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
@mustimplement "Branching" get_selection_nb_candidates(::APITMP.AbstractDivideAlgorithm) = nothing

"Returns the type of context required by the algorithm parameters."
@mustimplement "Branching" branching_context_type(::APITMP.AbstractDivideAlgorithm) = nothing

"Creates a context."
@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::APITMP.AbstractDivideAlgorithm, reform) = nothing

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
@mustimplement "Branching" projection_is_possible(::AbstractDivideContext, reform) = nothing

# branching output
@mustimplement "BranchingOutput" new_divide_output(children, opt_state) = nothing


# Default implementations.
"Candidates selection for branching algorithms."
function select!(rule::AbstractBranchingRule, env, reform, input::Branching.BranchingRuleInput)
    candidates = apply_branching_rule(rule, env, reform, input)
    local_id = input.local_id + length(candidates)
    select_candidates!(candidates, input.criterion, input.max_nb_candidates)

    for candidate in candidates
        children = generate_children!(candidate, env, reform, input.parent)
        set_children!(candidate, children)
    end
    return BranchingRuleOutput(local_id, candidates)
end

function advanced_select!(ctx::AbstractDivideContext, candidates, _, reform, input::AbstractDivideInput)
    children = get_children(first(candidates))
    return new_divide_output(children, new_optimization_state(ctx, reform, input))
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

""
@mustimplement "StrongBranchingOptState" new_optimization_state(ctx, reform, input) = nothing

# TODO: make generic.
function advanced_select!(ctx::Branching.AbstractStrongBrContext, candidates, env, reform, input::Branching.AbstractDivideInput)
    println("\e[34m ntm \e[0m")
    sb_state = perform_strong_branching!(ctx, env, reform, input, candidates)
    children = get_children(first(candidates))
    return new_divide_output(children, sb_state)
end

function perform_strong_branching!(
    ctx::AbstractStrongBrContext, env, reform, input::Branching.AbstractDivideInput, candidates::Vector{C}
) where {C<:AbstractBranchingCandidate}
    @show typeof(ctx)
    return perform_strong_branching_inner!(ctx, env, reform, input, candidates)
end

function perform_strong_branching_inner!(
    ctx::AbstractStrongBrContext, env, model, input::Branching.AbstractDivideInput, candidates::Vector{C}
) where {C<:AbstractBranchingCandidate}    
    # More clarity is needed here.
    # Basically, the goal is to give to the nodes of the candidates the best bounds found so far.
    optimization_state = new_optimization_state(ctx, model, input)

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

        scores = perform_branching_phase!(candidates, current_phase, optimization_state, env, model)

        perm = sortperm(scores, rev=true)
        permute!(candidates, perm)

        # The case where one/many candidate is conquered is not supported yet.
        # In this case, the number of candidates for next phase is one.
    
        # before deleting branching candidates which are not kept for the next phase
        # we need to remove record kept in these nodes

        resize!(candidates, nb_candidates_for_next_phase)
    end
    return optimization_state
end

# TODO: we can make the perform strong branching method generic by just removing the explicit
# use of the OptimizationState from its current implementation.
# When we do this, we'll have to write good unit tests to make the sure the generic implemntation is correct.
# Current almost generic implementation is in: _perform_strong_branching!
# perform_strong_branching!(ctx, env, reform, input, candidates) -> OptimizationState

function perform_branching_phase!(candidates, phase, sb_state, env, reform)
    return perform_branching_phase_inner!(candidates, phase, sb_state, env, reform)
end

# TODO: make the default implementation generic.
"Performs a branching phase."
function perform_branching_phase_inner!(candidates, phase, sb_state, env, reform)
    return map(candidates) do candidate
        # TODO; I don't understand why we need to sort the children here.
        # Looks like eval_children_of_candidiate! and the default implementation of
        # eval_child_of_candidate is fully independent of the order of the children.
        # Moreover, given the generic implementation of perform_branching_phase!,
        # it's not clear to me how the order of the children can affect the result.
        # At the end, only the score matters and AFAIK, the score is also independent of the order.
        
        # children = sort(
        #     Branching.get_children(candidate),
        #     by = child -> get_lp_primal_bound(TreeSearch.get_opt_state(child))
        # )
        children = Branching.get_children(candidate)
        Branching.eval_children_of_candidate!(children, phase, sb_state, env, reform)
        return Branching.compute_score(Branching.get_score(phase), candidate)
    end
end

function eval_children_of_candidate!(children, phase::AbstractStrongBrPhaseContext, sb_state, env, reform)
    return eval_children_of_candidate_inner!(children, phase, sb_state, env, reform)
end

"Evaluates a candidate."
function eval_children_of_candidate_inner!(children, phase::AbstractStrongBrPhaseContext, ip_primal_sols, env, reform)
    for child in children
        eval_child_of_candidate!(child, phase, ip_primal_sols, env, reform)
    end
    return
end

"Evaluate children of a candidate."
@mustimplement "StrongBranching" eval_child_of_candidate!(child, phase, sb_state, env, reform) = nothing

@mustimplement "Branching" isroot(node) = nothing

##############################################################################
# Default implementation of the branching algorithm
##############################################################################
function candidates_selection(ctx::Branching.AbstractDivideContext, max_nb_candidates, reform, env, parent, extended_sol, original_sol)
    if isnothing(extended_sol)
        error("Error") #TODO (talk with Ruslan.)
    end

    @show typeof(parent)
    
    # We sort branching rules by their root/non-root priority.
    sorted_rules = sort(Branching.get_rules(ctx), rev = true, by = x -> Branching.getpriority(x, isroot(parent)))
    
    kept_branch_candidates = Branching.AbstractBranchingCandidate[]

    local_id = 0 # TODO: this variable needs an explicit name.
    priority_of_last_gen_candidates = nothing

    for prioritised_rule in sorted_rules
        rule = prioritised_rule.rule

        # Priority of the current branching rule.
        priority = Branching.getpriority(prioritised_rule, isroot(parent))
    
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
                local_id, Branching.get_int_tol(ctx), priority, parent
            )
        )
        append!(kept_branch_candidates, output.candidates)
        local_id = output.local_id

        if projection_is_possible(ctx, reform) && !isnothing(extended_sol)
            output = Branching.select!(
                rule, env, reform, Branching.BranchingRuleInput(
                    extended_sol, false, max_nb_candidates, Branching.get_selection_criterion(ctx),
                    local_id, Branching.get_int_tol(ctx), priority, parent
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

function run_branching!(ctx, env, reform, input::Branching.AbstractDivideInput, extended_sol, original_sol)
    parent = Branching.get_parent(input)
    max_nb_candidates = get_selection_nb_candidates(ctx)
    candidates = candidates_selection(ctx, max_nb_candidates, reform, env, parent, extended_sol, original_sol)

    # We stop branching if no candidate generated.
    if length(candidates) == 0
        @warn "No candidate generated. No children will be generated. However, the node is not conquered."
        return
    end

    return advanced_select!(ctx, candidates, env, reform, input)
end

end
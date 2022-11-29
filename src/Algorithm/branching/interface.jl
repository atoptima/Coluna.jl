############################################################################################
# Candidates
############################################################################################

"""
A branching candidate is a data structure that contain all information needed to generate
children of a node.
"""
abstract type AbstractBranchingCandidate end

"Returns a string which serves to print the branching rule in the logs."
getdescription(candidate::AbstractBranchingCandidate) = 
    error("getdescription not defined for branching candidates of type $(typeof(candidate)).")

# Branching candidate and branching rule should be together.
# the rule generates the candidate.

## Note: Branching candidates must be created in the BranchingRule algorithm so they do not need
## a generic constructor.

"Returns the left-hand side of the candidate."
@mustimplement "BranchingCandidate" get_lhs(c::AbstractBranchingCandidate)

"Returns the generation id of the candidiate."
@mustimplement "BranchingCandidate" get_local_id(c::AbstractBranchingCandidate)

"Returns the children of the candidate."
@mustimplement "BranchingCandidate" get_children(c::AbstractBranchingCandidate)

"Set the children of the candidate."
@mustimplement "BranchingCandidate" set_children!(c::AbstractBranchingCandidate, children)

"Returns the parent node of the candidate's children."
@mustimplement "BranchingCandidate" get_parent(c::AbstractBranchingCandidate)

# TODO: this method should not generate the children of the tree search algorithm.
# However, AbstractBranchingCandidate should implement an interface to retrieve data to
# generate a children.
"""
    generate_children!(branching_candidate, lhs, env, reform, node)

This method generates the children of a node described by `branching_candidate`.
Make sure that this method returns an object the same type as the second argument of
`set_children!(candiate, children)`.
"""
@mustimplement "BranchingCandidate" generate_children!(c::AbstractBranchingCandidate, env, reform, parent)

"List of storage units to restore before evaluating the node."
@mustimplement "BranchingCandidate" get_branching_candidate_units_usage(::AbstractBranchingCandidate, reform)

############################################################################################
# Selection Criteria of branching candidates
############################################################################################
"""
Supertype of selection criteria of branching candidates.

A selection criterion provides a way to keep only the most promising branching
candidates. To create a new selection criterion, one needs to create a subtype of
`AbstractSelectionCriterion` and implements the method `select_candidates!`.
"""
abstract type AbstractSelectionCriterion end

"Sort branching candidates according to the selection criterion and remove excess ones."
@mustimplement "BranchingSelection" select_candidates!(::Vector{<:AbstractBranchingCandidate}, selection::AbstractSelectionCriterion, ::Int)

############################################################################################
# Branching rules
############################################################################################
"""
Supertype of branching rules.
"""
abstract type AbstractBranchingRule <: AbstractAlgorithm end

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
Input of a branching rule (branching separation algorithm)
Contains current solution, max number of candidates and local candidate id.
"""
struct BranchingRuleInput{SelectionCriterion<:AbstractSelectionCriterion,Node<:AbstractNode}
    solution::PrimalSolution 
    isoriginalsol::Bool
    max_nb_candidates::Int64
    criterion::SelectionCriterion
    local_id::Int64
    int_tol::Float64
    minimum_priority::Float64
    parent::Node
end

"""
Output of a branching rule (branching separation algorithm)
It contains the branching candidates generated and the updated local id value
"""
struct BranchingRuleOutput
    local_id::Int64
    candidates::Vector{AbstractBranchingCandidate}
end
 
# branching rules are always manager algorithms (they manage storing and restoring storage units)
ismanager(algo::AbstractBranchingRule) = true

"Returns all candidates that satisfy a given branching rule."
@mustimplement "BranchingRule" apply_branching_rule(rule, env, reform, input)

"Candidates selection for branching algorithms."
function select!(rule::AbstractBranchingRule, env::Env, reform::Reformulation, input::BranchingRuleInput)
    candidates = apply_branching_rule(rule, env, reform, input)
    local_id = input.local_id + length(candidates)
    select_candidates!(candidates, input.criterion, input.max_nb_candidates)

    for candidate in candidates
        children = generate_children!(candidate, env, reform, input.parent)
        set_children!(candidate, children)
    end
    return BranchingRuleOutput(local_id, candidates)
end

############################################################################################
# Branching score
############################################################################################
"""
Supertype of branching scores.
"""
abstract type AbstractBranchingScore end

"Returns the score of a candidate."
@mustimplement "BranchingScore" compute_score(::AbstractBranchingScore, candidate)

############################################################################################
# Branching API
############################################################################################

"Supertype for divide algorithm contexts."
abstract type AbstractDivideContext end

"Returns the number of candidates that the candidates selection step must return."
@mustimplement "Branching" get_selection_nb_candidates(::AbstractDivideAlgorithm)

"Returns the type of context required by the algorithm parameters."
@mustimplement "Branching" branching_context_type(::AbstractDivideAlgorithm)

"Creates a context."
@mustimplement "Branching" new_context(::Type{<:AbstractDivideContext}, algo::AbstractDivideAlgorithm, reform)

"Advanced candidates selection that selects candidates by evaluating their children."
@mustimplement "Branching" advanced_select!(::AbstractDivideContext, candidates, env, reform, input::AbstractDivideInput)

"Returns integer tolerance."
@mustimplement "Branching" get_int_tol(::AbstractDivideContext)

"Returns branching rules."
@mustimplement "Branching" get_rules(::AbstractDivideContext)

"Returns the selection criterion."
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

    max_nb_candidates = get_selection_nb_candidates(algo)
    candidates = _candidates_selection(ctx, max_nb_candidates, reform, env, parent)

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
@mustimplement "StrongBranching" new_phase_context(::Type{<:AbstractDivideContext}, phase, reform, phase_index)

"""
Returns the storage units that must be restored by the conquer algorithm called by the
strong branching phase.
"""
@mustimplement "StrongBranching" get_units_to_restore_for_conquer(::AbstractStrongBrPhaseContext)

"Returns all phases context of the strong branching algorithm."
@mustimplement "StrongBranching" get_phases(::AbstractStrongBrContext)

"Returns the type of score used to rank the candidates at a given strong branching phase."
@mustimplement "StrongBranching" get_score(::AbstractStrongBrPhaseContext)

"Returns the conquer algorithm used to evaluate the candidate's children at a given strong branching phase."
@mustimplement "StrongBranching" get_conquer(::AbstractStrongBrPhaseContext)

"Returns the maximum number of candidates kept at the end of a given strong branching phase."
@mustimplement "StrongBranching" get_max_nb_candidates(::AbstractStrongBrPhaseContext)

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
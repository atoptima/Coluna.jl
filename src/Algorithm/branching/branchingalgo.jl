############################################################################################
# NoBranching
############################################################################################

"""
    NoBranching

Divide algorithm that does nothing. It does not generate any child.
"""
struct NoBranching <: AbstractDivideAlgorithm end

function run!(::NoBranching, ::Env, reform::Reformulation, ::DivideInput)::DivideOutput
    return DivideOutput([], OptimizationState(getmaster(reform)))
end

############################################################################################
# StrongBranching
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
    int_tol = 1e-6
end

# default parameterisation corresponds to simple branching (no strong branching phases)
function SimpleBranching()
    algo = StrongBranching()
    push!(algo.rules, PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0))
    return algo
end

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

# This is only for strong branching
# returns the optimization part of the output of the conquer algorithm
function _apply_conquer_alg_to_child!(
    child::SbNode, algo::AbstractConquerAlgorithm, env::Env, reform::Reformulation, 
    units_to_restore::UnitsUsage, opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL, 
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
)
    child_state = getoptstate(child)
    if ip_gap_closed(child_state, rtol = opt_rtol, atol = opt_atol)
        @info "IP Gap is closed: $(ip_gap(child_state)). Abort treatment."
    else
        run!(algo, env, reform, ConquerInput(Node(child), units_to_restore, true))
        child.records = create_records(reform)
    end
    child.conquerwasrun = true
    return
end

function _eval_children_of_candidate!(
    children::Vector{SbNode}, phase::BranchingPhase, phase_index, conquer_units_to_restore, 
    sbstate, env, reform, varname
)
    for (child_index, child) in enumerate(children) 
        #### TODO: remove logs from algo logic
        if isverbose(phase.conquer_algo)
            print(
                "**** SB phase ", phase_index, " evaluation of candidate ", 
                varname, " (branch ", child_index, " : ", child.branchdescription
            )
            @printf "), value = %6.2f\n" getvalue(get_lp_primal_bound(getoptstate(child)))
        end
        
        child_state = getoptstate(child)
        update_ip_primal_bound!(child_state, get_ip_primal_bound(sbstate))

        # TODO: We consider that all branching algorithms don't exploit the primal solution 
        # at the moment.
        # best_ip_primal_sol = get_best_ip_primal_sol(sbstate)
        # if !isnothing(best_ip_primal_sol)
        #     set_ip_primal_sol!(nodestate, best_ip_primal_sol)
        # end                

        _apply_conquer_alg_to_child!(
            child, phase.conquer_algo, env, reform, conquer_units_to_restore
        )        

        add_ip_primal_sols!(sbstate, get_ip_primal_sols(child_state)...)
         
        if to_be_pruned(child) 
            if isverbose(phase.conquer_algo)
                println("Branch is conquered!")
            end
        end
    end
    return
end

function _perform_strong_branching_with_phases!(
    algo::StrongBranching, env::Env, reform::Reformulation, input::DivideInput, candidates::Vector{C}
)::OptimizationState where {C<:AbstractBranchingCandidate}
    # TODO: We consider that conquer algorithms in the branching algo don't exploit the
    # primal solution at the moment (3rd arg).
    sbstate = OptimizationState(
        getmaster(reform), getoptstate(input), false, false
    )

    for (phase_index, current_phase) in enumerate(algo.phases)
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

        conquer_units_to_restore = collect_units_to_restore!(current_phase.conquer_algo, reform)

        # TODO: separate printing logic from algo logic.
        println("**** Strong branching phase ", phase_index, " is started *****");

        scores = map(candidates) do candidate
            children = sort(get_children(candidate), by = child -> get_lp_primal_bound(getoptstate(child)))
            _eval_children_of_candidate!(
                children, current_phase, phase_index, conquer_units_to_restore, sbstate, env,
                reform, candidate.varname
            )

            score = compute_score(current_phase.score, candidate)
            print_bounds_and_score(candidate, phase_index, 30, score) # TODO: rm
            return score
        end

        perm = sortperm(scores, rev=true)
        permute!(candidates, perm)

        # The case where one/many candidate is conquered is not supported yet.
        # In this case, the number of candidates for next phase is one.
    
        # before deleting branching candidates which are not kept for the next phase
        # we need to remove record kept in these nodes

        resize!(candidates, nb_candidates_for_next_phase)
    end
    return sbstate
end

# TODO: unit tests for
# - fractional priorities
# - stopping criterion
# - what happens when original_solution or extended_solution are nothing
function _select_candidates_with_branching_rule(rules, phases, selection_criterion, int_tol, parent_is_root, reform, env, original_solution, extended_solution, parent)
    kept_branch_candidates = AbstractBranchingCandidate[]

    # We sort branching rules by their root/non-root priority.
    sorted_rules = sort(rules, rev = true, by = x -> getpriority(x, parent_is_root))

    max_nb_candidates = if isempty(phases)
        # A simple branching algorithm (with no phase) selects one candidate using the branching
        # rules and return it.
        1
    else
        # If the branching algorithm has phases, then it first selects the maximum number of
        # candidates required by the first phases. The last phase returns the "best" candidate.
        first(phases).max_nb_candidates
    end

    local_id = 0 # TODO: this variable needs an explicit name.
    priority_of_last_gen_candidates = nothing

    for prioritised_rule in sorted_rules
        rule = prioritised_rule.rule

        # Priority of the current branching rule.
        priority = getpriority(prioritised_rule, parent_is_root)
    
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
                original_solution, true, max_nb_candidates, selection_criterion, 
                local_id, int_tol, priority, parent
            )
        )
        append!(kept_branch_candidates, output.candidates)
        local_id = output.local_id

        if projection_is_possible(getmaster(reform)) && !isnothing(extended_solution)
            output = select!(
                rule, env, reform, BranchingRuleInput(
                    extended_solution, false, max_nb_candidates, selection_criterion, 
                    local_id, int_tol, priority, parent
                )
            )
            append!(kept_branch_candidates, output.candidates)
            local_id = output.local_id
        end
        select_candidates!(kept_branch_candidates, selection_criterion, max_nb_candidates)
        priority_of_last_gen_candidates = priority
    end
    return kept_branch_candidates
end

function run!(algo::StrongBranching, env::Env, reform::Reformulation, input::DivideInput)::DivideOutput
    parent = getparent(input)
    optstate = getoptstate(parent)
    nodestatus = getterminationstatus(optstate)

    # We don't run the branching algorithm if the node is already conquered
    if nodestatus == OPTIMAL || nodestatus == INFEASIBLE || ip_gap_closed(optstate)             
        println("Node is already conquered. No children will be generated.")
        return DivideOutput(SbNode[], optstate)
    end

    if isempty(algo.rules)
        @logmsg LogLevel(0) "No branching rule is defined. No children will be generated."
        return DivideOutput(SbNode[], optstate)
    end

    # We retrieve the original and extended solutions.
    master = getmaster(reform)
    original_solution = nothing
    extended_solution = get_best_lp_primal_sol(optstate)
    if !isnothing(extended_solution)
        original_solution = if projection_is_possible(master)
            proj_cols_on_rep(extended_solution, master)
        else
            get_best_lp_primal_sol(optstate)
        end
    else
        @warn "no LP solution is passed to the branching algorithm. No children will be generated."
        return DivideOutput(SbNode[], optstate)
    end

    parent_is_root = iszero(getdepth(parent))
    kept_branch_candidates = _select_candidates_with_branching_rule(
        algo.rules, algo.phases, algo.selection_criterion, algo.int_tol, parent_is_root, reform, env, original_solution, extended_solution, parent
    )

    if isempty(kept_branch_candidates)
        @logmsg LogLevel(0) "No branching candidates found. No children will be generated."
        return DivideOutput(SbNode[], optstate)
    end

    # in the case of simple branching, it remains to generate the children
    if isempty(algo.phases) 
        children = get_children(first(kept_branch_candidates))
        return DivideOutput(children, OptimizationState(getmaster(reform)))
    end

    sbstate = _perform_strong_branching_with_phases!(algo, env, reform, input, kept_branch_candidates)
    children = get_children(first(kept_branch_candidates))
    return DivideOutput(children, sbstate)
end

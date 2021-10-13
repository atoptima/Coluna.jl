"""
    BranchingPhase(max_nb_candidates, conquer_algo)

Define a phase in strong branching. It contains the maximum number of candidates
to evaluate and the conquer algorithm which does evaluation.
"""
struct BranchingPhase
    max_nb_candidates::Int64
    conquer_algo::AbstractConquerAlgorithm
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

############################################################################################
# NoBranching
############################################################################################

"""
    NoBranching

Divide algorithm that does not branch. It does not generate any child.
"""
struct NoBranching <: AbstractDivideAlgorithm end

function run!(::NoBranching, ::Env, reform::Reformulation, ::DivideInput)::DivideOutput
    return DivideOutput([], OptimizationState(getmaster(reform)))
end

############################################################################################
# StrongBranching
############################################################################################

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
function SimpleBranching()::AbstractDivideAlgorithm
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

function exploits_primal_solutions(algo::StrongBranching)
    for phase in algo.phases
        exploits_primal_solutions(phase.conquer_algo) && return true
    end
    return false
end

function perform_strong_branching_with_phases!(
    algo::StrongBranching, env::Env, reform::Reformulation, input::DivideInput, groups::Vector{BranchingGroup}
)::OptimizationState

    parent = getparent(input)
    exploitsprimalsolutions::Bool = exploits_primal_solutions(algo)    
    sbstate = OptimizationState(
        getmaster(reform), getoptstate(input), exploitsprimalsolutions, false
    )

    children_generated = false
    for (phase_index, current_phase) in enumerate(algo.phases)
        nb_candidates_for_next_phase::Int64 = 1        
        if phase_index < length(algo.phases)
            nb_candidates_for_next_phase = algo.phases[phase_index + 1].max_nb_candidates
            if phase_index > 1 && length(groups) <= nb_candidates_for_next_phase 
                continue
            end
        end

        conquer_units_to_restore = UnitsUsage()
        collect_units_to_restore!(
            conquer_units_to_restore, current_phase.conquer_algo, reform
        )

        #TO DO : we need to define a print level parameter
        println("**** Strong branching phase ", phase_index, " is started *****");

        #for nice printing, we compute the maximum description length
        max_descr_length::Int64 = 0
        for group in groups
            description = getdescription(group.candidate)
            if (max_descr_length < length(description)) 
                max_descr_length = length(description)
            end
        end
 
        for (group_index,group) in enumerate(groups)
            #TO DO: verify if time limit is reached
            if !children_generated
                generate_children!(group, env, reform, parent)                
            else    
                regenerate_children!(group, parent)
            end
                        
            if phase_index > 1
                sort!(group.children, by = x -> get_lp_primal_bound(getoptstate(x)))
            end
            
            # Here, we avoid the removal of pruned nodes at this point to let them
            # appear in the branching tree file            
            for (node_index, node) in enumerate(group.children)
                if isverbose(current_phase.conquer_algo)
                    print(
                        "**** SB phase ", phase_index, " evaluation of candidate ", 
                        group_index, " (branch ", node_index, " : ", node.branchdescription
                    )
                    @printf "), value = %6.2f\n" getvalue(get_lp_primal_bound(getoptstate(node)))
                end

                nodestate = getoptstate(node)

                update_ip_primal_bound!(nodestate, get_ip_primal_bound(sbstate))
                best_ip_primal_sol = get_best_ip_primal_sol(sbstate)
                if exploitsprimalsolutions && best_ip_primal_sol !== nothing
                    set_ip_primal_sol!(nodestate, best_ip_primal_sol)
                end                

                apply_conquer_alg_to_node!(
                    node, current_phase.conquer_algo, env, reform, conquer_units_to_restore
                )        

                add_ip_primal_sols!(sbstate, get_ip_primal_sols(nodestate)...)
                    
                if to_be_pruned(node) 
                    if isverbose(current_phase.conquer_algo)
                        println("Branch is conquered!")
                    end
                end
            end

            if phase_index < length(algo.phases) 
                # not the last phase, thus we compute the product score
                group.score = product_score(group, getoptstate(parent))
            else
                # the last phase, thus we compute the tree size score
                group.score = tree_depth_score(group, getoptstate(parent))
            end
            print_bounds_and_score(group, phase_index, max_descr_length)
        end
        children_generated = true

        sort!(groups, rev = true, by = x -> (x.isconquered, x.score))

        if groups[1].isconquered
            nb_candidates_for_next_phase = 1 
        end

        # before deleting branching groups which are not kept for the next phase
        # we need to remove record kept in these nodes
        for group_index = nb_candidates_for_next_phase + 1 : length(groups) 
            for (node_index, node) in enumerate(groups[group_index].children)
                remove_records!(node.recordids)
            end
        end
        resize!(groups, nb_candidates_for_next_phase)
    end
    return sbstate
end

function run!(algo::StrongBranching, env::Env, reform::Reformulation, input::DivideInput)::DivideOutput
    parent = getparent(input)
    optstate = getoptstate(parent)

    if isempty(algo.rules)
        @logmsg LogLevel(0) "No branching rule is defined. No children will be generated."
        return DivideOutput(Node[], optstate)
    end

    # we obtain the original and extended solutions
    master = getmaster(reform)
    original_solution = nothing
    extended_solution = get_best_lp_primal_sol(optstate)
    if extended_solution !== nothing
        if projection_is_possible(master)
            original_solution = proj_cols_on_rep(extended_solution, master)
        else
            original_solution = get_best_lp_primal_sol(optstate)
        end
    else
        @warn "no LP solution is passed to the branching algorithm. No children will be generated."
        return DivideOutput(Node[], optstate)
    end

    kept_branch_groups = BranchingGroup[]
    parent_is_root = getdepth(parent) == 0

    # we sort branching rules by their root/non-root priority (depending on the node depth)
    sort!(algo.rules, rev = true, by = x -> getpriority(x, parent_is_root))

    # phase 0 of branching : branching rules generates the branching candidates
    # Generation stops when :
    # 1. at least one candidate was generated, and its priority rounded down is stricly greater 
    #   than priorities of not yet considered branching rules
    # 2. all needed candidates were generated and their smallest priority is strictly greater
    #   than priorities of not yet considered branching rules

    max_nb_candidates = 1
    if !isempty(algo.phases)
        max_nb_candidates = algo.phases[1].max_nb_candidates
    end

    local_id = 0
    candidate_priority = getpriority(algo.rules[1], parent_is_root)

    for prioritised_rule in algo.rules
        rule = prioritised_rule.rule

        # priority of the branching rule not considered yet
        priority = getpriority(prioritised_rule, parent_is_root) 
    
        nb_candidates_found = length(kept_branch_groups)

        stop_gen_condition_1 = (nb_candidates_found > 0 && priority < floor(candidate_priority))
        stop_gen_condition_2 = (nb_candidates_found >= max_nb_candidates && priority < candidate_priority)
        if stop_gen_condition_1 || stop_gen_condition_2
            break
        end

        # update candidate priority (because we are going to consider a new branching rule)
        candidate_priority = priority

        # generate candidates
        output = run!(
            rule, env, reform, BranchingRuleInput(
                original_solution, true, max_nb_candidates, algo.selection_criterion, 
                local_id, algo.int_tol, candidate_priority
            )
        )
        append!(kept_branch_groups, output.groups)
        local_id = output.local_id

        if projection_is_possible(master) && extended_solution !== nothing
            output = run!(
                rule, env, reform, BranchingRuleInput(
                    extended_solution, false, max_nb_candidates, algo.selection_criterion, 
                    local_id, algo.int_tol, candidate_priority
                )
            )
            append!(kept_branch_groups, output.groups)
            local_id = output.local_id
        end

        sort_select_candidates!(kept_branch_groups, algo.selection_criterion, max_nb_candidates)
    end

    if isempty(kept_branch_groups)
        @logmsg LogLevel(0) "No branching candidates found. No children will be generated."
        return DivideOutput(Node[], optstate)
    end

    # in the case of simple branching, it remains to generate the children
    if isempty(algo.phases) 
        generate_children!(kept_branch_groups[1], env, reform, parent)
        return DivideOutput(kept_branch_groups[1].children, OptimizationState(getmaster(reform)))
    end

    sbstate = perform_strong_branching_with_phases!(algo, env, reform, input, kept_branch_groups)
    return DivideOutput(kept_branch_groups[1].children, sbstate)
end

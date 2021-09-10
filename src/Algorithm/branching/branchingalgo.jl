"""
    BranchingPhase

    A phase in strong branching. Containts the maximum number of candidates
    to evaluate and the conquer algorithm which does evaluation.
"""

struct BranchingPhase
    max_nb_candidates::Int64
    conquer_algo::AbstractConquerAlgorithm
end

# function ExactBranchingPhase(candidates_num::Int64; conqueralg = ColCutGenConquer())     
#     return BranchingPhase(candidates_num, conqueralg)
# end

# function OnlyRestrictedMasterBranchingPhase(candidates_num::Int64)
#     return BranchingPhase(candidates_num, RestrMasterLPConquer()) 
# end    

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
    NoBranching

    The empty divide algorithm
"""
struct NoBranching <: AbstractDivideAlgorithm
end

function run!(algo::NoBranching, env::Env, reform::Reformulation, input::DivideInput)::DivideOutput
    return DivideOutput([], OptimizationState(getmaster(reform)))
end

"""
    StrongBranching

    The algorithm to perform (strong) branching in a tree search algorithm
    Contains branching phases and branching rules.
    Should be populated by branching rules before execution.
"""
@with_kw struct StrongBranching <: AbstractDivideAlgorithm
    phases::Vector{BranchingPhase} = []
    rules::Vector{PrioritisedBranchingRule} = []
    selection_criterion::SelectionCriterion = MostFractionalCriterion
    int_tol = 1e-6
end

# default parameterisation corresponds to simple branching (no strong branching phases)
function SimpleBranching()::AbstractDivideAlgorithm
    algo = StrongBranching()
    push!(algo.rules, PrioritisedBranchingRule(VarBranchingRule(), 1.0, 1.0))
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
            if phase_index == 1                
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
        return DivideOutput(Vector{Node}(), optstate)
    end

    kept_branch_groups = Vector{BranchingGroup}()
    parent_is_root::Bool = getdepth(parent) == 0

    # first we sort branching rules by their root/non-root priority (depending on the node depth)
    sort!(algo.rules, rev = true, by = x -> getpriority(x, parent_is_root))

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
        return DivideOutput(Vector{Node}(), optstate)
    end

    # phase 0 of branching : we ask branching rules to generate branching candidates
    # we stop when   
    # - at least one candidate was generated, and its priority rounded down is stricly greater 
    #   than priorities of not yet considered branching rules
    # - all needed candidates were generated and their smallest priority is strictly greater
    #   than priorities of not yet considered branching rules
    nb_candidates_needed::Int64 = 1;
    if !isempty(algo.phases)
        nb_candidates_needed = algo.phases[1].max_nb_candidates
    end    
    local_id::Int64 = 0
    min_priority::Float64 = getpriority(algo.rules[1], parent_is_root)
    for prioritised_rule in algo.rules
        rule = prioritised_rule.rule
        # decide whether to stop generating candidates or not
        priority::Float64 = getpriority(prioritised_rule, parent_is_root) 
        nb_candidates_found::Int64 = length(kept_branch_groups)
        if priority < floor(min_priority) && nb_candidates_found > 0
            break
        elseif priority < min_priority && nb_candidates_found >= nb_candidates_needed
            break
        end
        min_priority = priority

        # generate candidates
        output = run!(rule, env, reform, BranchingRuleInput(
            original_solution, true, nb_candidates_needed, algo.selection_criterion, 
            local_id, algo.int_tol, min_priority
        ))
        nb_candidates_found += length(output.groups)
        append!(kept_branch_groups, output.groups)
        local_id = output.local_id

        if projection_is_possible(master) && extended_solution !== nothing
            output = run!(rule, env, reform, BranchingRuleInput(
                extended_solution, false, nb_candidates_needed, algo.selection_criterion, 
                local_id, algo.int_tol, min_priority
            ))   
            nb_candidates_found += length(output.groups)
            append!(kept_branch_groups, output.groups)
            local_id = output.local_id
        end

        # sort branching candidates according to the selection criterion and remove excess ones
        if algo.selection_criterion == FirstFoundCriterion
            sort!(kept_branch_groups, by = x -> x.local_id)
        elseif algo.selection_criterion == MostFractionalCriterion
            sort!(kept_branch_groups, rev = true, by = x -> get_lhs_distance_to_integer(x))
        end
        if length(kept_branch_groups) > nb_candidates_needed
            resize!(kept_branch_groups, nb_candidates_needed)
        end
    end

    if isempty(kept_branch_groups)
        @logmsg LogLevel(0) "No branching candidates found. No children will be generated."
        return DivideOutput(Vector{Node}(), optstate)
    end

    #in the case of simple branching, it remains to generate the children
    if isempty(algo.phases) 
        generate_children!(kept_branch_groups[1], env, reform, parent)
        return DivideOutput(kept_branch_groups[1].children, OptimizationState(getmaster(reform)))
    end

    sbstate = perform_strong_branching_with_phases!(algo, env, reform, input, kept_branch_groups)

    return DivideOutput(kept_branch_groups[1].children, sbstate)
end

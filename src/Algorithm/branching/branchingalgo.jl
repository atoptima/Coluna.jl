"""
    BranchingPhase

    A phase in strong branching. Containts the maximum number of candidates
    to evaluate and the conquer algorithm which does evaluation.
"""

struct BranchingPhase
    max_nb_candidates::Int64
    conquer_algo::AbstractConquerAlgorithm
end

function ExactBranchingPhase(candidates_num::Int64)     
    return BranchingPhase(
        candidates_num, ColGenConquer(
            colgen = ColumnGeneration(max_nb_iterations = typemax(Int64))
        )
    )
end

function OnlyRestrictedMasterBranchingPhase(candidates_num::Int64)
    return BranchingPhase(candidates_num, RestrMasterLPConquer()) 
end    

"""
    PrioritisedBranchingRule

    A branching rule with root and non-root priorities. 
"""

struct PrioritisedBranchingRule
    root_priority::Float64
    nonroot_priority::Float64
    rule::AbstractBranchingRule
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

function run!(algo::NoBranching, reform::Reformulation, input::DivideInput)::DivideOutput
    parent = getparent(input)
    parent_incumb = getincumbents(parent)
    result = OptimizationState(getmaster(reform))
    return DivideOutput([], result)
end


"""
    StrongBranching

    The algorithm to perform (strong) branching in a tree search algorithm
    Contains branching phases and branching rules.
    Should be populated by branching rules before execution.
"""
Base.@kwdef struct StrongBranching <: AbstractDivideAlgorithm
    phases::Vector{BranchingPhase} = []
    rules::Vector{PrioritisedBranchingRule} = []
    selection_criterion::SelectionCriterion = MostFractionalCriterion
end

# default parameterisation corresponds to simple branching (no strong branching phases)
function SimpleBranching()::AbstractDivideAlgorithm
    algo = StrongBranching()
    push!(algo.rules, PrioritisedBranchingRule(1.0, 1.0, VarBranchingRule()))
    return algo
end

function getslavealgorithms!(
    algo::StrongBranching, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}
)
    for phase in algo.phases
        push!(slaves, (reform, typeof(phase.conquer_algo)))
        getslavealgorithms!(phase.conquer_algo, reform, slaves)
    end
    for prioritised_rule in algo.rules
        push!(slaves, (reform, typeof(prioritised_rule.rule)))
        getslavealgorithms!(prioritised_rule.rule, reform, slaves)
    end
end

function perform_strong_branching_with_phases!(
    algo::StrongBranching, reform::Reformulation, parent::Node, 
    groups::Vector{BranchingGroup}, result::OptimizationState
)
    for (phase_index, current_phase) in enumerate(algo.phases)
        nb_candidates_for_next_phase::Int64 = 1        
        if phase_index < length(algo.phases)
            nb_candidates_for_next_phase = algo.phases[phase_index + 1].max_nb_candidates
            if length(groups) <= nb_candidates_for_next_phase 
                continue
            end
        end        

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

        a_candidate_is_conquered::Bool = false    
        for (group_index,group) in enumerate(groups)
            #TO DO: verify if time limit is reached

            if phase_index == 1
                generate_children!(group, reform, parent)
            else    
                regenerate_children!(group, reform, parent)
            end
                        
            if phase_index > 1
                sort!(group.children, by =  x -> get_lp_primal_bound(getincumbents(x)))
            end
            
            pruned_nodes_indices = Vector{Int64}()            
            for (node_index, node) in enumerate(group.children)
                if isverbose(current_phase.conquer_algo)
                    print(
                        "**** SB phase ", phase_index, " evaluation of candidate ", 
                        group_index, " (branch ", node_index, node.branchdescription
                    )
                    @printf "), value = %6.2f\n" getvalue(get_lp_primal_bound(getincumbents(node)))
                end

                optoutput = apply_conquer_alg_to_node!(
                    node, current_phase.conquer_algo, reform, result
                )        

                if to_be_pruned(node) 
                    if isverbose(current_phase.conquer_algo)
                        println("Branch is conquered!")
                    end
                    push!(pruned_nodes_indices, node_index)
                end
            end

            # TO CHECK : Should we do this???
            #update_father_dual_bound!(group, parent)

            deleteat!(group.children, pruned_nodes_indices)

            if isempty(group.children)
                setconquered!(group)
                if isverbose(current_phase.conquer_algo)
                    println("SB phase ", phase_index, " candidate ", group_index, " is conquered !")
                end    
                break
            end

            if phase_index < length(algo.phases) 
                # not the last phase, thus we compute the product score
                compute_product_score!(group, getincumbents(parent))
            else    
                # the last phase, thus we compute the tree size score
                compute_tree_depth_score!(group, getincumbents(parent))
            end
            print_bounds_and_score(group, phase_index, max_descr_length)
        end

        sort!(groups, rev = true, by = x -> (x.isconquered, x.score))

        if groups[1].isconquered
            nb_candidates_for_next_phase == 1 
        end

        resize!(groups, nb_candidates_for_next_phase)
    end
    return
end

function run!(algo::StrongBranching, reform::Reformulation, input::DivideInput)::DivideOutput
    parent = getparent(input)
    parent_incumb_res = getincumbentresult(parent)
    result = OptimizationState(getmaster(reform))
    set_ip_primal_bound!(result, input.ip_primal_bound)
    set_ip_dual_bound!(result, get_ip_dual_bound(parent_incumb_res))
    if isempty(algo.rules)
        @logmsg LogLevel(1) "No branching rule is defined. No children will be generated."
        return DivideOutput([], result)
    end

    kept_branch_groups = Vector{BranchingGroup}()
    parent_is_root::Bool = getdepth(parent) == 0

    # first we sort branching rules by their root/non-root priority (depending on the node depth)
    sort!(algo.rules, rev = true, by = x -> getpriority(x, parent_is_root))

    # we obtain the original and extended solutions
    master = getmaster(reform)
    original_solution = PrimalSolution(getmaster(reform))
    extended_solution = PrimalSolution(getmaster(reform))
    if nb_lp_primal_sols(parent_incumb_res) > 0
        if projection_is_possible(master)
            extended_solution = get_best_lp_primal_sol(parent_incumb_res)
            original_solution = proj_cols_on_rep(extended_solution, master)
        else
            original_solution = get_best_lp_primal_sol(parent_incumb_res)
        end
    else
        @logmsg LogLevel(1) "No branching candidates found. No children will be generated."
        return DivideOutput(Vector{Node}(), result)
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
        output = run!(rule, reform, BranchingRuleInput(
            original_solution, true, nb_candidates_needed, algo.selection_criterion, local_id
        ))
        nb_candidates_found += length(output.groups)
        append!(kept_branch_groups, output.groups)
        local_id = output.local_id

        if projection_is_possible(master)
            output = run!(rule, reform, BranchingRuleInput(
                extended_solution, false, nb_candidates_needed, algo.selection_criterion, local_id
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
        @logmsg LogLevel(1) "No branching candidates found. No children will be generated."
        return DivideOutput(Vector{Node}(), result)
    end

    if isempty(algo.phases) 
        #in the case of simple branching, it remains to generate the children
        generate_children!(kept_branch_groups[1], reform, parent)
    else
        perform_strong_branching_with_phases!(algo, reform, parent, kept_branch_groups, result)
    end

    return DivideOutput(kept_branch_groups[1].children, result)
end

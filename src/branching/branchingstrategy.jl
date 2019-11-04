"""
    BranchingPhase

    Contains parameters to determing what will be done in a branching phase
"""

struct BranchingPhase
    max_nb_candidates::Int64
    conquer_strategy::AbstractConquerStrategy
end

function exact_branching_phase(candidates_num::Int64)     
    return BranchingPhase(candidates_num, SimpleBnP(
            colgen = ColumnGeneration(max_nb_iterations = typemax(Int64))
        ))
end

function only_restricted_master_branching_phase(candidates_num::Int64)
    return BranchingPhase(candidates_num, RestrictedMasterResolve()) 
end    


"""
    BranchingStrategy

    The strategy to perform (strong) branching in a branch-and-bound algorithm
    Contains branching phases parameterisation and selection criterion
    Should be populated by branching rules before branch-and-bound execution
"""
Base.@kwdef struct BranchingStrategy <: AbstractDivideStrategy
    # default parameterisation corresponds to simple branching (no strong branching phases)
    strong_branching_phases::Vector{BranchingPhase} = []
    selection_criterion::SelectionCriterion = MostFractionalCriterion
    branching_rules::Vector{AbstractBranchingRule} = []
end

function SimpleBranching()
    strategy = BranchingStrategy()
    push!(strategy.branching_rules, VarBranchingRule())
    return strategy
end

function prepare!(strategy::BranchingStrategy, reform::Reformulation)

    #TO DO : here we need to verify whether branching phases are well set
    #for example, that the max_nb_iterations is not decreasing, etc

    for rule in strategy.branching_rules
        prepare!(rule, reform)
    end
    return
end

function perform_strong_branching_with_phases!(
    phases::Vector{BranchingPhase}, reform::Reformulation, parent::Node, 
    groups::Vector{BranchingGroup}
)
    for (phase_index, current_phase) in enumerate(phases)
        nb_candidates_for_next_phase::Int64 = 1        
        if phase_index < length(phases)
            nb_candidates_for_next_phase = phases[phase_index + 1].max_nb_candidates
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

            if (phase_index == 1)
                generate_children!(group, reform, parent)
            else    
                regenerate_children!(group, reform, parent)
            end
                        
            if phase_index > 1
                sort!(group.children, by =  x -> get_lp_primal_bound(getincumbents(x)))
            end
            
            pruned_nodes_indices = Vector{Int64}()            
            for (node_index, node) in enumerate(group.children)
                if isverbose(current_phase.conquer_strategy)
                    print(
                        "**** SB phase ", phase_index, " evaluation of candidate ", 
                        group_index, " (branch ", node_index, node.branchdescription
                    )
                    @printf "), value = %6.2f\n" getvalue(get_lp_primal_bound(getincumbents(node)))
                end

                # we update the best integer solution of the node 
                # (it might have been changed since the node has been created)    
                update_ip_primal_sol!(getincumbents(node), get_ip_primal_sol(getincumbents(parent)))

                # we apply the conquer strategy of the current branching phase on the current node
                reset_to_record_state!(reform, node.record) # TO DO : remove _of_father from this name
                apply_branch!(reform, getbranch(node))
                apply!(current_phase.conquer_strategy, reform, node)
                record!(reform, node)
                update_ip_primal_sol!(getincumbents(parent), get_ip_primal_sol(getincumbents(node)))            

                if to_be_pruned(node) 
                    if isverbose(current_phase.conquer_strategy)
                        println("Branch is conquered!")
                    end
                    push!(pruned_nodes_indices, node_index)
                end
            end

            update_father_dual_bound!(group, parent)

            deleteat!(group.children, pruned_nodes_indices)

            if isempty(group.children)
                setconquered!(group)
                if isverbose(current_phase.conquer_strategy)
                    println(" SB phase ", phase_index, " candidate ", group_index, " is conquered !")
                end    
                break
            end

            if phase_index < length(phases) 
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

function apply!(strategy::BranchingStrategy, reform::Reformulation, parent::Node)
    if isempty(strategy.branching_rules)
        @logmsg LogLevel(0) "No branching rule is defined. No children will be generated."
        return
    end

    kept_branch_groups = Vector{BranchingGroup}()
    parent_is_root::Bool = getdepth(parent) == 0

    # first we sort branching rules by their root/non-root priority (depending on the node depth)
    if parent_is_root
        sort!(strategy.branching_rules, rev = true, by = x -> getrootpriority(x))
    else  
        sort!(strategy.branching_rules, rev = true, by = x -> getnonrootpriority(x))
    end

    # we obtain the original and extended solutions
    master = getmaster(reform)
    original_solution = PrimalSolution{getobjsense(master)}()
    extended_solution = PrimalSolution{getobjsense(master)}()
    if projection_is_possible(master)
        extended_solution = get_lp_primal_sol(parent.incumbents)
        original_solution = proj_cols_on_rep(extended_solution, master)
    else
        original_solution = get_lp_primal_sol(parent.incumbents)
    end

    # phase 0 of branching : we ask branching rules to generate branching candidates
    # we stop when   
    # - at least one candidate was generated, and its priority rounded down is stricly greater 
    #   than priorities of not yet considered branching rules
    # - all needed candidates were generated and their smallest priority is strictly greater
    #   than priorities of not yet considered branching rules
    nb_candidates_needed::Int64 = 1;
    if !isempty(strategy.strong_branching_phases)
        nb_candidates_needed = strategy.strong_branching_phases[1].max_nb_candidates
    end    
    local_id::Int64 = 0
    min_priority::Float64 = getpriority(strategy.branching_rules[1], parent_is_root)
    for rule in strategy.branching_rules
        # decide whether to stop generating candidates or not
        priority::Float64 = getpriority(rule, parent_is_root) 
        nb_candidates_found::Int64 = length(kept_branch_groups)
        if priority < floor(min_priority) && nb_candidates_found > 0
            break
        elseif priority < min_priority && nb_candidates_found >= nb_candidates_needed
            break
        end
        min_priority = priority

        # generate candidates
        branch_groups = Vector{BranchingGroup}()
        local_id, branch_groups = gen_candidates_for_orig_sol(rule, reform, original_solution, nb_candidates_needed, 
                                                              local_id, strategy.selection_criterion)
        nb_candidates_found += length(branch_groups)
        append!(kept_branch_groups, branch_groups)
                                
        if projection_is_possible(master)
            local_id, branch_groups = gen_candidates_for_ext_sol(rule, reform, extended_solution, nb_candidates_needed, 
                                                                 local_id, strategy.selection_criterion)
            nb_candidates_found += length(branch_groups)
            append!(kept_branch_groups, branch_groups)
        end

        # sort branching candidates according to the selection criterion and remove excess ones
        if strategy.selection_criterion == FirstFoundCriterion
            sort!(kept_branch_groups, by = x -> x.local_id)
        elseif strategy.selection_criterion == MostFractionalCriterion    
            sort!(kept_branch_groups, rev = true, by = x -> get_lhs_distance_to_integer(x))
        end
        if length(kept_branch_groups) > nb_candidates_needed
            resize!(kept_branch_groups, nb_candidates_needed)
        end
    end
    
    if isempty(kept_branch_groups)
        @logmsg LogLevel(0) "No branching candidates found. No children will be generated."
        return
    end

    if isempty(strategy.strong_branching_phases) 
        #in the case of simple branching, it remains to generate the children
        generate_children!(kept_branch_groups[1], reform, parent)
    else
        perform_strong_branching_with_phases!(strategy.strong_branching_phases, reform, parent, kept_branch_groups)
    end

    parent.children = kept_branch_groups[1].children

    return
end

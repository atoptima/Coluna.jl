
############################################################################################
# SingleVarBranchingRule
############################################################################################

"""
    SingleVarBranchingRule

This branching rule allows the divide algorithm to branch on single integer variables.
For instance, `SingleVarBranchingRule` can produce the branching `x <= 2` and `x >= 3` 
where `x` is a scalar integer variable.
"""
struct SingleVarBranchingRule <: AbstractBranchingRule end

# SingleVarBranchingRule does not have child algorithms

function get_units_usage(::SingleVarBranchingRule, reform::Reformulation) 
    return [(getmaster(reform), MasterBranchConstrsUnit, READ_AND_WRITE)] 
end

function run!(
    ::SingleVarBranchingRule, env::Env, reform::Reformulation, input::BranchingRuleInput
)::BranchingRuleOutput
    # variable branching works only for the original solution
    if !input.isoriginalsol
        return BranchingRuleOutput(input.local_id, [])
    end

    master = getmaster(reform)
    local_id = input.local_id
    max_priority = -Inf
    for (var_id, val) in input.solution
        continuous_var = getperenkind(master, var_id) == Continuous
        int_val = abs(round(val) - val) < input.int_tol
        # Do not consider continuous variables as branching candidates
        # and variables with integer value in the current solution.
        if !continuous_var && !int_val
            br_priority = getbranchingpriority(master, var_id)
            if max_priority < br_priority
                max_priority = br_priority
            end
        end
    end

    if max_priority == -Inf    
        return BranchingRuleOutput(local_id, [])
    end

    groups = SingleVarBranchingCandidate[]
    for (var_id, val) in input.solution
        continuous_var = getperenkind(master, var_id) == Continuous
        int_val = abs(round(val) - val) < input.int_tol
        br_priority = getbranchingpriority(master, var_id)
        if !continuous_var && !int_val && br_priority == max_priority
            # Description string of the candidate is the variable name
            local_id += 1
            candidate = SingleVarBranchingCandidate(getname(master, var_id), var_id, local_id, val)
            push!(groups, candidate)
        end
    end

    select_candidates!(groups, input.criterion, input.max_nb_candidates)

    return BranchingRuleOutput(local_id, groups)
end

############################################################################################
# SingleVarBranchingCandidate
############################################################################################

"""
    SingleVarBranchingCandidate

It is an implementation of AbstractBranchingCandidate.
This is the type of branching candidates produced by the branching rule 
`SingleVarBranchingRule`.
"""
struct SingleVarBranchingCandidate <: AbstractBranchingCandidate
    varname::String
    varid::VarId
end

getdescription(candidate::SingleVarBranchingCandidate) = candidate.varname

function generate_children(
    candidate::SingleVarBranchingCandidate, lhs::Float64, env::Env, reform::Reformulation, 
    parent::Node
)
    master = getmaster(reform)

    @logmsg LogLevel(-1) string(
        "Chosen branching variable : ",
        getname(master, candidate.varid), " with value ", lhs, "."
    )

    units_to_restore = UnitsUsage()
    set_permission!(
        units_to_restore,
        getstoragewrapper(master, MasterBranchConstrsUnit),
        READ_AND_WRITE
    )

    # adding the first branching constraints
    restore_from_records!(units_to_restore, copy_records(parent.recordids))    
    TO.@timeit Coluna._to "Add branching constraint" begin
    setconstr!(
        master, string(
            "branch_geq_", getdepth(parent), "_", getname(master,candidate.varid)
        ), MasterBranchOnOrigVarConstr;
        sense = Greater, rhs = ceil(lhs), loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    end
    child1description = candidate.varname * ">=" * string(ceil(lhs))
    child1 = Node(master, parent, child1description, store_records!(reform))

    # adding the second branching constraints
    restore_from_records!(units_to_restore, copy_records(parent.recordids))
    TO.@timeit Coluna._to "Add branching constraint" begin
    setconstr!(
        master, string(
            "branch_leq_", getdepth(parent), "_", getname(master,candidate.varid)
        ), MasterBranchOnOrigVarConstr;
        sense = Less, rhs = floor(lhs), 
        loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    end
    child2description = candidate.varname * "<=" * string(floor(lhs))
    child2 = Node(master, parent, child2description, store_records!(reform))

    return [child1, child2]
end

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
        return BranchingRuleOutput(input.local_id, BranchingGroup[])
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
        return BranchingRuleOutput(local_id, BranchingGroup[])
    end

    groups = BranchingGroup[]
    for (var_id, val) in input.solution
        continuous_var = getperenkind(master, var_id) == Continuous
        int_val = abs(round(val) - val) < input.int_tol
        br_priority = getbranchingpriority(master, var_id)
        if !continuous_var && !int_val && br_priority == max_priority
            # Description string of the candidate is the variable name
            candidate = SingleVarBranchingCandidate(getname(master, var_id), var_id)
            local_id += 1
            push!(groups, BranchingGroup(candidate, local_id, val))
        end
    end

    select_candidates!(groups, input.criterion, input.max_nb_candidates)

    return BranchingRuleOutput(local_id, groups)
end

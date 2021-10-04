"""
    VarBranchingCandidate

    Contains a variable on which we branch
"""
struct VarBranchingCandidate <: AbstractBranchingCandidate
    description::String
    varid::VarId
end

getdescription(candidate::VarBranchingCandidate) = candidate.description

function generate_children(
    candidate::VarBranchingCandidate, lhs::Float64, env::Env, reform::Reformulation, parent::Node
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

    #adding the first branching constraints
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
    child1description = candidate.description * ">=" * string(ceil(lhs))
    child1 = Node(master, parent, child1description, store_records!(reform))

    #adding the second branching constraints
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
    child2description = candidate.description * "<=" * string(floor(lhs))
    child2 = Node(master, parent, child2description, store_records!(reform))

    return [child1, child2]
end

"""
    VarBranchingRule

    Branching on variables
    For the moment, we branch on all integer variables
    In the future, a VarBranchingRule could be defined for a subset of integer variables
    in order to be able to give different priorities to different groups of variables
"""
struct VarBranchingRule <: AbstractBranchingRule
end

# VarBranchingRule does not have child algorithms

function get_units_usage(algo::VarBranchingRule, reform::Reformulation) 
    return [(getmaster(reform), MasterBranchConstrsUnit, READ_AND_WRITE)] 
end

function run!(
    rule::VarBranchingRule, env::Env, reform::Reformulation, input::BranchingRuleInput
)::BranchingRuleOutput
    # variable branching works only for the original solution
    !input.isoriginalsol && return BranchingRuleOutput(input.local_id, Vector{BranchingGroup}())

    master = getmaster(reform)
    local_id = input.local_id
    max_priority = -Inf
    for (var_id, val) in input.solution
        # Do not consider continuous variables as branching candidates
        getperenkind(master, var_id) == Continuous && continue
        if !isinteger(val, input.int_tol)
            brpriority = getbranchingpriority(master, var_id)
            if max_priority < brpriority
                max_priority = brpriority
            end
        end
    end

    if max_priority == -Inf    
        return BranchingRuleOutput(local_id, BranchingGroup[])
    end

    selected_vars = Pair{VarId, Float64}[]
    for (var_id, val) in input.solution
        getperenkind(master, var_id) == Continuous && continue
        if !isinteger(val, input.int_tol) && getbranchingpriority(master, var_id) == max_priority
            push!(selected_vars, Pair{VarId, Float64}(var_id, val))
        end
    end

    groups = BranchingGroup[]
    for (var_id, val) in selected_vars
        #description string is just the variable name
        candidate = VarBranchingCandidate(getname(master, var_id), var_id)
        local_id += 1
        push!(groups, BranchingGroup(candidate, local_id, val))
    end

    if input.criterion == FirstFoundCriterion
        sort!(groups, by = x -> x.local_id)
    elseif input.criterion == MostFractionalCriterion
        sort!(groups, rev = true, by = x -> get_lhs_distance_to_integer(x))
    end

    if length(groups) > input.max_nb_candidates
        resize!(groups, input.max_nb_candidates)
    end

    return BranchingRuleOutput(local_id, groups)
end

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
    candidate::VarBranchingCandidate, lhs::Float64, data::ReformData,
    parent::Node, stateids::StorageStatesVector, first_restore_states::Bool
)
    master = getmaster(getreform(data))
    var = getvar(master, candidate.varid)

    @logmsg LogLevel(-1) string(
        "Chosen branching variable : ",
        getname(master, candidate.varid), " with value ", lhs, "."
    )

    storages_to_restore = StoragesToRestoreDict(
        (master, MasterBranchConstrsStoragePair) => READ_AND_WRITE
        #(master, BasisStorage) => READ_AND_WRITE) # not yet implemented
    )

    #adding the first branching constraints
    if first_restore_states
        restore_states!(copy_states(stateids), storages_to_restore)
    else
        reserve_for_writing!(getmasterdata(data), MasterBranchConstrsStoragePair)
    end

    #reserve_for_writing!(getmasterdata(data), BasisStorage) # not yet implemented
    TO.@timeit Coluna._to "Add branching constraint" begin
    setconstr!(
        master, string("branch_geq_", getdepth(parent)), MasterBranchOnOrigVarConstr;
        sense = Greater, rhs = ceil(lhs), loc_art_var = true,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    end
    child1description = candidate.description * ">=" * string(ceil(lhs))
    child1 = Node(master, parent, child1description, store_states!(data))

    #adding the second branching constraints
    restore_states!(stateids, storages_to_restore)
    TO.@timeit Coluna._to "Add branching constraint" begin
    setconstr!(
        master, string("branch_leq_", getdepth(parent)), MasterBranchOnOrigVarConstr;
        sense = Less, rhs = floor(lhs), loc_art_var = true,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    end
    child2description = candidate.description * "<=" * string(floor(lhs))
    child2 = Node(master, parent, child2description, store_states!(data))

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

# VarBranchingRule does not have slave algorithms

function get_storages_usage(algo::VarBranchingRule, reform::Reformulation) 
    return [(getmaster(reform), MasterBranchConstrsStoragePair, READ_AND_WRITE)] 
end

function run!(
    rule::VarBranchingRule, data::ReformData, input::BranchingRuleInput
)::BranchingRuleOutput
    # variable branching works only for the original solution
    !input.isoriginalsol && return BranchingRuleOutput(input.local_id, Vector{BranchingGroup}())

    master = getmaster(getreform(data))
    groups = Vector{BranchingGroup}()
    local_id = input.local_id
    for (var_id, val) in input.solution
        # Do not consider continuous variables as branching candidates
        getperenkind(master, var_id) == Continuous && continue
        if !isinteger(val, input.int_tol)
            #description string is just the variable name
            candidate = VarBranchingCandidate(getname(master, var_id), var_id)
            local_id += 1
            push!(groups, BranchingGroup(candidate, local_id, val))
        end
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

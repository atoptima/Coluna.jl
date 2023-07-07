############################################################################################
# SingleVarBranchingCandidate
############################################################################################
"""
    SingleVarBranchingCandidate

It is an implementation of AbstractBranchingCandidate.
This is the type of branching candidates produced by the branching rule 
`SingleVarBranchingRule`.
"""
mutable struct SingleVarBranchingCandidate <: Branching.AbstractBranchingCandidate
    varname::String
    varid::VarId
    local_id::Int64
    lhs::Float64
    score::Float64
    children::Vector{SbNode}
    isconquered::Bool
    function SingleVarBranchingCandidate(
        varname::String, varid::VarId, local_id::Int64, lhs::Float64
    )
        return new(varname, varid, local_id, lhs, 0.0, SbNode[], false)
    end
end

Branching.getdescription(candidate::SingleVarBranchingCandidate) = candidate.varname
Branching.get_lhs(candidate::SingleVarBranchingCandidate) = candidate.lhs
Branching.get_local_id(candidate::SingleVarBranchingCandidate) = candidate.local_id
Branching.get_children(candidate::SingleVarBranchingCandidate) = candidate.children
Branching.set_children!(candidate::SingleVarBranchingCandidate, children) = candidate.children = children

function get_branching_candidate_units_usage(::SingleVarBranchingCandidate, reform)
    units_to_restore = UnitsUsage()
    master = getmaster(reform)
    push!(units_to_restore.units_used, (master, MasterBranchConstrsUnit))
    return units_to_restore
end

function Branching.generate_children!(
    candidate::SingleVarBranchingCandidate, env::Env, reform::Reformulation, input
)
    master = getmaster(reform)
    lhs = Branching.get_lhs(candidate)

    @logmsg LogLevel(-1) string(
        "Chosen branching variable : ",
        getname(master, candidate.varid), " with value ", lhs, "."
    )

    units_to_restore = get_branching_candidate_units_usage(candidate, reform)
    d = Branching.get_parent_depth(input)

    # adding the first branching constraints
    restore_from_records!(units_to_restore, Branching.parent_records(input))
    setconstr!(
        master, 
        string("branch_geq_", d, "_", getname(master,candidate.varid)),
        MasterBranchOnOrigVarConstr;
        sense = Greater,
        rhs = ceil(lhs),
        loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    child1description = candidate.varname * ">=" * string(ceil(lhs))
    child1 = SbNode(reform, d+1, candidate.varname, child1description, create_records(reform), input)

    # adding the second branching constraints
    restore_from_records!(units_to_restore, Branching.parent_records(input))
    setconstr!(
        master,
        string("branch_leq_", d, "_", getname(master,candidate.varid)),
        MasterBranchOnOrigVarConstr;
        sense = Less,
        rhs = floor(lhs), 
        loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    child2description = candidate.varname * "<=" * string(floor(lhs))
    child2 = SbNode(reform, d+1, candidate.varname, child2description, create_records(reform), input)

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
struct SingleVarBranchingRule <: Branching.AbstractBranchingRule end

# SingleVarBranchingRule does not have child algorithms

function get_units_usage(::SingleVarBranchingRule, reform::Reformulation) 
    return [(getmaster(reform), MasterBranchConstrsUnit, READ_AND_WRITE)] 
end

# TODO : unit tests (especially branching priority).
function Branching.apply_branching_rule(::SingleVarBranchingRule, env::Env, reform::Reformulation, input::Branching.BranchingRuleInput)
    # Single variable branching works only for the original solution.
    if !input.isoriginalsol
        return SingleVarBranchingCandidate[]
    end

    master = getmaster(reform)

    # We do not consider continuous variables and variables with integer value in the
    # current solution as branching candidates.
    candidate_vars = Iterators.filter(
        ((var_id, val),) -> !is_cont_var(master, var_id) && !is_int_val(val, input.int_tol),
        input.solution
    )

    max_priority = mapreduce(
        ((var_id, _),) -> getbranchingpriority(master, var_id),
        max,
        candidate_vars;
        init = -Inf
    )

    if max_priority == -Inf    
        return SingleVarBranchingCandidate[]
    end

    # We select all the variables that have the maximum branching prority.
    candidates = reduce(
        candidate_vars; init = SingleVarBranchingCandidate[]
    ) do collection, (var_id, val)
        br_priority = getbranchingpriority(master, var_id)
        if br_priority == max_priority
            name = getname(master, var_id)
            local_id = input.local_id + length(collection) + 1
            candidate = SingleVarBranchingCandidate(name, var_id, local_id, val)
            push!(collection, candidate)
        end
        return collection
    end
    return candidates
end
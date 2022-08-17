############################################################################################
# SingleVarBranchingCandidate
############################################################################################
"""
    SingleVarBranchingCandidate

It is an implementation of AbstractBranchingCandidate.
This is the type of branching candidates produced by the branching rule 
`SingleVarBranchingRule`.
"""
mutable struct SingleVarBranchingCandidate <: AbstractBranchingCandidate
    varname::String
    varid::VarId
    local_id::Int64
    lhs::Float64
    score::Float64
    children::Vector{SbNode}
    isconquered::Bool
    parent::Union{Nothing,Node}
    function SingleVarBranchingCandidate(varname::String, varid::VarId, local_id::Int64, lhs::Float64, parent)
        return new(varname, varid, local_id, lhs, 0.0, SbNode[], false, parent)
    end
end

getdescription(candidate::SingleVarBranchingCandidate) = candidate.varname

get_lhs(candidate::SingleVarBranchingCandidate) = candidate.lhs

function get_lhs_distance_to_integer(candidate::SingleVarBranchingCandidate)
    lhs = get_lhs(candidate)
    return min(lhs - floor(lhs), ceil(lhs) - lhs)
end

get_local_id(candidate::SingleVarBranchingCandidate) = candidate.local_id

get_children(candidate::SingleVarBranchingCandidate) = candidate.children
set_children!(candidate::SingleVarBranchingCandidate, children::Vector{SbNode}) = candidate.children = children
get_parent(candidate::SingleVarBranchingCandidate) = candidate.parent

function generate_children!(
    candidate::SingleVarBranchingCandidate, env::Env, reform::Reformulation, 
    parent::Node
)
    master = getmaster(reform)
    lhs = get_lhs(candidate)

    @logmsg LogLevel(-1) string(
        "Chosen branching variable : ",
        getname(master, candidate.varid), " with value ", lhs, "."
    )

    units_to_restore = UnitsUsage()
    push!(units_to_restore.units_used, (master, MasterBranchConstrsUnit))

    # adding the first branching constraints
    restore_from_records!(units_to_restore, parent.records)
    setconstr!(
        master, string(
            "branch_geq_", getdepth(parent), "_", getname(master,candidate.varid)
        ), MasterBranchOnOrigVarConstr;
        sense = Greater, rhs = ceil(lhs), loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    child1description = candidate.varname * ">=" * string(ceil(lhs))
    child1 = SbNode(master, parent, child1description, create_records(reform))

    # adding the second branching constraints
    restore_from_records!(units_to_restore, parent.records)
    setconstr!(
        master, string(
            "branch_leq_", getdepth(parent), "_", getname(master,candidate.varid)
        ), MasterBranchOnOrigVarConstr;
        sense = Less, rhs = floor(lhs), 
        loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    child2description = candidate.varname * "<=" * string(floor(lhs))
    child2 = SbNode(master, parent, child2description, create_records(reform))

    return [child1, child2]
end

function print_bounds_and_score(
    candidate::SingleVarBranchingCandidate, phase_index::Int64, max_description_length::Int64, score
)
    lhs = get_lhs(candidate)
    lengthdiff = max_description_length - length(getdescription(candidate))
    print("SB phase ", phase_index, " branch on ", getdescription(candidate))
    @printf " (lhs=%.4f)" lhs
    print(repeat(" ", lengthdiff), " : [")
    for (node_index, node) in enumerate(candidate.children)
        node_index > 1 && print(",")            
        @printf "%10.4f" getvalue(get_lp_primal_bound(getoptstate(node)))
    end
    @printf "], score = %10.4f\n" score
    return
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

# TODO : unit tests (especially branching priority).
function apply_branching_rule(::SingleVarBranchingRule, env::Env, reform::Reformulation, input::BranchingRuleInput)
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
            candidate = SingleVarBranchingCandidate(name, var_id, local_id, val, input.parent)
            push!(collection, candidate)
        end
        return collection
    end
    return candidates
end
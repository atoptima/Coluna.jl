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
    function SingleVarBranchingCandidate(varname::String, varid::VarId, local_id::Int64, lhs::Float64)
        return new(varname, varid, local_id, lhs, 0.0, SbNode[], false)
    end
end

getdescription(candidate::SingleVarBranchingCandidate) = candidate.varname

get_lhs(candidate::SingleVarBranchingCandidate) = candidate.lhs

function get_lhs_distance_to_integer(candidate::SingleVarBranchingCandidate)
    lhs = get_lhs(candidate)
    return min(lhs - floor(lhs), ceil(lhs) - lhs)
end

get_local_id(candidate::SingleVarBranchingCandidate) = candidate.local_id


# TODO : it does not look like a regeneration but more like a new vector where we
# reassign children
function regenerate_children!(candidate::SingleVarBranchingCandidate, parent::Node)
    new_children = SbNode[]
    for child in candidate.children
        push!(new_children, SbNode(parent, child))
    end
    candidate.children = new_children
    return
end

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
    set_permission!(
        units_to_restore,
        getstoragewrapper(master, MasterBranchConstrsUnit),
        READ_AND_WRITE
    )

    # adding the first branching constraints
    restore_from_records!(units_to_restore, copy_records(parent.recordids))    
    setconstr!(
        master, string(
            "branch_geq_", getdepth(parent), "_", getname(master,candidate.varid)
        ), MasterBranchOnOrigVarConstr;
        sense = Greater, rhs = ceil(lhs), loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    child1description = candidate.varname * ">=" * string(ceil(lhs))
    child1 = SbNode(master, parent, child1description, store_records!(reform))

    # adding the second branching constraints
    restore_from_records!(units_to_restore, copy_records(parent.recordids))
    setconstr!(
        master, string(
            "branch_leq_", getdepth(parent), "_", getname(master,candidate.varid)
        ), MasterBranchOnOrigVarConstr;
        sense = Less, rhs = floor(lhs), 
        loc_art_var_abs_cost = env.params.local_art_var_cost,
        members = Dict{VarId,Float64}(candidate.varid => 1.0)
    )
    child2description = candidate.varname * "<=" * string(floor(lhs))
    child2 = SbNode(master, parent, child2description, store_records!(reform))

    candidate.children = [child1, child2] # TODO: remove.
    return [child1, child2]
end

function print_bounds_and_score(candidate::SingleVarBranchingCandidate, phase_index::Int64, max_description_length::Int64)
    lhs = get_lhs(candidate)
    lengthdiff = max_description_length - length(getdescription(candidate))
    print("SB phase ", phase_index, " branch on ", getdescription(candidate))
    @printf " (lhs=%.4f)" lhs
    print(repeat(" ", lengthdiff), " : [")
    for (node_index, node) in enumerate(candidate.children)
        node_index > 1 && print(",")            
        @printf "%10.4f" getvalue(get_lp_primal_bound(getoptstate(node)))
    end
    @printf "], score = %10.4f\n" candidate.score
    return
end

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
    child1 = SbNode(master, parent, child1description, store_records!(reform))

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
    child2 = SbNode(master, parent, child2description, store_records!(reform))

    return [child1, child2]
end


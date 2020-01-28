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
    candidate::VarBranchingCandidate, lhs::Float64, reform::Reformulation, 
    node::Node
)
    var = getvar(reform.master, candidate.varid)

    @logmsg LogLevel(-1) string(
        "Chosen branching variable : ",
        getname(getmaster(reform), candidate.var_id), ". With value ", 
        lhs, "."
    )

    child1description = candidate.description * ">=" * string(ceil(lhs))                               
    child1 = Node(node, Branch(var, ceil(lhs), Greater, getdepth(node)), 
                  child1description)
    child2description = candidate.description * "<=" * string(floor(lhs))                               
    child2 = Node(node, Branch(var, floor(lhs), Less, getdepth(node)),
                  child2description)
    return [child1, child2]
end

"""
    VarBranchingRule 

    Branching on variables
    For the moment, we branch on all integer variables
    In the future, a VarBranchingRule could be defined for a subset of integer variables
    in order to be able to give different priorities to different groups of variables
"""
Base.@kwdef struct VarBranchingRule <: AbstractBranchingRule 
    root_priority::Float64 = 1.0
    nonroot_priority::Float64 = 1.0
end

getrootpriority(rule::VarBranchingRule) = rule.root_priority
getnonrootpriority(rule::VarBranchingRule) = rule.nonroot_priority

function gen_candidates_for_orig_sol(
    rule::VarBranchingRule, reform::Reformulation, sol::PrimalSolution{Sense}, 
    max_nb_candidates::Int64, local_id::Int64, criterion::SelectionCriterion
) where Sense
    master = getmaster(reform)
    groups = Vector{BranchingGroup}()
    for (varid, val) in sol
        # Do not consider continuous variables as branching candidates
        getperenekind(master, varid) == Continuous && continue
        if !isinteger(val)
            #description string is just the variable name
            candidate = VarBranchingCandidate(getname(master, varid), varid)
            local_id += 1 
            push!(groups, BranchingGroup(candidate, local_id, val))
        end
    end

    if criterion == FirstFoundCriterion
        sort!(groups, by = x -> x.local_id)
    elseif criterion == MostFractionalCriterion    
        sort!(groups, rev = true, by = x -> get_lhs_distance_to_integer(x))
    end

    if length(groups) > max_nb_candidates
        resize!(groups, max_nb_candidates)
    end    

    return local_id, groups
end

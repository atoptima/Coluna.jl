"""
    VarBranchingCandidate

    Contains a variable on which we branch
"""
struct VarBranchingCandidate <: AbstractBranchingCandidate 
    description::String
    var_id::VarId
end

getdescription(candidate::VarBranchingCandidate) = candidate.description

function generate_children(candidate::VarBranchingCandidate, lhs::Float64, reform::Reformulation, node::Node)
    var = getvar(reform.master, candidate.var_id)
    @logmsg LogLevel(-1) string("Chosen branching variable : ", 
                                getname(getvar(reform.master, candidate.var_id)), ". With value ", lhs, ".")
    child1 = Node(node, Branch(var, ceil(lhs), Greater, getdepth(node)))
    child2 = Node(node, Branch(var, floor(lhs), Less, getdepth(node)))
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
    candidates = Vector{BranchingGroup}()
    for (var_id, val) in sol
        # Do not consider continuous variables as branching candidates
        getperenekind(getelements(getsol(sol))[var_id]) == Continuous && continue
        if !isinteger(val)
            #description string is just the variable name
            candidate = VarBranchingCandidate(getname(getvar(reform.master, var_id)), var_id)
            local_id += 1 
            push!(candidates, BranchingGroup(candidate, local_id, val))
        end
    end

    if length(candidates) > max_nb_candidates
        resize!(candidates, max_nb_candidates)
    end    

    return local_id, candidates
end

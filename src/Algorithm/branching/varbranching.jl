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
        getname(getmaster(reform), candidate.varid), ". With value ", 
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
end

function run!(
    rule::VarBranchingRule, reform::Reformulation, input::BranchingRuleInput
)::BranchingRuleOutput    
    # variable branching works only for the original solution
    !input.isoriginalsol && return BranchingRuleOutput(input.local_id, Vector{BranchingGroup}())

    master = getmaster(reform)
    groups = Vector{BranchingGroup}()
    local_id = input.local_id
    for (var_id, val) in input.solution
        # Do not consider continuous variables as branching candidates
        getperenekind(master, var_id) == Continuous && continue
        if !isinteger(val)
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



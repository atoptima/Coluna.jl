struct GenerateChildrenNode <: AbstractAlgorithm end

mutable struct GenerateChildrenNodeData
    incumbents::Incumbents
    reformulation::Reformulation # should handle reformulation & formulation
end

struct GenerateChildrenNodeRecord <: AbstractAlgorithmResult
    nodes::Vector{AbstractNode} # Node is not defined when this file is included
end

function prepare!(::Type{GenerateChildrenNode}, form, node, strategy_rec, params)
    @logmsg LogLevel(0) "Prepare generate children nodes"
    return
end

abstract type RuleForUsualBranching end
struct MostFractionalRule <: RuleForUsualBranching end
#struct LeastFractionalRule <: RuleForUsualBranching end

function run!(::Type{GenerateChildrenNode}, formulation, node, strategy_rec, parameters)
    @logmsg LogLevel(0) "Run generate children nodes"
    algorithm_data =  GenerateChildrenNodeData(getincumbents(node), formulation)
    if !isfertile(node)
        @logmsg LogLevel(1) "Node cannot generate children, aborting branching"
        return GenerateChildrenNodeRecord(Node[])
    end
    found_candidate, var_id, val = best_candidate(MostFractionalRule, algorithm_data)
    if found_candidate
        var = getvar(formulation.master, var_id)
        @logmsg LogLevel(-1) string("Chosen branching variable : ", getname(getvar(formulation.master, var_id)), ". With value ", val, ".")
        child1 = Node(node, Branch(var, ceil(val), Greater, getdepth(node)))
        child2 = Node(node, Branch(var, floor(val), Less, getdepth(node)))
        childs = [child1, child2]
        @logmsg LogLevel(0) "Generated two children nodes"
    else
        @logmsg LogLevel(0) "Did not find variable to do branch on. No children nodes will be generated."
        childs = Node[]
    end
    # Record
    record = GenerateChildrenNodeRecord(childs) 
    node.children = record.nodes
    return record
end

function best_candidate(Rule::Type{<:RuleForUsualBranching}, algorithm_data)
    master = getmaster(algorithm_data.reformulation)
    master_primal_sol = get_lp_primal_sol(algorithm_data.incumbents)

    solution = proj_cols_on_rep(master_primal_sol, master)
    #@show "fractional solution" solution

    return best_candidate(Rule, solution)
end

distround(r::Real) = abs(round(r) - r)

 # Todo : talk about float tolerance to select the candidate
function best_candidate(::Type{MostFractionalRule}, sol::PrimalSolution)
    candidate_id = zero(Id{Variable})
    candidate_val = 0.0
    best_dist = _params_.integrality_tolerance
    found_candidate = false
    for (var_id, val) in sol
        # Do not consider continuous variables as branching candidates
        getperenekind(getelements(getsol(sol))[var_id]) == Continuous && continue
        dist = distround(val)
        if dist > best_dist
            candidate_id = var_id
            candidate_val = val
            best_dist = dist
            found_candidate = true
        end
    end
    return found_candidate, candidate_id, candidate_val
end

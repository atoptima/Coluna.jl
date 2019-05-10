struct GenerateChildrenNode <: AbstractSolver end

mutable struct GenerateChildrenNodeData
    incumbents::Incumbents
    reformulation::Reformulation # should handle reformulation & formulation
end

struct GenerateChildrenNodeRecord <: AbstractSolverRecord
    nodes::Vector{AbstractNode} # Node is not defined when this file is included
end

function setup!(::Type{GenerateChildrenNode}, formulation, node, params)
    @logmsg LogLevel(0) "Setup generate children nodes"
    return
end

function solverdata(::Type{GenerateChildrenNode}, formulation, node, params)
    return GenerateChildrenNodeData(getincumbents(node), formulation)
end

function setdown!(::Type{GenerateChildrenNode}, formulation, node, params)
    @logmsg LogLevel(-1) "Setdown generate children nodes"
    solver_rec = get_solver_record!(node, GenerateChildrenNode)
    node.children = solver_rec.nodes
    return
end

abstract type RuleForUsualBranching end
struct MostFractionalRule <: RuleForUsualBranching end
#struct LeastFractionalRule <: RuleForUsualBranching end

function run!(::Type{GenerateChildrenNode}, formulation, node, parameters)
    @logmsg LogLevel(0) "Run generate children nodes"
    solver_data =  GenerateChildrenNodeData(getincumbents(node), formulation)
    if ip_gap(solver_data.incumbents) <= 0.0
        @logmsg LogLevel(-1) string("Subtree is conquered, no need for branching.")
        return GenerateChildrenNodeRecord(Node[])
    end
    found_candiate, var_id, val = best_candidate(MostFractionalRule, solver_data)
    if found_candiate
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
    return GenerateChildrenNodeRecord(childs)
end

function best_candidate(R::Type{<:RuleForUsualBranching}, solver_data)
    master = getmaster(solver_data.reformulation)
    master_primal_sol = get_lp_primal_sol(solver_data.incumbents)

    solution = proj_cols_on_rep(master_primal_sol, master)

    return best_candidate(R, solution)
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

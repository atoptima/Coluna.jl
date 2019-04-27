struct GenerateChildrenNode <: AbstractSolver end

mutable struct GenerateChildrenNodeData <: AbstractSolverData 
    incumbents::Incumbents
    reformulation::Reformulation # should handle reformulation & formulation
end

struct GenerateChildrenNodeRecord <: AbstractSolverRecord
    # TODO
end

function setup!(::Type{GenerateChildrenNode}, formulation, node)
    @logmsg LogLevel(0) "Setup generate children nodes"
    return GenerateChildrenNodeData(getincumbents(node), formulation)
end

function setdown!(::Type{GenerateChildrenNode}, solver_record::GenerateChildrenNodeRecord,
                 formulation, node)
    @logmsg LogLevel(-1) "Setdown generate children nodes"
end

abstract type RuleForUsualBranching end
struct MostFractionalRule <: RuleForUsualBranching end
#struct LeastFractionalRule <: RuleForUsualBranching end

function run!(::Type{GenerateChildrenNode}, solver_data::GenerateChildrenNodeData,
              formulation, node, parameters)
    @logmsg LogLevel(-1) "Run generate children nodes"
    var_id = id_of_best_candidate(MostFractionalRule, solver_data)

    @show var_id
    println(" Generate branching constraints... ")
    return GenerateChildrenNodeRecord()
end

function id_of_best_candidate(R::Type{<:RuleForUsualBranching}, solver_data)
    master = getmaster(solver_data.reformulation)
    master_primal_sol = get_lp_primal_sol(solver_data.incumbents)

    solution = proj_cols_on_rep(master_primal_sol, master)

    showdebug(stdout, master_primal_sol, master)
    showdebug(stdout, solution, master)
    return find_id_of_best_candidate(R, solution)
end

distround(r::Real) = abs(round(r) - r)

 # Todo : talk about float tolerance to select the candidate
function find_id_of_best_candidate(::Type{MostFractionalRule}, sol::PrimalSolution)
    candidate_id = zero(Id{Variable})
    candidate_val = 0.0
    for (var_id, val) in sol
        dist = distround(val)
        if dist >= candidate_val
            candidate_id = var_id
            candidate_val = dist
        end
    end
    return candidate_id
end


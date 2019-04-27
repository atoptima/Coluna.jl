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
    var_id, val = best_candidate(MostFractionalRule, solver_data)
    @show var_id val

    #genbranchingconstr!()
    #genbranchingconstr!()
    println(" Generate branching constraints... ")

    child1 = Node(node)
    child2 = Node(node)
    addchild!(node, child1)
    addchild!(node, child2)
    return GenerateChildrenNodeRecord()
end

function best_candidate(R::Type{<:RuleForUsualBranching}, solver_data)
    master = getmaster(solver_data.reformulation)
    master_primal_sol = get_lp_primal_sol(solver_data.incumbents)

    solution = proj_cols_on_rep(master_primal_sol, master)

    showdebug(stdout, master_primal_sol, master)
    showdebug(stdout, solution, master)
    return best_candidate(R, solution)
end

distround(r::Real) = abs(round(r) - r)

 # Todo : talk about float tolerance to select the candidate
function best_candidate(::Type{MostFractionalRule}, sol::PrimalSolution)
    candidate_id = zero(Id{Variable})
    candidate_val = 0.0
    best_dist = 0.0
    for (var_id, val) in sol
        dist = distround(val)
        if dist >= best_dist
            candidate_id = var_id
            candidate_val = round(val)
            best_dist = dist
        end
    end
    return candidate_id, candidate_val
end

#function genbranchingconstr!(solver_data, )

#end

# function generate_branch_constraint(alg::AlgToGenerateChildrenNodes,
#         depth::Int, var_to_branch::Variable, sense::Char, rhs::Float64)
#     extended_problem = alg.extended_problem
#     constr = MasterBranchConstrConstructor(
#         extended_problem.counter,
#         string("branch_",var_to_branch.name,"_",sense, "_", depth),
#         rhs, sense, depth, var_to_branch
#     )
#     # if extended_problem.params.node_eval_mode == SimplexCg
#     #     attach_art_var(extended_problem.art_var_manager,
#     #                    extended_problem.master_problem, constr)
#     # end
#     push!(alg.generated_branch_constraints, constr)
#     @logmsg LogLevel(-4) string(
#         "Generated branching constraint with reference ",
#         branch_constr.vc_ref)
# end

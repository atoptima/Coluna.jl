@hl type ChildrenGenerationInfo end
@hl type BranchingEvaluationInfo end

@hl type AlgToGenerateChildrenNodes
    rule::RuleForUsualBranching
    nb_vars_to_branch::Int
end

abstract type RuleForUsualBranching end

struct MostFractionalRule <: RuleForUsualBranching end
struct LeastFractionalRule <: RuleForUsualBranching end


function sort_vars_according_to_rule(rule::MostFractionalRule, vars::Vector{Variable})
    sort!(vars, by = x -> abs(x.value - round(x.value)), rev=false)
end


function run(alg::AlgToGenerateChildrenNodes, node::Node, problem::Problem)

    frac_master_cols = MasterColumn[]

    for var in node.solution_var_info_list
        if abs(var.value - round(var.value)) > Params.mip_tolerance_integrality
            if typeof(var) == MasterColumn
                push!(frac_master_cols, var)
            end
        end
    end

    if isempty(frac_master_cols)
        return
    end

    perform_usual_branching(node, alg, frac_master_cols, problem)
    ## Add strong branching here

end

function generate_child(parent_node::Node, var_to_branch::Variable, rhs::Float)

    newConstraint = BranchConstr(problem, "dummyName", 1.0, 'E')
    push!(node.problem_setup_info.active_branching_constraints_info,
        ConstraintInfo(newConstraint))
    new_node = Node()
    push!(node.children, new_node)

end


function perform_usual_branching(node::Node, alg::AlgToGenerateChildrenNodes,
        frac_master_cols::Vector{MasterColumn}, problem::Problem)

    branch_constraints = BranchConstr[]
    sort_vars_according_to_rule(alg.rule, frac_master_cols)
    for i in 1:alg.nb_vars_to_branch
        generate_child(node, frac_master_cols[i], 1.0)
        generate_child(node, frac_master_cols[i], 0.0)
    end


end

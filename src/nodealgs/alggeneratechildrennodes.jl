@hl type ChildrenGenerationInfo end

@hl type BranchingEvaluationInfo end

@hl type AlgToGenerateChildrenNodes
    extended_problem::ExtendedProblem
end

function AlgToGenerateChildrenNodesBuilder(problem::ExtendedProblem)
    return (problem,)
end

abstract type RuleForUsualBranching end
struct MostFractionalRule <: RuleForUsualBranching end
struct LeastFractionalRule <: RuleForUsualBranching end

@hl type UsualBranchingAlg <: AlgToGenerateChildrenNodes
    rule::RuleForUsualBranching
    nb_vars_to_branch::Int
end

function UsualBranchingAlgBuilder(problem::ExtendedProblem)
    return tuplejoin(AlgToGenerateChildrenNodesBuilder(problem),
        MostFractionalRule(), 1)
end


function setup(alg::AlgToGenerateChildrenNodes)
    return false
end

function setdown(alg::AlgToGenerateChildrenNodes)

end


function sort_vars_according_to_rule(rule::MostFractionalRule, vars::Vector{<:Variable})
    sort!(vars, by = x -> fract_part(x.value), rev=false)
end

function retreive_candidate_vars(alg::AlgToGenerateChildrenNodes,
        var_val_map::Dict{Variable, Float})
    frac_master_vars = MasterVar[]
    for var_val in var_val_map
        if typeof(var_val[1]) <: MasterVar
            if !primal_value_is_integer(var_val[2],
                    alg.extended_problem.params.mip_tolerance_integrality)
                push!(frac_master_vars, var_val[1])
            end
        end
    end

    return frac_master_vars
end


function perform_usual_branching(node, alg::AlgToGenerateChildrenNodes,
        frac_master_vars::Vector{<:Variable})

    sort_vars_according_to_rule(alg.rule, frac_master_vars)
    for i in 1:alg.nb_vars_to_branch
        generate_child(alg, node, frac_master_vars[i], 1.0)
        generate_child(alg, node, frac_master_vars[i], 0.0)
    end

end

function generate_child(alg::AlgToGenerateChildrenNodes, parent_node,
        var_to_branch::Variable, rhs::Float)

    new_node = NodeWithParent(alg.extended_problem,
        parent_node)

    branch_constr = BranchConstrConstructor(alg.extended_problem.counter,
    "dummyName", rhs, 'E', parent_node.depth, var_to_branch)

    push!(new_node.problem_setup_info.active_branching_constraints_info,
        ConstraintInfo(branch_constr, 0.0, 0.0, 1.0, Active))

    ### add to consraint manager?

    push!(parent_node.children, new_node)

end


function run(alg::UsualBranchingAlg, global_treat_order::Int, node)

    println("generating children\n\n")

    frac_master_vars = retreive_candidate_vars(alg, node.primal_sol.var_val_map)

    if isempty(frac_master_vars)
        return
    end

    perform_usual_branching(node, alg, frac_master_vars)
    ## Add strong branching here

end

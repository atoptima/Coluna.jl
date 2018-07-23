@hl type AlgToGenerateChildrenNodes <: AlgLike
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


function sort_vars_according_to_rule(rule::MostFractionalRule, vars::Vector{Pair{T, Float}}
        )  where T <: Variable
    sort!(vars, by = x -> fract_part(x.second), rev=true)
end

function retreive_candidate_vars(alg::AlgToGenerateChildrenNodes,
        var_val_map::Dict{Variable, Float})
    frac_master_vars = Pair{MasterVar, Float}[]
    for var_val in var_val_map
        if typeof(var_val[1]) <: MasterVar
            if !primal_value_is_integer(var_val[2],
                    alg.extended_problem.params.mip_tolerance_integrality)
                push!(frac_master_vars, Pair(var_val[1], var_val[2]))
            end
        end
    end

    return frac_master_vars
end

function generate_branch_constraint(alg::AlgToGenerateChildrenNodes,
        depth::Int, var_to_branch::Variable, sense::Char, rhs::Float)
    return BranchConstrConstructor(alg.extended_problem.counter,
        "dummyName", rhs, sense, depth, var_to_branch)
end

function generate_child(alg::AlgToGenerateChildrenNodes, node::Node,
        branch_constrs::Vector{T}) where T <: BranchConstr

    new_node = NodeWithParent(alg.extended_problem, node)
    for constr in branch_constrs
        push!(new_node.local_branching_constraints, constr)
    end
    push!(node.children, new_node)

end

function perform_usual_branching(node::Node, alg::AlgToGenerateChildrenNodes,
        frac_master_vars::Vector{Pair{T, Float}}) where T <: Variable

    sort_vars_according_to_rule(alg.rule, frac_master_vars)
    local_branch_constraints = BranchConstr[]
    for i in 1:alg.nb_vars_to_branch
        println("Chosen variable to branch: ", frac_master_vars[i].first.name,
            ". With value: ", frac_master_vars[i].second, ". fract_part = ",
            fract_part(frac_master_vars[i].second))
        branch_constr = generate_branch_constraint(alg, node.depth,
            frac_master_vars[i].first, 'G', ceil(frac_master_vars[i].second))

        push!(local_branch_constraints, branch_constr)
        println("Generated branching constraint with reference ", branch_constr.vc_ref)
        branch_constr = generate_branch_constraint(alg, node.depth,
            frac_master_vars[i].first, 'L', floor(frac_master_vars[i].second))
        push!(local_branch_constraints, branch_constr)
        println("Generated branching constraint with reference ", branch_constr.vc_ref)
    end
    for constr in local_branch_constraints
        generate_child(alg, node, [constr])
    end
end

function run(alg::UsualBranchingAlg, global_treat_order::Int, node::Node)

    println("Generating children...")

    frac_master_vars = retreive_candidate_vars(alg, node.primal_sol.var_val_map)

    if isempty(frac_master_vars)
        println("Generated ", length(node.children), " child nodes.")
        return
    end

    perform_usual_branching(node, alg, frac_master_vars)

    println("Generated ", length(node.children), " child nodes.")

end

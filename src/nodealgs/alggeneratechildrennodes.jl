@hl mutable struct AlgToGenerateChildrenNodes <: AlgLike
    extended_problem::ExtendedProblem
end

function AlgToGenerateChildrenNodesBuilder(problem::ExtendedProblem)
    return (problem,)
end

abstract type RuleForUsualBranching end
struct MostFractionalRule <: RuleForUsualBranching end
struct LeastFractionalRule <: RuleForUsualBranching end

@hl mutable struct UsualBranchingAlg <: AlgToGenerateChildrenNodes
    rule::RuleForUsualBranching
end

function UsualBranchingAlgBuilder(problem::ExtendedProblem)
    return tuplejoin(AlgToGenerateChildrenNodesBuilder(problem),
        MostFractionalRule())
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

function retrieve_candidate_vars(alg::AlgToGenerateChildrenNodes,
        var_val_map::Dict{Variable, Float})

    # find the fractional pure variables and aggregate the column variable
    # values into subproblem variables
    frac_master_vars = Pair{Variable, Float}[]
    subprob_vars = Dict{Variable, Float}()
    for var_val in var_val_map
        if typeof(var_val.first) <: MasterVar
            if !is_value_integer(var_val.second,
                    alg.extended_problem.params.mip_tolerance_integrality)
                push!(frac_master_vars, Pair(var_val.first, var_val.second))
            end
        elseif typeof(var_val[1]) <: MasterColumn
            for sp_var_val in var_val[1].solution.var_val_map
                val = var_val[2] * sp_var_val[2]
                if haskey(subprob_vars,sp_var_val[1])
                    subprob_vars[sp_var_val[1]] += val
                else
                    subprob_vars[sp_var_val[1]] = val
                end
            end
        end
    end

    # extract only the subproblem variables with fractional values
    frac_subprob_vars = Pair{SubprobVar, Float}[]
    for sp_var_val in subprob_vars
        if !is_value_integer(sp_var_val[2],
                alg.extended_problem.params.mip_tolerance_integrality)
            push!(frac_subprob_vars, sp_var_val)
        end
    end

    return frac_master_vars, frac_subprob_vars
end

function generate_branch_constraint(alg::AlgToGenerateChildrenNodes,
        depth::Int, var_to_branch::Variable, sense::Char, rhs::Float)
    return BranchConstrConstructor(alg.extended_problem.counter,
        string("branch_",var_to_branch.name,"_",sense), rhs, sense, depth,
        var_to_branch)
end

function generate_child(alg::AlgToGenerateChildrenNodes, node::Node,
        branch_constrs::Vector{T}) where T <: BranchConstr

    new_node = NodeWithParent(alg.extended_problem, node)

    #global nn_ = new_node
    #global bc_ = branch_constrs
    #global n_ = node
    #SimpleDebugger.@bkp

    for i in 1:length(branch_constrs)
        push!(new_node.local_branching_constraints, branch_constrs[i])
    end
    push!(node.children, new_node)

end

function perform_usual_branching(node::Node, alg::AlgToGenerateChildrenNodes,
        frac_vars::Vector{Pair{T, Float}}) where T <: Variable

    sort_vars_according_to_rule(alg.rule, frac_vars)
    var_to_branch = frac_vars[1].first
    val = frac_vars[1].second
    @logmsg LogLevel(-4) string("Chosen variable to branch: ",
        var_to_branch.name, ". With value: ", val, ". fract_part = ",
        fract_part(val))

    branch_constr = generate_branch_constraint(alg, node.depth,
        var_to_branch, 'G', ceil(val))
    generate_child(alg, node, [branch_constr])
    @logmsg LogLevel(-4) string("Generated branching 
        constraint with reference ", branch_constr.vc_ref)

    branch_constr = generate_branch_constraint(alg, node.depth,
        var_to_branch, 'L', floor(val))
    generate_child(alg, node, [branch_constr])
    @logmsg LogLevel(-4) string("Generated branching 
        constraint with reference ", branch_constr.vc_ref)
end

function run(alg::UsualBranchingAlg, global_treat_order::Int, node::Node)

    @logmsg LogLevel(-4) "Generating children..."
    frac_master_vars, frac_subprob_vars = retrieve_candidate_vars(
                                            alg, node.primal_sol.var_val_map)
    frac_vars = vcat(frac_master_vars, frac_subprob_vars)

    #global ps_ = node.primal_sol
    #global fv_ = frac_vars
    #SimpleDebugger.@bkp

    if isempty(frac_vars)
        @logmsg LogLevel(-4) string("Generated ", length(node.children), " child nodes.")
        return
    end
    perform_usual_branching(node, alg, frac_vars)
    @logmsg LogLevel(-4) string("Generated ", length(node.children), " child nodes.")

end

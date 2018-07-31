
@hl mutable struct VariableSmallInfo
    variable::Variable
    cost::Float
    status::VCSTATUS
end

VariableSmallInfoBuilder(var::Variable, status::VCSTATUS) = (var, var.cur_cost_rhs, status)
VariableSmallInfoBuilder(var::Variable) = VariableSmallInfoBuilder(var, Active)

function apply_var_info(info::VariableSmallInfo)::Void
    reset_cur_cost_by_value(var, info.cost)
end

@hl mutable struct VariableInfo <: VariableSmallInfo
    lb::Float
    ub::Float
end

VariableInfoBuilder(var::Variable, status::VCSTATUS) =
        tuplejoin(VariableSmallInfoBuilder(var, status),
                  var.cur_lb, var.cur_ub)

VariableInfoBuilder(var::Variable) = VariableInfoBuilder(var::Variable, Active)

function apply_var_info(info::VariableInfo)::Void
    @callsuper apply_var_info(var::VariableInfoSmall)
    var.cur_lb = info.lb
    var.cur_ub = info.ub
end

function is_need_to_change_bounds(info::VariableInfo)::Bool
    var = info.variable
    ub = info.ub
    lb = info.lb
    return var.in_cur_form && (lb != var.cur_lb || ub != var.cur_ub)
end

@hl mutable struct SpVariableInfo <: VariableInfo
    local_lb::Float
    local_ub::Float
end

SpVariableInfoBuilder(var::SubprobVar, status::VCSTATUS) =
        tuplejoin(VariableInfoBuilder(var,status), var.local_cur_lb, var.local_cur_ub)

function apply_var_info(info::SubprobVar)::Void
    @callsuper apply_var_info(var::VariableInfo)
    var.local_cur_lb = info.local_lb
    var.local_cur_ub = info.local_ub
end

@hl mutable struct ConstraintInfo
    constraint::Constraint
    min_slack::Float
    max_slack::Float
    rhs::Float
    status::VCSTATUS
end

function ConstraintInfoBuilder(constr::T, status::VCSTATUS) where T <: Constraint
    return (ConstraintInfo(constr, 0.0, 0.0, constr.cost_rhs, status), )
end

function ConstraintInfoBuilder(constr::T) where T <: Constraint
    return ConstraintInfoBuilder(constr, Active)
end

function applyconstrinfo(info::ConstraintInfo)::Void
    info.constraint.min_slack = info.min_slack
    info.constraint.max_slack = info.max_slack
    info.constraint.rhs = info.rhs
end

@hl mutable struct ProblemSetupInfo <: SetupInfo
    treat_order::Int
    number_of_nodes::Int
    full_setup_is_obligatory::Bool

    suitable_master_columns_info::Vector{VariableSmallInfo}
    suitable_master_cuts_info::Vector{ConstraintInfo}
    active_branching_constraints_info::Vector{ConstraintInfo}
    master_partial_solution_info::Vector{VariableSolInfo}

    # - In these two lists we keep only static variables and constraints for
    # which at least one of the attributes in VariableInfo and ConstraintInfo is
    # different from the default. Default values are set by the user and can be
    # changed by the preprocessing at the root
    # - Unsuitable static variables or constraints are ignored: they are
    #   eliminated by the preprocessed at the root
    # - We keep variables and constraints in the strict order:
    #   master -> subprob 1 -> subprob 2 -> ...

    modified_static_vars_info::Vector{VariableInfo}
    modified_static_constrs_info::Vector{ConstraintInfo}
end

ProblemSetupInfo(treat_order) = ProblemSetupInfo(treat_order, 0, false,
        Vector{VariableSmallInfo}(), Vector{ConstraintInfo}(),
        Vector{ConstraintInfo}(), Vector{VariableSolInfo}(),
        Vector{VariableInfo}(), Vector{ConstraintInfo}())

#############################
#### AlgToSetdownNode #######
#############################

@hl mutable struct AlgToSetdownNode <: AlgLike
    extended_problem::ExtendedProblem
end

function run(alg::AlgToSetdownNode)
    # alg.extended_problem.master_problem.cur_node = Nullable{Node}()
    # for prob in alg.extended_problem.pricing_vect
    #     prob.cur_node = Nullable{Node}()
    # end
    # problem_info = record_problem_info(alg, )
end

function record_problem_info(alg::AlgToSetdownNode,
                             global_treat_order::Int)::ProblemSetupInfo
    return ProblemSetupInfo(alg.extended_problem.master_problem.cur_node.treat_order)
end
record_problem_info(alg) = record_problem_info(alg, -1)

@hl mutable struct AlgToSetdownNodeFully <: AlgToSetdownNode end

function AlgToSetdownNodeFullyBuilder(problem::ExtendedProblem)
    return (problem, )
end

function run(alg::AlgToSetdownNodeFully, node::Node)
    record_problem_info(alg, node::Node)
end

function record_problem_info(alg::AlgToSetdownNodeFully, node::Node)
    master_problem = alg.extended_problem.master_problem
    # prob_info = ProblemSetupInfo(alg.extended_problem.master_problem.cur_node.treat_order)
    prob_info = ProblemSetupInfo(1)

    #patial solution of master
    for (var, val) in master_problem.partial_solution
        push!(prob_info.master_partial_solution_info, VariableSolInfo(var, val))
    end

    #static variables of master
    for var in master_problem.var_manager.active_static_list
        if (var.cur_lb != var.lower_bound
            || var.cur_ub != var.upper_bound
            || var.cur_cost_rhs != var.costrhs)
            push!(prob_info.modified_static_vars_info, VariableInfo(var, Active))
        end
    end

    # dynamic master variables
    for var in master_problem.var_manager.active_dynamic_list
        if isa(var, MasterColumn)
            push!(prob_info.suitable_master_columns_info,
                  VariableSmallInfo(var, Active))
        end
    end

    println("Stored ", length(master_problem.var_manager.active_dynamic_list),
        " active variables")

    # static constraints of the master
    # for constr in master_problem.constr_manager.active_static_list
    #     if (# !isa(constr, ConvexityMasterConstr) &&
    #         constr.cur_min_slack != constr.min_slack &&
    #         constr.cur_max_slack != constr.max_slack)
    #         push!(prob_info.modified_static_constrs_info, ConstraintInfo(constr))
    #     end
    # end

    # dynamic constraints of the master (cuts and branching constraints)
    for constr in master_problem.constr_manager.active_dynamic_list
        if isa(constr, BranchConstr)
            push!(prob_info.active_branching_constraints_info,
                ConstraintInfo(constr))
        elseif isa(constr, MasterConstr)
            push!(prob_info.suitable_master_cuts_info,
                  ConstraintInfo(constr, Active))
        end
    end


    #subprob variables
    for subprob in alg.extended_problem.pricing_vect
        for var in subprob.var_manager.active_static_list
            if (var.cur_lower_bound != var.lower_bound
                || var.cur_upper_bound != var.upper_bound
                || var.cur_local_lb != local_lb
                || var.cur_loca_lub != var.local_ub || var.cur_cost_rhs != var.costrhs)
                push!(modified_static_vars_info, SpVariableInfo(var))
            end
        end
    end

    println("Stored ", length(master_problem.constr_manager.active_dynamic_list),
        " active cosntraints")

    node.problem_setup_info = prob_info
end

#############################
##### AlgToSetupNode ########
#############################

@hl mutable struct AlgToSetupNode <: AlgLike
    extended_problem::ExtendedProblem
    problem_setup_info::ProblemSetupInfo
    is_all_columns_active::Bool
end

function AlgToSetupNodeBuilder(extended_problem::ExtendedProblem)
    return (extended_problem, ProblemSetupInfo(0), false)
end

function AlgToSetupNodeBuilder(extended_problem::ExtendedProblem,
        problem_setup_info::ProblemSetupInfo)
    return (extended_problem, problem_setup_info, false)
end

@hl mutable struct AlgToSetupBranchingOnly <: AlgToSetupNode end

function AlgToSetupBranchingOnlyBuilder(extended_problem::ExtendedProblem)
    return AlgToSetupNodeBuilder(extended_problem)
end

function AlgToSetupBranchingOnlyBuilder(extended_problem::ExtendedProblem,
        problem_setup_info::ProblemSetupInfo)
    return AlgToSetupNodeBuilder(extended_problem, problem_setup_info)
end

function reset_partial_solution(alg::AlgToSetupNode)
    # node = alg.node
    # if !isempty(node.localfixedsolution)
    #     for (var, val) in node.localfixedsolution.solvarvalmap
    #         updatepartialsolution(alg.extended_problem.master_problem, var, val)
    #     end
    # end
end

function prepare_branching_constraints_added_by_father(alg::AlgToSetupNode, node)
    for constr in node.local_branching_constraints
        add_full_constraint(alg.extended_problem.master_problem, constr)
        println("Adding cosntraint ", constr.vc_ref, " generated when branching.")
    end
end

function prepare_branching_constraints(alg::AlgToSetupBranchingOnly, node)
    prepare_branching_constraints_added_by_father(alg, node)
end

function run(alg::AlgToSetupBranchingOnly, node)

    # apply_subproblem_info()
    # fill_local_branching_constraints()
    prepare_branching_constraints(alg, node)

    # reset_branching_constraints(_masterProbPtr, branchingConstrPtrIt)

    ### should be done after resetBranchingConstraints as component set branching constraints
    ### can modify convexity constraints
    # reset_convexity_constraints()
    # reset_non_stab_artificial_variables()

    reset_partial_solution(alg)
    update_formulation(alg)
    return false
end

@hl mutable struct AlgToSetupFull <: AlgToSetupNode end

function AlgToSetupFullBuilder(extended_problem::ExtendedProblem,
        problem_setup_info::ProblemSetupInfo)
    return AlgToSetupNodeBuilder(extended_problem, problem_setup_info)
end

function find_first_in_problem_setup(constr_info_vec::Vector{ConstraintInfo},
        vc_ref::Int)
    for i in 1:length(constr_info_vec)
        if vc_ref == constr_info_vec[i].constraint.vc_ref
            return i
        end
    end
    return 0
end

function prepare_branching_constraints(alg::AlgToSetupFull, node)
    in_problem = alg.extended_problem.master_problem.constr_manager.active_dynamic_list
    in_setup_info = node.problem_setup_info.active_branching_constraints_info
    for i in length(in_problem):-1:1
        constr = in_problem[i]
        if typeof(constr) <: BranchConstr
            idx = find_first_in_problem_setup(in_setup_info, constr.vc_ref)
            if idx == 0
                delete_constraint(alg.extended_problem.master_problem, constr)
                println("cosntraint ", constr.vc_ref, " deactivated")
            else
                println("constraint ", constr.vc_ref, " is in branching tree of node")
            end
        end
    end
    for constr_info in in_setup_info
        constr = constr_info.constraint
        if typeof(constr) <: BranchConstr
            idx = find_first(in_problem, constr.vc_ref)
            if idx == 0
                add_full_constraint(alg.extended_problem.master_problem, constr)
                println("added constraint ", constr.vc_ref)
            else
                println("constraint ", constr.vc_ref, " is already in problem")
            end
        end
    end
    prepare_branching_constraints_added_by_father(alg, node)
end

function run(alg::AlgToSetupFull, node)

    prepare_branching_constraints(alg, node)

    reset_partial_solution(alg)
    update_formulation(alg)
    return false

end


function reset_master_columns(alg::AlgToSetupNode)
    prob_info = alg.problem_setup_info
    for var_info in alg.prob_setup_info.suitable_master_columns_info
        var = var_info.variable
        if var_info.status == Active || alg.is_all_columns_active
            if var.status == Active && var_info.cost != var.cur_cost_rhs
                push!(alg.vars_to_change_cost, var)
            end
            apply_var_info(var_info)
        elseif var_info.status == Unsuitable
            deactivate_variable(alg, prob, var)
        end
        var.info_is_updated = true
    end

    for var in alg.extended_problem.master_problem.var_manager.active_dynamic_list
        if isa(var, MasterColumn) && var.info_is_updated == false
            deactivate_variable(alg, alg.extended_problem.master_problem, var)
        else
            var.info_is_updated = false
        end
    end
end

function update_formulation(alg::AlgToSetupNode)
    # TODO implement caching through MOI.
end

#############################
#### AlgToSetupRootNode #####
#############################

@hl mutable struct AlgToSetupRootNode <: AlgToSetupNode end

function AlgToSetupRootNodeBuilder(problem::ExtendedProblem,
        problem_setup_info::ProblemSetupInfo)
    return AlgToSetupNodeBuilder(problem, problem_setup_info)
end

# function run(alg::AlgToSetupRootNode, node::Node)
function run(alg::AlgToSetupRootNode, node)
    # @callsuper probleminfeasible = AlgToSetupNode::run(node)

    # reset_root_convexity_master_constr(alg)
    # reset_master_columns(alg)
    # reset_non_stab_artificial_variables(alg)

    update_formulation(alg)

    # return problem_infeasible
    return false
end

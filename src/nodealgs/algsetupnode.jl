
@hl type VariableSmallInfo
    variable::Variable
    cost::Float
    status::VCSTATUS
end

VariableSmallInfoBuilder(var::Variable, status::VCSTATUS) = (var, var.cur_cost, status)
VariableSmallInfoBuilder(var::Variable) = VariableSmallInfoBuilder(var, Active)

function apply_var_info(info::VariableSmallInfo)::Void
    reset_cur_cost_by_value(var, info.cost)
end

@hl type VariableInfo <: VariableSmallInfo
    lb::Float
    ub::Float
end

VariableInfoBuilder(var::Variable, status::VCSTATUS) =
        tuplejoin(VariableSmallInfoBuilder(var, status),
                  var.global_cur_lb, var.global_cur_ub)

VariableInfoBuilder(var::Variable) = VariableInfoBuilder(var::Variable, Active)

function apply_var_info(info::VariableInfo)::Void
    @callsuper apply_var_info(var::VariableInfoSmall)
    var.global_cur_lb = info.lb
    var.global_cur_ub = info.ub
end

function is_need_to_change_bounds(info::VariableInfo)::Bool
    var = info.variable
    ub = info.ub
    lb = info.lb
    return var.in_cur_form && (lb != var.global_cur_lb || ub != var.global_cur_ub)
end

@hl type SpVariableInfo <: VariableInfo
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

type ConstraintInfo
    constraint::Constraint
    min_slack::Float
    max_slack::Float
    rhs::Float
    status::VCSTATUS
end

ConstraintInfo(constr, status) = ConstraintInfo(constr, constr.min_slack,
        constr.max_slack, constr.rhs, status)
CosntraintInfo(constr) = ConstraintInfo(constr, Active)

function applyconstrinfo(info::ConstraintInfo)::Void
    info.constraint.min_slack = info.min_slack
    info.constraint.max_slack = info.max_slack
    info.constraint.rhs = info.rhs
end

type ProblemSetupInfo
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

@hl type AlgToSetdownNode
    master_prob::Problem
    pricing_probs::Vector{Problem}
end

function run(alg::AlgToSetdownNode)
    alg.master_prob.cur_node = Nullable{Node}()
    for prob in alg.pricing_probs
        prob.cur_node = Nullable{Node}()
    end
end

function record_problem_info(alg::AlgToSetdownNode,
                             global_treat_order::Int)::ProblemSetupInfo
    return ProblemSetupInfo(alg.master_prob.cur_node.treat_order)
end
record_problem_info(alg) = record_problem_info(alg, -1)

@hl type AlgToSetdownNodeFully <: AlgToSetdownNode end

function record_problem_info(alg::AlgToSetdownNodeFully, global_treat_order::Int)
    const master_prob = alg.master_prob
    const prob_info = ProblemSetupInfo(alg.master_prob.cur_node.treat_order)

    #patial solution of master
    for (var, val) in master_prob.partial_solution
        push!(prob_info.master_partial_solution_info, VariableSolInfo(var, val))
    end

    #static variables of master
    for var in master_prob.var_manager.active_static_list
        if (var.global_cur_lb != var.global_lb
            || var.global_cur_ub != var.global_ub
            || var.cur_cost != var.costrhs)
            push!(prob_info.modified_static_vars_info, VariableInfo(var, Active))
        end
    end

    # dynamic master variables
    for var in master_prob.var_manager.active_dynamic_list
        if isa(var, MasterColumn)
            push!(prob_info.suitable_master_columns_info,
                  VariableSmallInfo(var, Active))
        end
    end

    printl(1) && print("Stored ", legnth(master_prob.var_manager.active_dynamic_list),
    " active")

    # static constraints of the master
    for constr in master_prob.constr_manager.active_static_list
        if (# !isa(constr, ConvexityMasterConstr) &&
            constr.cur_min_slack != constr.min_slack &&
            constr.cur_max_slack != constr.max_slack)
            push!(prob_info.modified_static_constrs_info, ConstraintInfo(constr))
        end
    end

    # dynamic constraints of the master (cuts and branching constraints)
    for constr in master_prob.constr_manager.active_dynamic_list
        # if isa(constr, BranchingMasterConstr) TODO: required for branching
        #     push!(prob_info.active_branching_constraints_info, ConstraintInfo(constr)
        # else
        if isa(constr, MasterConstr)
            push!(prob_info.suitable_master_cuts_info,
                  ConstraintInfo(constr, Active))
        end
    end


    #subprob variables
    for subprob in alg.pricing_probs
        for var in subprob.var_manager.active_static_list
            if (var.cur_global_lb != var.global_lb
                || var.cur_global_ub != var.global_ub
                || var.cur_local_lb != local_lb
                || var.cur_loca_lub != var.local_ub || var.cur_cost != var.costrhs)
                push!(modified_static_vars_info, SpVariableInfo(var))
            end
        end
    end

    return prob_info
end

#############################
##### AlgToSetupNode ########
#############################

@hl type AlgToSetupNode
    # node::Node
    master_prob::Problem
    pricing_probs::Vector{Problem}
    problem_setup_info::ProblemSetupInfo
    is_all_columns_active::Bool
end

function reset_partial_solution(alg::AlgToSetupNode)
    # const node = alg.node
    # if !isempty(node.localfixedsolution)
    #     for (var, val) in node.localfixedsolution.solvarvalmap
    #         updatepartialsolution(alg.master_prob, var, val)
    #     end
    # end
end

# function run(alg::AlgToSetupNode, node::Node)
function run(alg::AlgToSetupNode)
    # alg.master_prob.cur_node = Nullable{Node}(node)
    # for prob in alg.pricing_probs
    #     prob.cur_node = Nullable{Node}(node)
    # end
    reset_partial_solution(alg)
    return false
end

function reset_master_columns(alg::AlgToSetupNode)
    const prob_info = alg.problem_setup_info
    for var_info in alg.prob_setup_info.suitable_master_columns_info
        var = var_info.variable
        if var_info.status == Active || alg.is_all_columns_active
            if var.status == Active && var_info.cost != var.cur_cost
                push!(alg.vars_to_change_cost, var)
            end
            apply_var_info(var_info)
        elseif var_info.status == Unsuitable
            deactivate_variable(alg, prob, var)
        end
        var.info_is_updated = true
    end

    for var in alg.master_prob.var_manager.active_dynamic_list
        if isa(var, MasterColumn) && var.info_is_updated == false
            deactivate_variable(alg, alg.master_prob, var)
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

@hl type AlgToSetupRootNode <: AlgToSetupNode end

# function run(alg::AlgToSetupRootNode, node::Node)
function run(alg::AlgToSetupRootNode)
    # @callsuper probleminfeasible = AlgToSetupNode::run(node)

    # reset_root_convexity_master_constr(alg)
    reset_master_columns(alg)
    # reset_non_stab_artificial_variables(alg)

    update_formulation(alg.master_prob)

    return problem_infeasible
end

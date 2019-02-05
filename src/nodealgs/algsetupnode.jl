@hl mutable struct VariableSmallInfo
    variable::Variable
    cost::Float
    status::VCSTATUS
end

VariableSmallInfoBuilder(var::Variable, status::VCSTATUS) = (var, var.cur_cost_rhs, status)
VariableSmallInfoBuilder(var::Variable) = VariableSmallInfoBuilder(var, Active)

function apply_var_info(info::VariableSmallInfo)
    info.variable.cur_cost_rhs = info.cost
end

@hl mutable struct VariableInfo <: VariableSmallInfo
    # Current lb and ub as of the end of node treatment.
    # This is valid for all preprocessing done in the subtree of the node.
    # This information should be carried throught the tree by means of
    # setup and setdown algs.
    lb::Float
    ub::Float
end

VariableInfoBuilder(var::Variable, status::VCSTATUS) =
        tuplejoin(VariableSmallInfoBuilder(var, status),
                  var.cur_lb, var.cur_ub)

VariableInfoBuilder(var::Variable) = VariableInfoBuilder(var::Variable, Active)

function apply_var_info(info::VariableInfo)
    @callsuper apply_var_info(info::VariableSmallInfo)
    info.variable.cur_lb = info.lb
    info.variable.cur_ub = info.ub
end

@hl mutable struct SpVariableInfo <: VariableInfo
    # Current global lb and global ub as of the end of node treatment.
    # This is valid for all preprocessing done in the subtree of the node.
    # This information should be carried throught the tree by means of
    # setup and setdown algs.
    global_lb::Float
    global_ub::Float
end

SpVariableInfoBuilder(var::SubprobVar, status::VCSTATUS) =
        tuplejoin(VariableInfoBuilder(var, status), var.cur_global_lb, var.cur_global_ub)

SpVariableInfoBuilder(var::SubprobVar) = SpVariableInfoBuilder(var, Active)

function apply_var_info(info::SpVariableInfo)
    @callsuper apply_var_info(info::VariableInfo)
    info.variable.cur_global_lb = info.global_lb
    info.variable.cur_global_ub = info.global_ub
end

@hl mutable struct ConstraintInfo
    constraint::Constraint
    rhs::Float
    status::VCSTATUS
end

function ConstraintInfoBuilder(constr::T, status::VCSTATUS) where T <: Constraint
    return (constr, constr.cost_rhs, status)
end

function ConstraintInfoBuilder(constr::T) where T <: Constraint
    return ConstraintInfoBuilder(constr, Active)
end

function apply_constr_info(info::ConstraintInfo)
    info.constraint.cur_cost_rhs = info.rhs
end

@hl mutable struct ProblemSetupInfo <: SetupInfo
    #treat_order::Int
    # number_of_nodes::Int
    # full_setup_is_obligatory::Bool

    suitable_master_columns_info::Vector{VariableSmallInfo}
    # suitable_master_cuts_info::Vector{ConstraintInfo}
    active_branching_constraints_info::Vector{ConstraintInfo}
    # master_partial_solution_info::Vector{VariableSolInfo}

    # - In these two lists we keep only static variables and constraints for
    # which at least one of the attributes in VariableInfo and ConstraintInfo is
    # different from the default. Default values are set by the user and can be
    # changed by the preprocessing at the root
    # - Unsuitable static variables or constraints are ignored: they are
    #   eliminated by the preprocessed at the root
    # - We keep variables and constraints in the strict order:
    #   master -> subprob 1 -> subprob 2 -> ...

    modified_static_vars_info::Vector{VariableInfo}
    # modified_static_constrs_info::Vector{ConstraintInfo}
end

ProblemSetupInfo() = ProblemSetupInfo(Vector{VariableSmallInfo}(),
                                      Vector{ConstraintInfo}(),
                                      Vector{VariableInfo}())

function apply_var_constr_info(prob_info::ProblemSetupInfo)
    for var_info in prob_info.modified_static_vars_info
        apply_var_info(var_info)
    end
end

#############################
#### AlgToSetdownNode #######
#############################

@hl mutable struct AlgToSetdownNode <: AlgLike
    extended_problem::ExtendedProblem
end

@hl mutable struct AlgToSetdownNodeFully <: AlgToSetdownNode end

function AlgToSetdownNodeFullyBuilder(problem::ExtendedProblem)
    return (problem, )
end

function run(alg::AlgToSetdownNodeFully, node::Node)
    record_problem_info(alg, node::Node)
end

function record_variables_info(prob_info::ProblemSetupInfo,
                               master_problem::CompactProblem,
                               subproblems::Vector{Problem})
    # Static variables of master
    for var in master_problem.var_manager.active_static_list
        if var.flag != 'a' && bounds_changed(var)
            push!(prob_info.modified_static_vars_info, VariableInfo(var, Active))
            set_default_currents(var)
            enforce_current_bounds_in_optimizer(master_problem.optimizer, var)
        end
    end

    # Dynamic master variables
    for var in master_problem.var_manager.active_dynamic_list
        @assert isa(var, MasterColumn)
        push!(prob_info.suitable_master_columns_info,
              VariableSmallInfo(var, Active))
    end

    # Subprob variables
    for subprob in subproblems
        for var in subprob.var_manager.active_static_list
            if bounds_changed(var)
                push!(prob_info.modified_static_vars_info,
                      SpVariableInfo(var, Active))
                set_default_currents(var)
                # if @callsuper bounds_changed(var::Variable)
                #     enforce_current_bounds_in_optimizer(subprob.optimizer, var)
                # end
            end
        end
    end

    @logmsg LogLevel(-4) string("Stored ",
        length(master_problem.var_manager.active_dynamic_list),
        " active variables")
end

function record_constraints_info(prob_info::ProblemSetupInfo,
                                 master_problem::CompactProblem)

    #Dynamic constraints of the master (cuts and branching constraints)
    for constr in master_problem.constr_manager.active_dynamic_list
        if isa(constr, MasterBranchConstr)
            push!(prob_info.active_branching_constraints_info,
                ConstraintInfo(constr, Active))
        # elseif isa(constr, MasterConstr)
            # push!(prob_info.suitable_master_cuts_info,
                  # ConstraintInfo(constr, Active))
        end
    end

    @logmsg LogLevel(-4) string("Stored ",
        length(master_problem.constr_manager.active_dynamic_list),
        " active constraints")
end    

function record_problem_info(alg::AlgToSetdownNodeFully, node::Node)
    prob_info = ProblemSetupInfo()
    master_problem = alg.extended_problem.master_problem

    record_variables_info(prob_info, master_problem,
                          alg.extended_problem.pricing_vect)
    record_constraints_info(prob_info, master_problem)

    node.problem_setup_info = prob_info

end

#############################
##### AlgToSetupNode ########
#############################

@hl mutable struct AlgToSetupNode <: AlgLike
    extended_problem::ExtendedProblem
    problem_setup_info::ProblemSetupInfo
    branch_from_father::Vector{MasterBranchConstr}
    # is_all_columns_active::Bool
end

function AlgToSetupNodeBuilder(extended_problem::ExtendedProblem)
    return (extended_problem, ProblemSetupInfo(0))
end

function AlgToSetupNodeBuilder(extended_problem::ExtendedProblem,
             problem_setup_info::ProblemSetupInfo,
             branch_from_father::Vector{MasterBranchConstr})
    return (extended_problem, problem_setup_info, branch_from_father)
end

@hl mutable struct AlgToSetupBranchingOnly <: AlgToSetupNode end

function AlgToSetupBranchingOnlyBuilder(extended_problem::ExtendedProblem,
             problem_setup_info::ProblemSetupInfo,
             branch_from_father::Vector{MasterBranchConstr})
    return AlgToSetupNodeBuilder(extended_problem, problem_setup_info,
                                 branch_from_father)
end

function prepare_branching_constraints_added_by_father(alg::AlgToSetupNode)
    master = alg.extended_problem.master_problem
    added_to_problem = Constraint[]
    for constr in alg.branch_from_father
        constr.status = Active
        add_constraint(master, constr)
        push!(added_to_problem, constr)
        @logmsg LogLevel(-4) string("Adding constraint ",
            constr.vc_ref, " generated when branching.")
    end
    return added_to_problem
end

function prepare_branching_constraints(alg::AlgToSetupBranchingOnly)
    return prepare_branching_constraints_added_by_father(alg)
end

function run(alg::AlgToSetupBranchingOnly)

    @logmsg LogLevel(-4) "AlgToSetupBranchingOnly"

    # apply_subproblem_info()
    # fill_local_branching_constraints()
    added_cuts_to_problem = prepare_branching_constraints(alg)
    apply_var_constr_info(alg.problem_setup_info)

    # This function updates the MOI models with the
    # current active rows and columns and their bounds
    update_formulation(alg.extended_problem, Constraint[], added_cuts_to_problem,
                       Variable[], Variable[], Variable[],
                       alg.problem_setup_info.modified_static_vars_info)

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

function find_first_in_problem_setup(var_info_vec::Vector{VariableSmallInfo},
        vc_ref::Int)
    for i in 1:length(var_info_vec)
        if vc_ref == var_info_vec[i].variable.vc_ref
            return i
        end
    end
    return 0
end

function prepare_branching_constraints(alg::AlgToSetupFull)
    master = alg.extended_problem.master_problem
    in_problem = master.constr_manager.active_dynamic_list
    in_setup_info = alg.problem_setup_info.active_branching_constraints_info

    removed_from_problem = Constraint[]
    added_to_problem = Constraint[]
    for i in length(in_problem):-1:1
        constr = in_problem[i]
        if typeof(constr) <: MasterBranchConstr
            idx = find_first_in_problem_setup(in_setup_info, constr.vc_ref)
            if idx == 0
                update_constr_status(master, constr, Unsuitable)
                push!(removed_from_problem, constr)
                @logmsg LogLevel(-4) string("constraint ", constr.vc_ref,
                                            " deactivated")
            else
                @logmsg LogLevel(-4) string("constraint ", constr.vc_ref,
                                            " is in branching tree of node")
            end
        end
    end
    for i in 1:length(in_setup_info)
        constr_info = in_setup_info[i]
        constr = constr_info.constraint
        if typeof(constr) <: MasterBranchConstr
            idx = find_first(in_problem, constr.vc_ref)
            if idx == 0
                update_constr_status(master, constr, Active)
                push!(added_to_problem, constr)
                @logmsg LogLevel(-4) string("added constraint ", constr.vc_ref)
            else
                @logmsg LogLevel(-4) string("constraint ", constr.vc_ref,
                                            " is already in problem")
            end
        end
    end
    branch_from_father = prepare_branching_constraints_added_by_father(alg)
    return removed_from_problem, vcat(added_to_problem, branch_from_father)
end

function prepare_master_columns(alg::AlgToSetupFull)
    master = alg.extended_problem.master_problem
    in_problem = master.var_manager.active_dynamic_list
    in_setup_info = alg.problem_setup_info.suitable_master_columns_info

    removed_from_problem = Variable[]
    added_to_problem = Variable[]
    for i in length(in_problem):-1:1
        col = in_problem[i]
        if typeof(col) <: MasterColumn
            idx = find_first_in_problem_setup(in_setup_info, col.vc_ref)
            if idx == 0
                update_var_status(master, col, Unsuitable)
                push!(removed_from_problem, col)
                @logmsg LogLevel(-4) string("column ", col.vc_ref,
                                            " deactivated")
            else
                @logmsg LogLevel(-4) string("column ", col.vc_ref,
                                            " is in branching tree of node")
            end
        end
    end
    for i in 1:length(in_setup_info)
        col_info = in_setup_info[i]
        col = col_info.variable
        if typeof(col) <: MasterColumn
            idx = find_first(in_problem, col.vc_ref)
            if idx == 0
                update_var_status(master, col, Active)
                push!(added_to_problem, col)
                @logmsg LogLevel(-4) string("added column ", col.vc_ref)
            else
                @logmsg LogLevel(-4) string("column ", col.vc_ref,
                                            " is already in problem")
            end
        end
    end
    return removed_from_problem, added_to_problem
end

function update_formulation(extended_problem::ExtendedProblem,
                            removed_cuts_from_problem::Vector{Constraint},
                            added_cuts_to_problem::Vector{Constraint},
                            removed_cols_from_problem::Vector{Variable},
                            added_cols_to_problem::Vector{Variable},
                            changed_bounds::Vector{Variable},
                            modified_static_vars_info::Vector{VariableInfo})

    master_update = ProblemUpdate(
        removed_cuts_from_problem,
        added_cuts_to_problem, removed_cols_from_problem,
        added_cols_to_problem, changed_bounds
    )
    optimizer = extended_problem.master_problem.optimizer
    is_relaxed = extended_problem.master_problem.is_relaxed
    update_moi_optimizer(optimizer, is_relaxed, master_update)
    # Update bounds that changed in all extended problem
    # for info in modified_static_vars_info
    #     v = info.variable
    #     enforce_current_bounds_in_optimizer(get_problem(extended_problem, v.prob_ref).optimizer, v)
    # end
end

function run(alg::AlgToSetupFull)

    @logmsg LogLevel(-4) "AlgToSetupFull"

    # The two next function only update the managers
    # and the statuses, all memberships are already up-to-date
    removed_cuts_from_problem, added_cuts_to_problem =
        prepare_branching_constraints(alg)
    removed_cols_from_problem, added_cols_to_problem =
        prepare_master_columns(alg)

    # This function updated the infos with the ones stored by father
    apply_var_constr_info(alg.problem_setup_info)

    # This function updates the MOI models with the
    # current active rows and columns and their bounds
    update_formulation(alg.extended_problem,
                       removed_cuts_from_problem,
                       added_cuts_to_problem, removed_cols_from_problem,
                       added_cols_to_problem, Variable[],
                       alg.problem_setup_info.modified_static_vars_info)

    return false

end

#############################
#### AlgToSetupRootNode #####
#############################

@hl mutable struct AlgToSetupRootNode <: AlgToSetupNode end

function AlgToSetupRootNodeBuilder(problem::ExtendedProblem,
        problem_setup_info::ProblemSetupInfo)
    return AlgToSetupNodeBuilder(problem, problem_setup_info)
end

function set_cur_bounds(extended_problem::ExtendedProblem)
    master = extended_problem.master_problem
    @assert isempty(master.var_manager.unsuitable_static_list)
    @assert isempty(master.var_manager.unsuitable_dynamic_list)
    @assert isempty(master.var_manager.active_dynamic_list)
    @assert isempty(master.constr_manager.unsuitable_static_list)
    @assert isempty(master.constr_manager.unsuitable_dynamic_list)
    @assert isempty(master.constr_manager.active_dynamic_list)
    for var in master.var_manager.active_static_list
        set_default_currents(var)
    end
    for subprob in extended_problem.pricing_vect
        for var in subprob.var_manager.active_static_list
            set_global_bounds(var,
                extended_problem.pricing_convexity_lbs[subprob].cost_rhs,
                extended_problem.pricing_convexity_ubs[subprob].cost_rhs)
            set_default_currents(var)
        end
    end
end

function run(alg::AlgToSetupRootNode)
    # @callsuper probleminfeasible = AlgToSetupNode::run(node)

    # reset_root_convexity_master_constr(alg)
    # reset_master_columns(alg)
    # reset_non_stab_artificial_variables(alg)
    @logmsg LogLevel(-4) "AlgToSetupRootNode"
    set_cur_bounds(alg.extended_problem)

    return false
end

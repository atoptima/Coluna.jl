function create_array_of_vars(n::Int, var_type::DataType)
    vars = CL.Variable[]
    vc_counter = CL.VarConstrCounter(0)
    for i in 1:n
        if var_type == CL.Variable
            var = CL.Variable(vc_counter, string("var_", i), 1.0, 'P', 'B',
                              's', 'U', 2.0, 0.0, 1.0)
        elseif var_type == CL.MasterVar
            var = CL.MasterVar(vc_counter, string("var_", i), 1.0, 'P', 'B',
                              's', 'U', 2.0, 0.0, 1.0)
            
        elseif var_type == CL.SubprobVar
            var = CL.SubprobVar(vc_counter, string("var_", i), 1.0, 'P', 'C', 's', 'U', 2.0, -Inf, Inf, -30.0, 30.0, -25.0, 25.0)
        end
        push!(vars, var)
    end
    return vars
end

function create_array_of_constrs(n::Int, constr_type::DataType)
    constrs = CL.Constraint[]
    vc_counter = CL.VarConstrCounter(0)
    for i in 1:n
        if constr_type == CL.Constraint
            constr = CL.Constraint(vc_counter, string("C_", i), 5.0, 'L', 'M', 's')
        elseif constr_type == CL.MasterConstr
            constr = CL.MasterConstr(vc_counter, string("C_", i), 5.0, 'L', 'M', 's')
        elseif constr_type == CL.BranchConstr
            constr = CL.BranchConstr(vc_counter, string("C_", i), 5.0, 'L', 3)
        end            
        push!(constrs, constr)
    end
    return constrs
end

function create_problem_empty()
    prob_counter = CL.ProblemCounter(0)
    vc_counter = CL.VarConstrCounter(0)
    return CL.SimpleCompactProblem(prob_counter, vc_counter)
end

function create_problem_knapsack(feasible::Bool = true, MIP::Bool = true, unbounded::Bool = false)
    n = 5
    w = [2.0, 3.0, 2.0, 4.0, 3.0]
    p = [-1.0, -5.0, -2.0, -6.0, -2.0]
    C = 7.0
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    
    knp = CL.Constraint(problem.counter, "knp", C, 'L', 'M', 's')
    CL.add_constraint(problem, knp)

    x_vars = Vector{CL.Variable}()
    if MIP
        var_type = 'I'
    else
        var_type = 'C'
    end
    if unbounded
        UB = Inf
    else
        UB = 1.0
    end
    for i in 1:n
        x_var = CL.MasterVar(problem.counter, string("x(", i, ")"),
                             p[i], 'P', var_type, 's', 'U', 1.0, 0.0, UB)
        push!(x_vars, x_var)
        CL.add_variable(problem, x_var)
        CL.add_membership(problem, x_var, knp, w[i])
    end

    if !feasible
        infeas = CL.Constraint(problem.counter, "infeas", C+1, 'G', 'M', 's')
        CL.add_constraint(problem, infeas)
        for i in 1:n
            CL.add_membership(problem, x_vars[i], infeas, w[i])
        end
    end

    return problem, x_vars, knp
end

function create_extended_problem()
    params = CL.Params()
    callback = CL.Callback()
    prob_counter = CL.ProblemCounter(-1)
    vc_counter = CL.VarConstrCounter(0)
    return CL.ExtendedProblem(prob_counter, vc_counter, params,
                              params.cut_up, params.cut_lo)
end

function create_sols_and_bounds(n_vars::Int)
    sols_and_bounds = CL.SolsAndBounds(Inf, Inf, -Inf,
        -Inf, Dict{CL.Variable, Float64}(), Dict{CL.Variable, Float64}(),
        Dict{CL.Constraint, Float64}(), false)
    vars = create_array_of_vars(n_vars, CL.Variable)
    for i in 1:length(vars)
        sols_and_bounds.alg_inc_ip_primal_sol_map[vars[i]] = 2*i
    end
    for i in 1:length(vars)
        sols_and_bounds.alg_inc_ip_primal_sol_map[vars[i]] = 0.5*i
    end
    return sols_and_bounds
end

function create_node(extended_problem::CL.ExtendedProblem, with_parent = false)
    params = extended_problem.params
    problem_setup_info = CL.ProblemSetupInfo(0)
    stab_info  = CL.StabilizationInfo(extended_problem.master_problem, params)
    master_lp_basis = CL.LpBasisRecord("Basis0")

    ## use parameters to define how the tree will be solved
    # node_eval_info = ColGenEvalInfo(stab_info, master_lp_basis, Inf)
    node_eval_info = CL.LpEvalInfo(stab_info)

    return CL.Node(extended_problem, extended_problem.dual_inc_bound,
        problem_setup_info, node_eval_info)
end

function create_sols_and_bounds()
    return CL.SolsAndBounds(Inf, Inf, -Inf, -Inf, Dict{CL.Variable, Float64}(),
                            Dict{CL.Variable, Float64}(),
                            Dict{CL.Constraint, Float64}(), false)
end

function create_cg_extended_problem()
    model = CL.ModelConstructor()
    params = model.params
    callback = model.callback
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    prob_counter = model.prob_counter
    master_problem = extended_problem.master_problem
    masteroptimizer = GLPK.Optimizer()
    model.problemidx_optimizer_map[master_problem.prob_ref] = masteroptimizer

    pricingoptimizer = GLPK.Optimizer()
    pricingprob = CL.SimpleCompactProblem(prob_counter, counter)
    push!(extended_problem.pricing_vect, pricingprob)
    model.problemidx_optimizer_map[pricingprob.prob_ref] = pricingoptimizer

    art_glob_pos_var = extended_problem.artificial_global_pos_var 
    art_glob_neg_var = extended_problem.artificial_global_neg_var

    CL.set_model_optimizers(model)
    CL.add_artificial_variables(extended_problem)
    CL.add_convexity_constraints(extended_problem, pricingprob, 0, 3)

    #subproblem vars
    x1 = CL.SubprobVar(counter, "x1", 0.0, 'P', 'B', 's', 'U', 1.0,
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    x2 = CL.SubprobVar(counter, "x2", 0.0, 'P', 'B', 's', 'U', 1.0,
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    x3 = CL.SubprobVar(counter, "x3", 0.0, 'P', 'B', 's', 'U', 1.0,
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    y = CL.SubprobVar(counter, "y", 1.0, 'P', 'B', 's', 'U', 1.0,
                       1.0, 1.0, -Inf, Inf, -Inf, Inf)

    CL.add_variable(pricingprob, x1)
    CL.add_variable(pricingprob, x2)
    CL.add_variable(pricingprob, x3)
    CL.add_variable(pricingprob, y)

    #subproblem constrs
    knp_constr = CL.Constraint(counter, "knp_constr", 0.0, 'L', 'M', 's')

    CL.add_constraint(pricingprob, knp_constr)

    CL.add_membership(pricingprob, x1, knp_constr, 3.0)
    CL.add_membership(pricingprob, x2, knp_constr, 4.0)
    CL.add_membership(pricingprob, x3, knp_constr, 5.0)
    CL.add_membership(pricingprob, y, knp_constr, -8.0)

    # master var
    art_glob_pos_var = extended_problem.artificial_global_pos_var
    art_glob_neg_var = extended_problem.artificial_global_neg_var

    # master constraints
    cov_1_constr = CL.MasterConstr(master_problem.counter, "cov_1_constr", 1.0,
                                   'G', 'M', 's')
    cov_2_constr = CL.MasterConstr(master_problem.counter, "cov_2_constr", 1.0,
                                   'G', 'M', 's')
    cov_3_constr = CL.MasterConstr(master_problem.counter, "cov_3_constr", 1.0,
                                   'G', 'M', 's')

    CL.add_constraint(master_problem, cov_1_constr)
    CL.add_constraint(master_problem, cov_2_constr)
    CL.add_constraint(master_problem, cov_3_constr)

    CL.add_membership(master_problem, x1, cov_1_constr, 1.0)
    CL.add_membership(master_problem, x2, cov_2_constr, 1.0)
    CL.add_membership(master_problem, x3, cov_3_constr, 1.0)

    CL.add_membership(master_problem, art_glob_pos_var, cov_1_constr, 1.0)
    CL.add_membership(master_problem, art_glob_pos_var, cov_2_constr, 1.0)
    CL.add_membership(master_problem, art_glob_pos_var, cov_3_constr, 1.0)
    return extended_problem
end

function get_output_from_function(f::Function, args...)
    backup_stdout = stdout
    (rd, wr) = redirect_stdout()
    f(args...)
    close(wr)
    s = String(readavailable(rd))
    close(rd)
    redirect_stdout(backup_stdout)
    return s
end

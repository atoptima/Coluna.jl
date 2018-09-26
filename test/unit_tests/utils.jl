function create_array_of_vars(n::Int, var_type::DataType)
    vars = CL.Variable[]
    vc_counter = CL.VarConstrCounter(0)
    for i in 1:n
        if var_type == CL.Variable
            var = CL.Variable(vc_counter, string("var_", i), 1.0, 'P', 'B',
                              's', 'U', 2.0, 0.0, 1.0)
        elseif var_type == CL.SubprobVar
            var = CL.SubprobVar(vc_counter, string("var_", i), 1.0, 'P', 'C', 's', 'U', 2.0, -Inf, Inf, -30.0, 30.0, -25.0, 25.0)
        end
        push!(vars, var)
    end
    return vars
end

function create_array_of_constrs(n::Int)
    constrs = CL.Constraint[]
    vc_counter = CL.VarConstrCounter(0)
    for i in 1:n
        constr = CL.Constraint(vc_counter, string("C_", i), 5.0, 'L', 'M', 's')
        push!(constrs, constr)
    end
    return constrs
end

function create_problem_empty()
    prob_counter = CL.ProblemCounter(0)
    vc_counter = CL.VarConstrCounter(0)
    return CL.SimpleCompactProblem(prob_counter, vc_counter)
end

function create_problem_1()
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
    for i in 1:n
        x_var = CL.MasterVar(problem.counter, string("x(", i, ")"),
                             p[i], 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
        push!(x_vars, x_var)
        CL.add_variable(problem, x_var)
        CL.add_membership(problem, x_var, knp, w[i])
    end

    return problem, x_vars, knp
end

function _get_benders_var_ids(reform::Reformulation)
    varids = Dict{String,VarId}()

    master = Coluna.MathProg.getmaster(reform)
    for (varid, _) in Coluna.MathProg.getvars(master)
        varids[Coluna.MathProg.getname(master, varid)] = varid
    end

    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        for (varid, _) in Coluna.MathProg.getvars(sp)
            varids[Coluna.MathProg.getname(sp, varid)] = varid
        end
    end
    return varids
end

function benders_form_A()
    # using JuMP, GLPK
    # m = Model(GLPK.Optimizer)
    # @variable(m, x[1:2]>= 0)
    # @variable(m, y[1:2] >= 0)
    # @constraint(m, -x[1] + 4x[2] + 2y[1] + 3y[2] >= 2)
    # @constraint(m, x[1] + 3x[2] + y[1] + y[2] >= 3)
    # @objective(m, Min, x[1] + 4x[2] + 2y[1] + 3y[2])
    # optimize!(m)
    # objective_value(m)
    # value.(x)
    # value.(y)

    form = """
    master
        min
        x1 + 4x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 2y1 + 3y2 + z
        s.t.
        -x1 + 4x2 + 2y1 + 3y2 >= 2 {BendTechConstr}
        x1 + 3x2 + y1 + y2 >= 3 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

function benders_form_B()
    #using JuMP, GLPK
    #m = Model(GLPK.Optimizer)
    #@variable(m, x[1:2] >= 0)
    #@variable(m, y[1:2] >= 0)
    #@constraint(m, -x[1] + x[2] + y[1] - 0.5y[2] >= 4)
    #@constraint(m, 2x[1] + 1.5x[2] + y[1] + y[2] >= 5)
    #@objective(m, Min, x[1] + 2x[2] + 1.5y[1] + y[2])
    #optimize!(m)
    #objective_value(m)
    #value.(x)
    #value.(y)
    form = """
    master
        min
        x1 + 2x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 1.5y1 + y2 + z
        s.t.
        -x1 + x2 + y1 - 0.5y2 >= 4 {BendTechConstr}
        2x1 + 1.5x2 + y1 + y2 >= 5 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

function benders_form_C()
   #using JuMP, GLPK
   #m = Model(GLPK.Optimizer)
   #@variable(m, x[1:2] >= 0)
   #@variable(m, y[1:4] >= 0) #y1 y2 -> 1st sp, y3, y4 -> 2nd sp
   #@constraint(m, 2x[1] - x[2] + 0.5y[1] - y[2] >= 5)
   #@constraint(m, x[1] + 3x[2] - 1.5y[3] + y[4] >= 3)
   #@objective(m, Min, 6x[1] + x[2] + 1.5y[1] + y[2] + 1.5y[3] + 0.5y[4])
   #optimize!(m)
   #objective_value(m)
   #value.(x)
   #value.(y)
   form = """
    master
        min
        6x1 + 1x2 + z1 + z2
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 1.5y1 + y2 + z1
        s.t.
        2x1 - x2 + 0.5y1 - y2 >= 5 {BendTechConstr}
        y1 + y2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 1.5y3 + 0.5y4 + z2
        s.t.
        1x1 + 3x2 - 1.5y3 + 1y4 >= 3 {BendTechConstr}
        y3 + y4 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z1, z2
        second_stage
            y1, y2, y3, y4
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
        y3 >= 0
        y4 >= 0
   """
   env, _, _, _, reform = reformfromstring(form)
   return env, reform, _get_benders_var_ids(reform)

end

function benders_form_max()
    #using JuMP, GLPK
    #m = Model(GLPK.Optimizer)
    #@variable(m, x[1:2] >= 0)
    #@variable(m, y[1:2] >= 0)
    #@constraint(m, x[1] - x[2] - y[1] + 0.5y[2] <= -4)
    #@constraint(m, -2x[1] - 1.5x[2] - y[1] - y[2] <= -5)
    #@objective(m, Max, -x[1] - 2x[2] - 1.5y[1] - y[2])
    #optimize!(m)
    #objective_value(m)
    #value.(x)
    #value.(y)
    form = """
    master
        max
        -x1 - 2x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        max
        0x1 + 0x2 - 1.5y1 - y2 + z
        s.t.
        x1 - x2 - y1 + 0.5y2 <= -4 {BendTechConstr}
        -2x1 - 1.5x2 - y1 - y2 <= -5 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

function benders_form_infeasible_master()
    #A infeasible master
    #using JuMP, GLPK
    #m = Model(GLPK.Optimizer)
    #@variable(m, x[1:2] >= 0, Int)
    #@variable(m, y[1:2] >= 0)
    #@constraint(m, x[1] + x[2] <= -1)
    #@constraint(m, -x[1] + 4x[2] + 2y[1] + 3y[2] >= 2)
    #@constraint(m, x[1] + 3x[2] + y[1] + y[2] >= 3)
    #@objective(m, Min, x[1] + 4x[2] + 2y[1] + 3y[2])
    #optimize!(m)
    #objective_value(m)
    #value.(x)
    #value.(y)

    form = """
    master
        min
        x1 + 4x2 + z
        s.t.
        x1 + x2 >= 0
        x1 + x2 <= -1

    benders_sp
        min
        0x1 + 0x2 + 2y1 + 3y2 + z
        s.t.
        -x1 + 4x2 + 2y1 + 3y2 >= 2 {BendTechConstr}
        x1 + 3x2 + y1 + y2 >= 3 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)

end

function benders_form_infeasible_sp()
    #A infeasible subproblem
    # using JuMP, GLPK
    # m = Model(GLPK.Optimizer)
    # @variable(m, x[1:2]>= 0, Int)
    # @variable(m, y[1:2] >= 0)
    # @constraint(m, -x[1] + 4x[2] + 2y[1] + 3y[2] >= 2)
    # @constraint(m, x[1] + 3x[2] + y[1] + y[2] >= 3)
    # @constraint(m, 7x[2] + 3y[1] + 4y[2] <= 4)
    # @objective(m, Min, x[1] + 4x[2] + 2y[1] + 3y[2])
    # optimize!(m)
    # objective_value(m)
    # value.(x)
    # value.(y)

    form = """
    master
        min
        x1 + 4x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 2y1 + 3y2 + a1 + a2 + a3 + a4 + z
        s.t.
        -x1 + 4x2 + 2y1 + 3y2 + a1 >= 2 {BendTechConstr}
        x1 + 3x2 + y1 + y2 + a2 >= 3 {BendTechConstr}
        7x2 + 3y1 + 4y2 - a3 <= 4 {BendTechConstr}
        y1 + y2 + a4 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
        second_stage_artificial
            a1, a2, a3, a4
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
        a1 >= 0
        a2 >= 0
        a3 >= 0
        a4 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

function benders_form_lower_bound()
    #A with high lower bound on y
    #using JuMP, GLPK
    #m = Model(GLPK.Optimizer)
    #@variable(m, x[1:2]>= 0)
    #@variable(m, y[1:2] >= 5)
    #@constraint(m, -x[1] + 4x[2] + 2y[1] + 3y[2] >= 2)
    #@constraint(m, x[1] + 3x[2] + y[1] + y[2] >= 3)
    #@objective(m, Min, x[1] + 4x[2] + 2y[1] + 3y[2])
    #optimize!(m)
    #objective_value(m)
    #value.(x)
    #value.(y)

    form = """
    master
        min
        x1 + 4x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 2y1 + 3y2 + z
        s.t.
        -x1 + 4x2 + 2y1 + 3y2 >= 2 {BendTechConstr}
        x1 + 3x2 + y1 + y2 >= 3 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 5
        y2 >= 5
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

function benders_form_upper_bound()
    # using JuMP, GLPK
    # m = Model(GLPK.Optimizer)
    # @variable(m, x[1:2] >= 0)
    # @variable(m, 1 >= y[1:2] >= 0)
    # @constraint(m, x[1] - x[2] - y[1] + 0.5y[2] <= -4)
    # @constraint(m, -2x[1] - 1.5x[2] - y[1] - y[2] <= -5)
    # @objective(m, Max, -x[1] - 2x[2] - 1.5y[1] - y[2])
    # optimize!(m)
    # objective_value(m)
    # value.(x)
    # value.(y)
    form = """
    master
        max
        -x1 - 2x2 - 1.5y1 - y2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        max
        0x1 + 0x2 - 1.5y1 - y2 + z - a1 - a2 - a3
        s.t.
        x1 - x2 - y1 + 0.5y2 - a1 <= -4 {BendTechConstr}
        -2x1 - 1.5x2 - y1 - y2 - a2 <= -5 {BendTechConstr}
        y1 + y2 + a3 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
        second_stage_artificial
            a1, a2, a3

    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        1 >= y1 >= 0
        1 >= y2 >= 0
        a1 >= 0
        a2 >= 0
        a3 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

function benders_form_unbounded_master()
    form = """
    master
        min
        -1x1 + 4x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 + 2y1 + 3y2 + z
        s.t.
        x1 + 4x2 + 2y1 + 3y2 >= 2 {BendTechConstr}
        x1 + 3x2 + y1 + y2 >= 3 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)

end

function benders_form_unbounded_sp()
    form = """
    master
        min
        x1 + 4x2 + z
        s.t.
        x1 + x2 >= 0

    benders_sp
        min
        0x1 + 0x2 - 2y1 + 3y2 + z
        s.t.
        -x1 + 4x2 + 2y1 + 3y2 >= 2 {BendTechConstr}
        x1 + 3x2 + y1 + y2 >= 3 {BendTechConstr}
        y1 + y2 >= 0

    integer
        first_stage
            x1, x2

    continuous
        second_stage_cost
            z
        second_stage
            y1, y2
    
    bounds
        -Inf <= z <= Inf
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform, _get_benders_var_ids(reform)
end

# A with continuous first stage finds optimal solution
function benders_iter_default_A_continuous()
    #env, reform = benders_simple_example()
    env, reform, varids = benders_form_A()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 3.7142857142857144
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.8571428571428571
    @test result.ip_primal_sol[varids["x2"]] ≈ 0.7142857142857143
    @test result.ip_primal_sol[varids["y1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_iter_default_A_continuous)

# A with integer first stage finds optimal solution
function benders_iter_default_A_integer()
    #env, reform = benders_simple_example()
    env, reform, varids = benders_form_A()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10,
        restr_master_solve_alg = Coluna.Algorithm.SolveIpForm()
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 4.0
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["x2"]] ≈ 1.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_iter_default_A_integer)

# B with continuous first stage finds optimal solution
function benders_iter_default_B_continuous()
    #env, reform = benders_simple_example()
    env, reform, varids = benders_form_B()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 6.833333333333333
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.33333333333333337
    @test result.ip_primal_sol[varids["x2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 4.333333333333333
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_iter_default_B_continuous)

# B with integer first stage finds optimal solution
function benders_iter_default_B_integer()
    #env, reform = benders_simple_example()
    env, reform, varids = benders_form_B()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10,
        restr_master_solve_alg = Coluna.Algorithm.SolveIpForm()
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 7
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["x2"]] ≈ 2.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 2.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_iter_default_B_integer)

# C with continuous first stage finds optimal solution
function benders_sp_C_continuous()
    env, reform, varids = benders_form_C()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 20
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 15.25
    @test result.ip_primal_sol[varids["x1"]] ≈ 2.5
    @test result.ip_primal_sol[varids["x2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y3"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y4"]] ≈ 0.5
end
register!(unit_tests, "benders_default", benders_sp_C_continuous)

# C with integer first stage finds optimal solution
function benders_sp_C_integer()
    env, reform, varids = benders_form_C()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10,
        restr_master_solve_alg = Coluna.Algorithm.SolveIpForm()
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 15.5
    @test result.ip_primal_sol[varids["x1"]] ≈ 2.0
    @test result.ip_primal_sol[varids["x2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 2.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y3"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y4"]] ≈ 1.0
end
register!(unit_tests, "benders_default", benders_sp_C_integer)

function benders_default_max_form_continuous()
    env, reform, varids = benders_form_max()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ -6.833333333333333
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.33333333333333337
    @test result.ip_primal_sol[varids["x2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 4.333333333333333
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_default_max_form_continuous)

function benders_default_max_form_integer()
    env, reform, varids = benders_form_max()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10,
        restr_master_solve_alg = Coluna.Algorithm.SolveIpForm()
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ -7
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["x2"]] ≈ 2.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 2.0000000000000004
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_default_max_form_integer)

# A formulation with infeasible master constraint
function benders_default_infeasible_master()
    env, reform, _ = benders_form_infeasible_master()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.infeasible == true

end
register!(unit_tests, "benders_default", benders_default_infeasible_master)

# A formulation with infeasible sp constraint
function benders_default_infeasible_sp()
    env, reform, _ = benders_form_infeasible_sp()
    master = Coluna.MathProg.getmaster(reform)    
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.infeasible == true

end
register!(unit_tests, "benders_default", benders_default_infeasible_sp)

# form A with lower bound on y variables equal to 5
function benders_min_lower_bound()
    env, reform, varids = benders_form_lower_bound()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 25
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["x2"]] ≈ 0.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 5.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 5.0
end
register!(unit_tests, "benders_default", benders_min_lower_bound)


# max form B with upper bound on y variables equal to 1
function benders_max_upper_bound()
    env, reform, varids = benders_form_upper_bound()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10,
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ -7.5
    @test result.ip_primal_sol[varids["x1"]] ≈ 0.0
    @test result.ip_primal_sol[varids["x2"]] ≈ 3.0
    @test result.ip_primal_sol[varids["y1"]] ≈ 1.0
    @test result.ip_primal_sol[varids["y2"]] ≈ 0.0
end
register!(unit_tests, "benders_default", benders_max_upper_bound)

# benders throws error
function benders_default_unbounded_master()
    env, reform, _ = benders_form_unbounded_master()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(reform, alg;
        print = false
    )
    Coluna.set_optim_start_time!(env)

    @test_throws Coluna.Benders.UnboundedError Coluna.Benders.run_benders_loop!(ctx, env)
end
register!(unit_tests, "benders_default", benders_default_unbounded_master)

# benders throws error
function benders_default_unbounded_sp()
    env, reform, _ = benders_form_unbounded_sp()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(reform, alg; print = false)
    Coluna.set_optim_start_time!(env)

    @test_throws Coluna.Benders.UnboundedError Coluna.Benders.run_benders_loop!(ctx, env)
end
register!(unit_tests, "benders_default", benders_default_unbounded_sp)



function benders_default_loc_routing()
    env, reform = benders_form_location_routing()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    #ClMP.relax_integrality!(master)
    @show master
    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
        @show sp
    end
    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 100
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 293.5
end
register!(unit_tests, "benders_default", benders_default_loc_routing)



function benders_default_loc_routing_infeasible()
    env, reform = benders_form_location_routing_infeasible()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    #ClMP.relax_integrality!(master)
    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 100
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.infeasible == true
end
register!(unit_tests, "benders_default", benders_default_loc_routing_infeasible)

function benders_default_location_routing_subopt()
    env, reform = benders_form_location_routing_subopt()
    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    #ClMP.relax_integrality!(master)
    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 100
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 386.0
end
register!(unit_tests, "benders_default", benders_default_location_routing_subopt)


function test_two_identicals_cut_at_two_iterations_failure()
    env, reform = benders_form_A()
    master = ClMP.getmaster(reform)
    sps = ClMP.get_benders_sep_sps(reform)
    spform = sps[3]
    spconstrids = Dict(CL.getname(spform, constr) => constrid for (constrid, constr) in CL.getconstrs(spform))
    spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 2
    )
    ctx = Coluna.Algorithm.BendersContext(
        reform, alg;
    )

    cut1 = ClMP.DualSolution(
        spform,
        map(x -> spconstrids[x], ["sp_c1", "sp_c2", "sp_c3"]),
        [1.5, 2.0, 4.0],
        map(x -> spvarids[x], ["y1", "y2"]),
        [1.0, 1.0],
        [ClMP.LOWER, ClMP.UPPER],
        1.0,
        ClB.FEASIBLE_SOL
    )
    lhs1 = Dict{ClMP.VarId, Float64}()
    rhs1 = 1.0
    cut2 = ClMP.DualSolution(
        spform,
        map(x -> spconstrids[x], ["sp_c1", "sp_c2", "sp_c3"]),
        [1.5, 2.0, 4.0],
        map(x -> spvarids[x], ["y1", "y2"]),
        [1.0, 1.0],
        [ClMP.LOWER, ClMP.UPPER],
        1.0,
        ClB.FEASIBLE_SOL
    )
    lhs2 = Dict{ClMP.VarId, Float64}()
    rhs2 = 1.5

    cuts = Coluna.Benders.set_of_cuts(ctx)
    for (sol, lhs, rhs) in Iterators.zip([cut1, cut2], [lhs1, lhs2], [rhs1, rhs2])
        cut = ClA.GeneratedCut(true, lhs, rhs, sol)
        sep_res = ClA.BendersSeparationResult(2.0, 3.0, nothing, false, false, nothing, cut, false, false)
        Coluna.Benders.push_in_set!(ctx, cuts, sep_res)
    end
    Coluna.Benders.insert_cuts!(reform, ctx, cuts)
    @test_throws Coluna.Algorithm.CutAlreadyInsertedBendersWarning Coluna.Benders.insert_cuts!(reform, ctx, cuts)

    # Coluna.set_optim_start_time!(env)
    # result = Coluna.Benders.run_benders_loop!(ctx, env)

    # @test result.mlp ≈ 3.7142857142857144
end
register!(unit_tests, "benders_default", test_two_identicals_cut_at_two_iterations_failure)



##########################################################################




## original MIP:
## min cx + dy s.t.
##  Ax >= b 
##  Tx + Qy >= r
##  x, y >= 0, x ∈ Z^n

## master:
## min cx + η
##  Ax >= B
##  < benders cuts >

## SP:
## min  dy
##  Tx* + Qy >= r
##  y >= 0

## π: dual sol
## η: contribution to the objective of the second-level variables
## feasibility cut: πTx >= πr
## optimality cut: η + πTx >= πr


struct TestBendersIterationContext <: Coluna.Benders.AbstractBendersContext
    context::ClA.BendersContext
    first_stage_sol::Dict{String, Float64} ## id of variable, value
    second_stage_sols::Dict{String, Float64} ##id of sp, id of variable, value
    second_stage_dual_vals::Dict{String, Float64} ##id of sp, value ## TODO: see if useless ?
end

Coluna.Benders.get_master(ctx::TestBendersIterationContext) = Coluna.Benders.get_master(ctx.context)
Coluna.Benders.get_reform(ctx::TestBendersIterationContext) = Coluna.Benders.get_reform(ctx.context)
Coluna.Benders.is_minimization(ctx::TestBendersIterationContext) = Coluna.Benders.is_minimization(ctx.context)
Coluna.Benders.get_benders_subprobs(ctx::TestBendersIterationContext) = Coluna.Benders.get_benders_subprobs(ctx.context)

## where to check stop condition ? 

## re-def if need to check something
Coluna.Benders.optimize_master_problem!(master, ctx::TestBendersIterationContext, env) = Coluna.Benders.optimize_master_problem!(master, ctx.context, env)

Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx::TestBendersIterationContext, env) = Coluna.Benders.treat_unbounded_master_problem_case!(master, ctx.context, env) 

Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx::TestBendersIterationContext, sp, mast_primal_sol) = Coluna.Benders.setup_separation_for_unbounded_master_case!(ctx.context, sp, mast_primal_sol) 


## TODO: redef to check cuts
Coluna.Benders.optimize_separation_problem!(ctx::TestBendersIterationContext, sp::Formulation{BendersSp}, env, unbounded_master) = Coluna.Benders.optimize_separation_problem!(ctx.context, sp, env, unbounded_master)

Coluna.Benders.master_is_unbounded(ctx::TestBendersIterationContext, second_stage_cost, unbounded_master_case) = Coluna.Benders.master_is_unbounded(ctx.context, second_stage_cost, unbounded_master_case)

## same
Coluna.Benders.treat_infeasible_separation_problem_case!(ctx::TestBendersIterationContext, sp::Formulation{BendersSp}, env, unbounded_master_case) = Coluna.Benders.treat_infeasible_separation_problem_case!(ctx.context, sp, env, unbounded_master_case)


Coluna.Benders.push_in_set!(ctx::TestBendersIterationContext, set::Coluna.Algorithm.CutsSet, sep_result::Coluna.Algorithm.BendersSeparationResult) = Coluna.Benders.push_in_set!(ctx.context, set, sep_result)

Coluna.Benders.push_in_set!(ctx::TestBendersIterationContext, set::Coluna.Algorithm.SepSolSet, sep_result::Coluna.Algorithm.BendersSeparationResult) = Coluna.Benders.push_in_set!(ctx.context, set, sep_result)

Coluna.Benders.insert_cuts!(reform, ctx::TestBendersIterationContext, cuts) = Coluna.Benders.insert_cuts!(reform, ctx.context, cuts)

Coluna.Benders.build_primal_solution(ctx::TestBendersIterationContext, mast_primal_sol, sep_sp_sols) = Coluna.Benders.build_primal_solution(ctx.context, mast_primal_sol, sep_sp_sols)

Coluna.Benders.benders_iteration_output_type(ctx::TestBendersIterationContext) = Coluna.Benders.benders_iteration_output_type(ctx.context)

Coluna.Benders.update_sp_rhs!(ctx::TestBendersIterationContext, sp, mast_primal_sol) =
Coluna.Benders.update_sp_rhs!(ctx.context, sp, mast_primal_sol)
Coluna.Benders.set_of_cuts(ctx::TestBendersIterationContext) = Coluna.Benders.set_of_cuts(ctx.context)  

Coluna.Benders.set_of_sep_sols(ctx::TestBendersIterationContext) = Coluna.Benders.set_of_sep_sols(ctx.context)


Coluna.Benders.build_primal_solution(ctx::TestBendersIterationContext, mast_primal_sol, sep_sp_sols) = Coluna.Benders.build_primal_solution(ctx.context, mast_primal_sol, sep_sp_sols)

## checks cuts

## stop criterion because of opt. sol found is matched
function benders_default_opt_stop()
    env, reform = benders_form_location_routing_fixed_opt()
    ## sol fully fixed
    ##expected sol
    first_stage_sol = Dict(
        "y1" => 0.5,
        "y2" => 0.0,  
        "y3" => 0.33333 
    )
    second_stage_sols = Dict(
        "x11" => 0.5, 
        "x12" => 0.5, 
        "x13" => 0.49999, 
        "x14" => 0.5, 
        "x31" => 0.33333, 
        "x32" => 0.33333, 
        "x33" => 0.16666, 
        "x34" => 1/3
    )

    second_stage_dual_vals = Dict(
        "sp" => 0.0 ## TODO change
    )

    alg = Coluna.Algorithm.BendersCutGeneration(
        max_nb_iterations = 10
    )
    ctx = TestBendersIterationContext(
        Coluna.Algorithm.BendersContext(
            reform, alg
        ),
        first_stage_sol,
        second_stage_sols,
        second_stage_dual_vals
    )

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    for (_, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_iteration!(ctx, 0, env, 0)
    @show result.ip_primal_sol
end
register!(unit_tests, "benders_default", benders_default_opt_stop, f = true)

## subopt 1st level solution, an optimality cut should be generated
## should call benders_form_location_routing_subopt with variables fixed
function benders_default_opt_cut()

end

## 1st level solution makes sp infeasible, an infeasibility cut should be returned 
## should call benders_form_location_routing_infeasible
function benders_default_infeas_cut()

end
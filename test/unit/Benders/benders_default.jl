# function benders_simple_example()
#     env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())
#     origform = Coluna.MathProg.create_formulation!(env, Coluna.MathProg.Original())

#     # Variables
#     vars = Dict{String, Coluna.MathProg.VarId}()
#     variables_infos = [
#         ("x1", 1.0, Coluna.MathProg.Integ),
#         ("x2", 4.0, Coluna.MathProg.Integ),
#         ("y1", 2.0, Coluna.MathProg.Continuous),
#         ("y2", 3.0, Coluna.MathProg.Continuous)
#     ]
#     for (name, cost, kind) in variables_infos
#         vars[name] = Coluna.MathProg.getid(Coluna.MathProg.setvar!(
#             origform, name, Coluna.MathProg.OriginalVar; cost = cost, lb = 0.0, kind = kind
#         ))
#     end

#     # Constraints
#     constrs = Dict{String, Coluna.MathProg.ConstrId}()
#     constraints_infos = [
#         ("c1", 2.0, Coluna.MathProg.Greater, Dict(vars["x1"] => -1.0, vars["x2"] => 4.0, vars["y1"] => 2.0, vars["y2"] => 3.0)),
#         ("c2", 3.0, Coluna.MathProg.Greater, Dict(vars["x1"] => 1.0, vars["x2"] => 3.0, vars["y1"] => 1.0, vars["y2"] => 1.0)),
#     ]
#     for (name, rhs, sense, members) in constraints_infos
#         constrs[name] = Coluna.MathProg.getid(Coluna.MathProg.setconstr!(
#             origform, name, Coluna.MathProg.OriginalConstr; rhs = rhs, sense = sense, members = members
#         ))
#     end

#     @show origform

#     # Decomposition tree
#     m = JuMP.Model()
#     BlockDecomposition.@axis(axis, [1])
#     tree = BlockDecomposition.Tree(m, BlockDecomposition.Benders, axis)
#     mast_ann = tree.root.master
#     sp_ann = BlockDecomposition.Annotation(tree, BlockDecomposition.BendersSepSp, BlockDecomposition.Benders, [])
#     BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[1], sp_ann)

#     # Benders annotations
#     ann = Coluna.Annotations()
#     ann.tree = tree
#     Coluna.store!(ann, mast_ann, Coluna.MathProg.getvar(origform, vars["x1"]))
#     Coluna.store!(ann, mast_ann, Coluna.MathProg.getvar(origform, vars["x2"]))
#     Coluna.store!(ann, sp_ann, Coluna.MathProg.getvar(origform, vars["y1"]))
#     Coluna.store!(ann, sp_ann, Coluna.MathProg.getvar(origform, vars["y2"]))
#     Coluna.store!(ann, sp_ann, Coluna.MathProg.getconstr(origform, constrs["c1"]))
#     Coluna.store!(ann, sp_ann, Coluna.MathProg.getconstr(origform, constrs["c2"]))

#     problem = Coluna.MathProg.Problem(env)
#     Coluna.MathProg.set_original_formulation!(problem, origform)

#     Coluna.reformulate!(problem, ann, env)
#     reform = Coluna.MathProg.get_reformulation(problem)
#     return env, reform
# end


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
    return env, reform
end


# function benders_form_B()
#     #using JuMP, GLPK
#     #m = Model(GLPK.Optimizer)
#     #@variable(m, x[1:2] >= 0)
#     #@variable(m, y[1:2] >= 0)
#     #@constraint(m, -x[1] + x[2] + y[1] - 0.5y[2] >= 4)
#     #@constraint(m, 2x[1] + 1.5x[2] + y[1] + y[2] >= 5)
#     #@objective(m, Min, x[1] + 2x[2] + 1.5y[1] + y[2])
#     #optimize!(m)
#     #objective_value(m)
#     #value.(x)
#     #value.(y)
#     form = """
#     master
#         min
#         x1 + 2x2 + 1.5y1 + 1y2 + z
#         s.t.
#         x1 + x2 >= 0

#     benders_sp
#         min
#         0x1 + 0x2 + 1.5y1 + y2 + z
#         s.t.
#         -x1 + x2 + y1 - 0.5y2 >= 4 {BendTechConstr}
#         2x1 + 1.5x2 + y1 + y2 >= 5 {BendTechConstr}
#         y1 + y2 >= 0

#     integer
#         first_stage
#             x1, x2

#     continuous
#         second_stage_cost
#             z
#         second_stage
#             y1, y2
    
#     bounds
#         -Inf <= z <= Inf
#         x1 >= 0
#         x2 >= 0
#         y1 >= 0
#         y2 >= 0
#     """
#     env, _, _, _, reform = reformfromstring(form)
#     return env, reform
# end


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
    return env, reform
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
   return env, reform

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
    return env, reform
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
    return env, reform

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
    return env, reform
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
    return env, reform
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
    return env, reform
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
    return env, reform

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
    return env, reform
end

# A with continuous first stage finds optimal solution
# TODO: check output
# x1 =  0.8571428571428571, x2 = 0.7142857142857143
# y1 = 0.0, y2 = 0.0
function benders_iter_default_A_continuous()
    #env, reform = benders_simple_example()
    env, reform = benders_form_A()

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
end
register!(unit_tests, "benders_default", benders_iter_default_A_continuous)

# A with integer first stage finds optimal solution
# expected output:
# mlp = 4.0
# x1 = 0.0, x2 = 1.0
# y1 = 0.0, y2 = 0.0
function benders_iter_default_A_integer()
    #env, reform = benders_simple_example()
    env, reform = benders_form_A()

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
end
register!(unit_tests, "benders_default", benders_iter_default_A_integer)


# B with continuous first stage finds optimal solution
# TODO: check output
# x1 = 0.33333333333333337, x2 = 0.0
# y1 = 4.333333333333333, y2 = 0.0
function benders_iter_default_B_continuous()
    #env, reform = benders_simple_example()
    env, reform = benders_form_B()

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
end
register!(unit_tests, "benders_default", benders_iter_default_B_continuous)

# B with integer first stage finds optimal solution
# expected output:
# mlp = 7
# x1 = 0.0, x2 = 2.0
# y1 =  2, y2 = 0
function benders_iter_default_B_integer()
    #env, reform = benders_simple_example()
    env, reform = benders_form_B()

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
end
register!(unit_tests, "benders_default", benders_iter_default_B_integer)

# C with continuous first stage
# Error occurs during test, TODO fix
# expected output:
# mlp = 15.25
# x1 = 2.5, x2 = 0.0
# y1 = y2 = y3 = 0.0, y4 = 0.5
function benders_sp_C_continuous()
    env, reform = benders_form_C()

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
end
register!(unit_tests, "benders_default", benders_sp_C_continuous)

# C with integer first stage
# Error occurs during test, TODO fix
# expected output:
# mlp = 15.25
# x1 = 2.0, x2 = 0.0
# y1 = 2.0, y2 = 0.0, y3 = 0.0, y4 = 1.0
function benders_sp_C_integer()
    env, reform = benders_form_C()

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
end
register!(unit_tests, "benders_default", benders_sp_C_integer)


# test FAIL
# expected output:
# x1 =  0.33333333333333337, x2 = 0.0
# y1 = 4.333333333333333, y2 = 0.0
# mlp = -6.833333333333333
function benders_default_max_form_continuous()
    env, reform = benders_form_max()
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
end
register!(unit_tests, "benders_default", benders_default_max_form_continuous)


# test FAIL
# expected output:
# x1 =  0.0, x2 = 2.0
# y1 = 2.0000000000000004, y2 = 0.0
# mlp = -7
function benders_default_max_form_integer()
    env, reform = benders_form_max()
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
end
register!(unit_tests, "benders_default", benders_default_max_form_integer)


# A formulation with infeasible master constraint
# test FAIL + I can't see the master constraints with @show master
function benders_default_infeasible_master()
    env, reform = benders_form_infeasible_master()
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
# ERROR during test, but maybe I don't check the infeasibility of the sp in a proper way ?
function benders_default_infeasible_sp()
    env, reform = benders_form_infeasible_sp()
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
# test FAIL, expected output:
# x1 = x2 = 0.0
# y1 = y2 = 5.0
# mlp = 25.0
function benders_min_lower_bound()
    env, reform = benders_form_lower_bound()
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

end
register!(unit_tests, "benders_default", benders_min_lower_bound)


# max form B with upper bound on y variables equal to 1
# test FAIL, expected output:
# x1 = 0, x2 = 3
# y1 = 1, y2 = 0
# mlp = -7.5
function benders_max_upper_bound()
    env, reform = benders_form_upper_bound()
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
end
register!(unit_tests, "benders_default", benders_max_upper_bound)


#TODO check if benders throws error
function benders_default_unbounded_master()
    env, reform = benders_form_unbounded_master()

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
        print = true,
        debug_print_master = true,
        debug_print_master_primal_solution = true,
        debug_print_master_dual_solution = true,
        debug_print_subproblem = true,
        debug_print_subproblem_primal_solution = true,
        debug_print_subproblem_dual_solution = true,
        debug_print_generated_cuts = true,
    )
    Coluna.set_optim_start_time!(env)

    @test_throws Coluna.Benders.UnboundedError Coluna.Benders.run_benders_loop!(ctx, env)
end
register!(unit_tests, "benders_default", benders_default_unbounded_master; x = true)



# TODO: check if benders throws error
function benders_default_unbounded_sp()
    env, reform = benders_form_unbounded_sp()

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
    ctx = Coluna.Algorithm.BendersPrinterContext(reform, alg)
    Coluna.set_optim_start_time!(env)

    @test_throws Coluna.Benders.UnboundedError Coluna.Benders.run_benders_loop!(ctx, env)
end
register!(unit_tests, "benders_default", benders_default_unbounded_sp; x = true)
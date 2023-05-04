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
        x1 + 2x2 + 1.5y1 + 1y2 + z
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
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
        print = true
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 3.7142857142857144
end
register!(unit_tests, "benders_default", benders_iter_default_A_continuous)

# A with integer first stage finds optimal solution
# Error occurs during test TODO fix
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
        separation_solve_alg = Coluna.Algorithm.SolveIpForm()
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
        print = true
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 4.0
end
register!(unit_tests, "benders_default", benders_iter_default_A_integer; x = true)


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
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
        print = true
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 6.833333333333333
end
register!(unit_tests, "benders_default", benders_iter_default_B_continuous)

# B with integer first stage finds optimal solution
# Error occurs during test TODO fix
# expected output:
# mlp = 7.083333333333333
# x1 = 0.0, x2 = 1.0
# y1 =  3.1666666666666665, y2 = 0.3333333333333333
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
        separation_solve_alg = Coluna.Algorithm.SolveIpForm()
    )
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, alg;
        print = true
    )
    Coluna.set_optim_start_time!(env)

    result = Coluna.Benders.run_benders_loop!(ctx, env)
    @test result.mlp ≈ 7.083333333333333
end
register!(unit_tests, "benders_default", benders_iter_default_B_integer; x = true)
function benders_simple_example()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())
    origform = Coluna.MathProg.create_formulation!(env, Coluna.MathProg.Original())

    # Variables
    vars = Dict{String, Coluna.MathProg.VarId}()
    variables_infos = [
        ("x1", 1.0, Coluna.MathProg.Integ),
        ("x2", 4.0, Coluna.MathProg.Integ),
        ("y1", 2.0, Coluna.MathProg.Continuous),
        ("y2", 3.0, Coluna.MathProg.Continuous)
    ]
    for (name, cost, kind) in variables_infos
        vars[name] = Coluna.MathProg.getid(Coluna.MathProg.setvar!(
            origform, name, Coluna.MathProg.OriginalVar; cost = cost, lb = 0.0, kind = kind
        ))
    end

    # Constraints
    constrs = Dict{String, Coluna.MathProg.ConstrId}()
    constraints_infos = [
        ("c1", 2.0, Coluna.MathProg.Greater, Dict(vars["x1"] => -1.0, vars["x2"] => 4.0, vars["y1"] => 2.0, vars["y2"] => 3.0)),
        ("c2", 3.0, Coluna.MathProg.Greater, Dict(vars["x1"] => 1.0, vars["x2"] => 3.0, vars["y1"] => 1.0, vars["y2"] => 1.0)),
    ]
    for (name, rhs, sense, members) in constraints_infos
        constrs[name] = Coluna.MathProg.getid(Coluna.MathProg.setconstr!(
            origform, name, Coluna.MathProg.OriginalConstr; rhs = rhs, sense = sense, members = members
        ))
    end

    @show origform

    # Decomposition tree
    m = JuMP.Model()
    BlockDecomposition.@axis(axis, [1])
    tree = BlockDecomposition.Tree(m, BlockDecomposition.Benders, axis)
    mast_ann = tree.root.master
    sp_ann = BlockDecomposition.Annotation(tree, BlockDecomposition.BendersSepSp, BlockDecomposition.Benders, [])
    BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[1], sp_ann)

    # Benders annotations
    ann = Coluna.Annotations()
    ann.tree = tree
    Coluna.store!(ann, mast_ann, Coluna.MathProg.getvar(origform, vars["x1"]))
    Coluna.store!(ann, mast_ann, Coluna.MathProg.getvar(origform, vars["x2"]))
    Coluna.store!(ann, sp_ann, Coluna.MathProg.getvar(origform, vars["y1"]))
    Coluna.store!(ann, sp_ann, Coluna.MathProg.getvar(origform, vars["y2"]))
    Coluna.store!(ann, sp_ann, Coluna.MathProg.getconstr(origform, constrs["c1"]))
    Coluna.store!(ann, sp_ann, Coluna.MathProg.getconstr(origform, constrs["c2"]))

    problem = Coluna.MathProg.Problem(env)
    Coluna.MathProg.set_original_formulation!(problem, origform)

    Coluna.reformulate!(problem, ann, env)
    reform = Coluna.MathProg.get_reformulation(problem)
    return env, reform
end

function benders_iteration_default()
    env, reform = benders_simple_example()

    master = Coluna.MathProg.getmaster(reform)
    master.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for (sp_id, sp) in Coluna.MathProg.get_benders_sep_sps(reform)
        sp.optimizers = Coluna.MathProg.AbstractOptimizer[] # dirty
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    println("\e[42m --------------- n --s------------- \e[00m")

    alg = Coluna.Algorithm.BendersCutGeneration()
    ctx = Coluna.Algorithm.BendersContext(reform, alg)

    println("\e[42m --------------- n --1------------- \e[00m")
    Coluna.Benders.run_benders_iteration!(ctx, nothing, env, nothing)
    println("\e[42m --------------- n --2------------- \e[00m")
    Coluna.Benders.run_benders_iteration!(ctx, nothing, env, nothing)
    println("\e[42m --------------- n --3------------- \e[00m")
    Coluna.Benders.run_benders_iteration!(ctx, nothing, env, nothing)
    println("\e[42m --------------- n --4------------- \e[00m")
    Coluna.Benders.run_benders_iteration!(ctx, nothing, env, nothing)
end
register!(unit_tests, "benders_default", benders_iteration_default)
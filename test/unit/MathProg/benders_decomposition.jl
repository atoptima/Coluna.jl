function benders_decomposition()
    """
    original
        min
        x1 + 4x2 + 2y1 + 3y2
        s.t.
        x1 + x2 >= 0
        - x1 + 3x2 - y1 + 2y2 >= 2
        x1 + 3x2 + y1 + y2 >= 3
        y1 + y2 >= 0

    continuous
        original
            y1, y2

    integer
        original
            x1, x2

    bounds
        x1 >= 0
        x2 >= 0
        y1 >= 0
        y2 >= 0
    """

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    origform = Coluna.MathProg.create_formulation!(
        env, Coluna.MathProg.Original()
    )

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
        ("c3", 0.0, Coluna.MathProg.Greater, Dict(vars["x1"] => 1.0, vars["x2"] => 1.0)),
        ("c4", 0.0, Coluna.MathProg.Greater, Dict(vars["y1"] => 1.0, vars["y2"] => 1.0))
    ]
    for (name, rhs, sense, members) in constraints_infos
        constrs[name] = Coluna.MathProg.getid(Coluna.MathProg.setconstr!(
            origform, name, Coluna.MathProg.OriginalConstr; rhs = rhs, sense = sense, members = members
        ))
    end

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
    Coluna.store!(ann, mast_ann, Coluna.MathProg.getconstr(origform, constrs["c3"]))
    Coluna.store!(ann, sp_ann, Coluna.MathProg.getconstr(origform, constrs["c4"]))

    problem = Coluna.MathProg.Problem(env)
    Coluna.MathProg.set_original_formulation!(problem, origform)

    Coluna.reformulate!(problem, ann, env)
    reform = Coluna.MathProg.get_reformulation(problem)

    # Test first stage variables & constraints
    # Coluna.MathProg.MinSense + 1.0 x1 + 4.0 x2 + 1.0 η[4]  
    # c3 : + 1.0 x1 + 1.0 x2  >= 0.0 (MasterPureConstrConstraintu3 | true)
    # 0.0 <= x1 <= Inf (Continuous | MasterPureVar | true)
    # 0.0 <= x2 <= Inf (Continuous | MasterPureVar | true)
    # 0.0 <= η[4] <= Inf (Continuous | MasterBendSecondStageCostVar | true)

    master = Coluna.MathProg.getmaster(reform)
    fs_vars = Dict(getname(master, varid) => var for (varid, var) in Coluna.MathProg.getvars(master))
    fs_constrs = Dict(getname(master, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(master))

    @test length(fs_vars) == 3

    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(fs_vars["x1"])) <= Coluna.MathProg.MasterPureVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(fs_vars["x2"])) <= Coluna.MathProg.MasterPureVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(fs_vars["η[4]"])) <= Coluna.MathProg.MasterBendSecondStageCostVar

    @test Coluna.MathProg.getcurlb(master, fs_vars["x1"]) == 0.0
    @test Coluna.MathProg.getcurlb(master, fs_vars["x2"]) == 0.0
    @test Coluna.MathProg.getcurlb(master, fs_vars["η[4]"]) == -Inf

    @test Coluna.MathProg.getcurub(master, fs_vars["x1"]) == Inf
    @test Coluna.MathProg.getcurub(master, fs_vars["x2"]) == Inf
    @test Coluna.MathProg.getcurub(master, fs_vars["η[4]"]) == Inf

    @test Coluna.MathProg.getcurcost(master, fs_vars["x1"]) == 1.0
    @test Coluna.MathProg.getcurcost(master, fs_vars["x2"]) == 4.0
    @test Coluna.MathProg.getcurcost(master, fs_vars["η[4]"]) == 1.0

    @test length(fs_constrs) == 1

    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(fs_constrs["c3"])) <= Coluna.MathProg.MasterPureConstr

    @test Coluna.MathProg.getcurrhs(master, fs_constrs["c3"]) == 0.0

    # Test second stage variables & Constraints
    # Coluna.MathProg.MinSense + 2.0 y1 + 3.0 y2 + 1.0 μ⁺[x1] + 1.0 μ⁻[x1] + 4.0 μ⁺[x2] + 4.0 μ⁻[x2]
    # c1 : - 1.0 x1 + 4.0 x2 + 2.0 y1 + 3.0 y2  >= 2.0 (BendSpTechnologicalConstrConstraintu1 | true)
    # c2 : + 1.0 x1 + 3.0 x2 + 1.0 y1 + 1.0 y2 >= 3.0 (BendSpTechnologicalConstrConstraintu2 | true)
    # c4 : + 1.0 y1 + 1.0 y2  >= 0.0 (BendSpPureConstrConstraintu4 | true)
    # 0.0 <= y1 <= Inf (Continuous | BendSpSepVar | true)
    # 0.0 <= y2 <= Inf (Continuous | BendSpSepVar | true)
    # 0.0 <= x1 <= Inf (Continuous | BendFirstStageRepVar | true)
    # 0.0 <= x2 <= Inf (Continuous | BendFirstStageRepVar | true)
    
    subprob = first(values(Coluna.MathProg.get_benders_sep_sps(reform)))

    ss_vars = Dict(getname(subprob, varid) => var for (varid, var) in Coluna.MathProg.getvars(subprob))
    ss_constrs = Dict(getname(subprob, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(subprob))

    @test length(ss_vars) == 7

    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["y1"])) <= Coluna.MathProg.BendSpSepVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["y2"])) <= Coluna.MathProg.BendSpSepVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["x1"])) <= Coluna.MathProg.BendSpFirstStageRepVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["x2"])) <= Coluna.MathProg.BendSpFirstStageRepVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["local_art_of_c1"])) <= Coluna.MathProg.BendSpSecondStageArtVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["local_art_of_c2"])) <= Coluna.MathProg.BendSpSecondStageArtVar
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_vars["local_art_of_c4"])) <= Coluna.MathProg.BendSpSecondStageArtVar

    @test Coluna.MathProg.getcurlb(subprob, ss_vars["y1"]) == 0.0
    @test Coluna.MathProg.getcurlb(subprob, ss_vars["y2"]) == 0.0
    @test Coluna.MathProg.getcurlb(subprob, ss_vars["x1"]) == 0.0
    @test Coluna.MathProg.getcurlb(subprob, ss_vars["x2"]) == 0.0

    @test Coluna.MathProg.getcurub(subprob, ss_vars["y1"]) == Inf
    @test Coluna.MathProg.getcurub(subprob, ss_vars["y2"]) == Inf
    @test Coluna.MathProg.getcurub(subprob, ss_vars["x1"]) == Inf
    @test Coluna.MathProg.getcurub(subprob, ss_vars["x2"]) == Inf

    @test Coluna.MathProg.getcurcost(subprob, ss_vars["y1"]) == 2.0
    @test Coluna.MathProg.getcurcost(subprob, ss_vars["y2"]) == 3.0
    @test Coluna.MathProg.getcurcost(subprob, ss_vars["x1"]) == 1.0
    @test Coluna.MathProg.getcurcost(subprob, ss_vars["x2"]) == 4.0

    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_constrs["c1"])) <= Coluna.MathProg.BendSpTechnologicalConstr
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_constrs["c2"])) <= Coluna.MathProg.BendSpTechnologicalConstr
    @test Coluna.MathProg.getduty(Coluna.MathProg.getid(ss_constrs["c4"])) <= Coluna.MathProg.BendSpPureConstr

    @test Coluna.MathProg.getcurrhs(subprob, ss_constrs["c1"]) == 2.0
    @test Coluna.MathProg.getcurrhs(subprob, ss_constrs["c2"]) == 3.0
    @test Coluna.MathProg.getcurrhs(subprob, ss_constrs["c4"]) == 0.0

    @test length(ss_constrs) == 3
    return
end
register!(unit_tests, "benders_decomposition", benders_decomposition)


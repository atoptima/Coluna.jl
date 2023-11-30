function dw_decomposition()
    """
        min x1 + x2 + y1 + y2 + s1 + s2
        st. x1 + x2 + y1 + y2 >= 1
            2x1 + 3x2         <= s1
            3y1 + 2y2         <= s2
            2 >= x1 >= 1
            3 >= x2 >= 2
            -Inf >= s1 >= -Inf
            2 >= y1 >= 1
            3 >= y2 >= 2
            -Inf >= -Inf
    """

    env = Coluna.Env{Coluna.MathProg.VarId}(
        Coluna.Params(
            global_art_var_cost=1000.0,
            local_art_var_cost=100.0
        )
    )

    origform = Coluna.MathProg.create_formulation!(
        env, Coluna.MathProg.Original()
    )

    # Variables
    vars = Dict{String,Coluna.MathProg.VarId}()
    variables_infos = [
        ("x1", 1.0, Integ, 1.0, 2.0),
        ("x2", 1.0, Integ, 2.0, 3.0),
        ("s1", 1.0, Continuous, -Inf, Inf),
        ("y1", 1.0, Integ, 1.0, 2.0),
        ("y2", 1.0, Integ, 2.0, 3.0),
        ("s2", 1.0, Continuous, -1.0, Inf)
    ]
    for (name, cost, kind, lb, ub) in variables_infos
        vars[name] = Coluna.MathProg.getid(
            Coluna.MathProg.setvar!(
                origform,
                name,
                Coluna.MathProg.OriginalVar;
                cost=cost, lb=lb, ub=ub, kind=kind
            )
        )
    end

    # Constraints
    constrs = Dict{String,Coluna.MathProg.ConstrId}()
    constraints_infos = [
        ("c1", 1.0, Coluna.MathProg.Greater, Dict(vars["x1"] => 1.0, vars["x2"] => 1.0, vars["y1"] => 1.0, vars["y2"] => 1.0, vars["s1"] => 1.0, vars["s2"] => 1.0)),
        ("c2", 0.0, Coluna.MathProg.Less, Dict(vars["x1"] => 2.0, vars["x2"] => 3.0, vars["s1"] => -1.0)),
        ("c3", 0.0, Coluna.MathProg.Less, Dict(vars["y1"] => 3.0, vars["y2"] => 2.0, vars["s2"] => -1.0))
    ]
    for (name, rhs, sense, members) in constraints_infos
        constrs[name] = Coluna.MathProg.getid(
            Coluna.MathProg.setconstr!(
                origform, name, Coluna.MathProg.OriginalConstr; rhs=rhs, sense=sense, members=members
            )
        )
    end

    # Decomposition tree
    m = JuMP.Model()
    BlockDecomposition.@axis(axis, [1, 2])
    tree = BlockDecomposition.Tree(m, BlockDecomposition.DantzigWolfe, axis)
    mast_ann = tree.root.master
    sp_ann1 = BlockDecomposition.Annotation(tree, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, [])
    BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[1], sp_ann1)
    sp_ann2 = BlockDecomposition.Annotation(tree, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, [])
    BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[2], sp_ann2)

    # Dantzig-Wolfe annotations
    ann = Coluna.Annotations()
    ann.tree = tree
    Coluna.store!(ann, mast_ann, Coluna.MathProg.getconstr(origform, constrs["c1"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getconstr(origform, constrs["c2"]))
    Coluna.store!(ann, sp_ann2, Coluna.MathProg.getconstr(origform, constrs["c3"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getvar(origform, vars["x1"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getvar(origform, vars["x2"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getvar(origform, vars["s1"]))
    Coluna.store!(ann, sp_ann2, Coluna.MathProg.getvar(origform, vars["y1"]))
    Coluna.store!(ann, sp_ann2, Coluna.MathProg.getvar(origform, vars["y2"]))
    Coluna.store!(ann, sp_ann2, Coluna.MathProg.getvar(origform, vars["s2"]))

    problem = Coluna.MathProg.Problem(env)
    Coluna.MathProg.set_original_formulation!(problem, origform)

    Coluna.reformulate!(problem, ann, env)
    reform = Coluna.MathProg.get_reformulation(problem)

    # Test master
    master = Coluna.MathProg.getmaster(reform)
    master_vars = Dict(getname(master, varid) => var for (varid, var) in Coluna.MathProg.getvars(master))
    master_constrs = Dict(getname(master, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(master))

    @test length(master_vars) == 15
    @test getcurub(master, master_vars["x1"]) == 2.0
    @test getcurub(master, master_vars["x2"]) == 3.0
    @test getcurub(master, master_vars["y1"]) == 2.0
    @test getcurub(master, master_vars["y2"]) == 3.0
    @test getcurub(master, master_vars["s1"]) == Inf
    @test getcurub(master, master_vars["s2"]) == Inf

    @test getcurlb(master, master_vars["x1"]) == 1.0
    @test getcurlb(master, master_vars["x2"]) == 2.0
    @test getcurlb(master, master_vars["y1"]) == 1.0
    @test getcurlb(master, master_vars["y2"]) == 2.0
    @test getcurlb(master, master_vars["s1"]) == -Inf
    @test getcurlb(master, master_vars["s2"]) == -1.0


    sp1 = first(values(Coluna.MathProg.get_dw_pricing_sps(reform)))

    sp1_vars = Dict(getname(sp1, varid) => var for (varid, var) in Coluna.MathProg.getvars(sp1))
    sp1_constrs = Dict(getname(sp1, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(sp1))
    @test Coluna.MathProg.getcurlb(sp1, sp1_vars["x1"]) == 1.0
    @test Coluna.MathProg.getcurub(sp1, sp1_vars["x1"]) == 2.0
    @test Coluna.MathProg.getcurlb(sp1, sp1_vars["x2"]) == 2.0
    @test Coluna.MathProg.getcurub(sp1, sp1_vars["x2"]) == 3.0
end
register!(unit_tests, "dw_decomposition", dw_decomposition)

function dw_decomposition_with_identical_subproblems()
    """
        min x1 + x2 + y1 + y2 + x3 + y3
        st. x1 + x2 + y1 + y2 >= 1
            2x1 + 3x2         <= x3
            2y1 + 3y2         <= y3 // same subproblem
            1 <= x1 <= 2
            2 <= x2 <= 3

    """

    env = Coluna.Env{Coluna.MathProg.VarId}(
        Coluna.Params(
            global_art_var_cost=1000.0,
            local_art_var_cost=100.0
        )
    )

    origform = Coluna.MathProg.create_formulation!(
        env, Coluna.MathProg.Original()
    )

    # Variables
    vars = Dict{String,Coluna.MathProg.VarId}()
    variables_infos = [
        ("x1", 1.0, Integ, 1.0, 2.0),
        ("x2", 1.0, Integ, 2.0, 3.0),
        ("x3", 1.0, Continuous, -Inf, Inf),
    ]
    for (name, cost, kind, lb, ub) in variables_infos
        vars[name] = Coluna.MathProg.getid(
            Coluna.MathProg.setvar!(
                origform, name, Coluna.MathProg.OriginalVar; cost=cost, lb=lb, ub=ub, kind=kind
            )
        )
    end

    # Constraints
    constrs = Dict{String,Coluna.MathProg.ConstrId}()
    constraints_infos = [
        ("c1", 1.0, Coluna.MathProg.Greater, Dict(vars["x1"] => 1.0, vars["x2"] => 1.0)),
        ("c2", 5.0, Coluna.MathProg.Less, Dict(vars["x1"] => 2.0, vars["x2"] => 3.0, vars["x3"] => -1.0)),
    ]
    for (name, rhs, sense, members) in constraints_infos
        constrs[name] = Coluna.MathProg.getid(
            Coluna.MathProg.setconstr!(
                origform, name, Coluna.MathProg.OriginalConstr; rhs=rhs, sense=sense, members=members
            )
        )
    end

    # Decomposition tree
    m = JuMP.Model()
    BlockDecomposition.@axis(axis, [1, 2])
    tree = BlockDecomposition.Tree(m, BlockDecomposition.DantzigWolfe, axis)
    mast_ann = tree.root.master
    sp_ann1 = BlockDecomposition.Annotation(tree, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, [])
    BlockDecomposition.setlowermultiplicity!(sp_ann1, 0)
    BlockDecomposition.setuppermultiplicity!(sp_ann1, 2)
    BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[1], sp_ann1)

    # Dantzig-Wolfe annotations
    ann = Coluna.Annotations()
    ann.tree = tree
    Coluna.store!(ann, mast_ann, Coluna.MathProg.getconstr(origform, constrs["c1"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getconstr(origform, constrs["c2"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getvar(origform, vars["x1"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getvar(origform, vars["x2"]))
    Coluna.store!(ann, sp_ann1, Coluna.MathProg.getvar(origform, vars["x3"]))

    problem = Coluna.MathProg.Problem(env)
    Coluna.MathProg.set_original_formulation!(problem, origform)

    Coluna.reformulate!(problem, ann, env)
    reform = Coluna.MathProg.get_reformulation(problem)

    # Test master
    master = Coluna.MathProg.getmaster(reform)
    master_vars = Dict(getname(master, varid) => var for (varid, var) in Coluna.MathProg.getvars(master))
    master_constrs = Dict(getname(master, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(master))

    @test length(master_vars) == 9
    @test Coluna.MathProg.getcurub(master, master_vars["x1"]) == 2.0 * 2
    @test Coluna.MathProg.getcurub(master, master_vars["x2"]) == 3.0 * 2
    @test Coluna.MathProg.getcurub(master, master_vars["x3"]) == Inf
    @test Coluna.MathProg.getcurlb(master, master_vars["x1"]) == 1.0 * 0
    @test Coluna.MathProg.getcurlb(master, master_vars["x2"]) == 2.0 * 0
    @test Coluna.MathProg.getcurlb(master, master_vars["x3"]) == -Inf
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c1"]) == 1.0
    @test Coluna.MathProg.getcurrhs(master, master_constrs["sp_ub_4"]) == 2.0
    @test Coluna.MathProg.getcurrhs(master, master_constrs["sp_lb_4"]) == 0.0


    sp1 = first(values(Coluna.MathProg.get_dw_pricing_sps(reform)))

    sp1_vars = Dict(getname(sp1, varid) => var for (varid, var) in Coluna.MathProg.getvars(sp1))
    sp1_constrs = Dict(getname(sp1, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(sp1))

    @test length(sp1_vars) == 4
    @test Coluna.MathProg.getcurlb(sp1, sp1_vars["x1"]) == 1.0
    @test Coluna.MathProg.getcurub(sp1, sp1_vars["x1"]) == 2.0
    @test Coluna.MathProg.getcurlb(sp1, sp1_vars["x2"]) == 2.0
    @test Coluna.MathProg.getcurub(sp1, sp1_vars["x2"]) == 3.0
end
register!(unit_tests, "dw_decomposition", dw_decomposition_with_identical_subproblems)

function dw_decomposition_repr()
    """
        min e1
        s.t. e1 >= 4
             
        sp1 : 1 <= e1 <= 2 with lm = 0, lm= 2
        sp2 : 1 <= e1 <= 2 with lm = 1, lm= 3
    """

    env = Coluna.Env{Coluna.MathProg.VarId}(
        Coluna.Params(
            global_art_var_cost=1000.0,
            local_art_var_cost=100.0
        )
    )

    origform = Coluna.MathProg.create_formulation!(
        env, Coluna.MathProg.Original()
    )

    # Variables
    vars = Dict{String,Coluna.MathProg.VarId}()
    e1 = Coluna.MathProg.getid(
        Coluna.MathProg.setvar!(
            origform, "e1", Coluna.MathProg.OriginalVar;
            cost=1.0, lb=1.0, ub=2.0, kind=Integ
        )
    )

    # Constraints
    constrs = Dict{String,Coluna.MathProg.ConstrId}()
    c1 = Coluna.MathProg.getid(
        Coluna.MathProg.setconstr!(
            origform, "c1", Coluna.MathProg.OriginalConstr; rhs=4.0, sense=Coluna.MathProg.Greater, members=Dict(e1 => 1.0)
        )
    )

    # Decomposition tree
    m = JuMP.Model()
    BlockDecomposition.@axis(axis, [1, 2])
    tree = BlockDecomposition.Tree(m, BlockDecomposition.DantzigWolfe, axis)
    mast_ann = tree.root.master
    sp_ann1 = BlockDecomposition.Annotation(tree, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, [])
    BlockDecomposition.setlowermultiplicity!(sp_ann1, 0)
    BlockDecomposition.setuppermultiplicity!(sp_ann1, 2)
    BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[1], sp_ann1)
    sp_ann2 = BlockDecomposition.Annotation(tree, BlockDecomposition.DwPricingSp, BlockDecomposition.DantzigWolfe, [])
    BlockDecomposition.setlowermultiplicity!(sp_ann2, 1)
    BlockDecomposition.setuppermultiplicity!(sp_ann2, 3)
    BlockDecomposition.create_leaf!(BlockDecomposition.getroot(tree), axis[2], sp_ann2)

    # Dantzig-Wolfe annotations
    ann = Coluna.Annotations()
    ann.tree = tree
    Coluna.store!(ann, mast_ann, Coluna.MathProg.getconstr(origform, c1))
    Coluna.store_repr!(ann, [sp_ann1, sp_ann2], Coluna.MathProg.getvar(origform, e1))

    problem = Coluna.MathProg.Problem(env)
    Coluna.MathProg.set_original_formulation!(problem, origform)

    Coluna.reformulate!(problem, ann, env)
    reform = Coluna.MathProg.get_reformulation(problem)

    _io = IOBuffer()
    print(IOContext(_io, :user_only => true), reform)
    @test String(take!(_io)) ==
          """
          --- Reformulation ---
          Formulation DwMaster id = 3
          MinSense  
          c1 : + 1.0 e1  >= 4.0 (MasterMixedConstr | true)
          1.0 <= e1 <= 10.0 (Integ | MasterRepPricingVar | false)
          Formulation DwSp id = 5
          Multiplicities: lower = 0, upper = 2
          MinSense + 1.0 e1  
          1.0 <= e1 <= 2.0 (Integ | DwSpPricingVar | true)
          Formulation DwSp id = 4
          Multiplicities: lower = 1, upper = 3
          MinSense + 1.0 e1  
          1.0 <= e1 <= 2.0 (Integ | DwSpPricingVar | true)
          ---------------------
          """

    # Test master
    master = Coluna.MathProg.getmaster(reform)
    master_vars = Dict(getname(master, varid) => var for (varid, var) in Coluna.MathProg.getvars(master))
    master_constrs = Dict(getname(master, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(master))

    @test Coluna.MathProg.getcurlb(master, master_vars["e1"]) == 1.0 * (0 + 1)
    @test Coluna.MathProg.getcurub(master, master_vars["e1"]) == 2.0 * (2 + 3)
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c1"]) == 4.0

    # Test subproblem 1
    sp1 = first(values(Coluna.MathProg.get_dw_pricing_sps(reform)))
    sp1_vars = Dict(getname(sp1, varid) => var for (varid, var) in Coluna.MathProg.getvars(sp1))
    sp1_constrs = Dict(getname(sp1, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(sp1))

    @test length(sp1_vars) == 2
    @test Coluna.MathProg.getcurlb(sp1, sp1_vars["e1"]) == 1.0
    @test Coluna.MathProg.getcurub(sp1, sp1_vars["e1"]) == 2.0

    # Test subproblem 2
    sp2 = collect(values(Coluna.MathProg.get_dw_pricing_sps(reform)))[2]
    sp2_vars = Dict(getname(sp2, varid) => var for (varid, var) in Coluna.MathProg.getvars(sp2))
    sp2_constrs = Dict(getname(sp2, constrid) => constr for (constrid, constr) in Coluna.MathProg.getconstrs(sp2))

    @test length(sp2_vars) == 2
    @test Coluna.MathProg.getcurlb(sp1, sp2_vars["e1"]) == 1.0
    @test Coluna.MathProg.getcurub(sp1, sp2_vars["e1"]) == 2.0
end
register!(unit_tests, "dw_decomposition", dw_decomposition_repr)
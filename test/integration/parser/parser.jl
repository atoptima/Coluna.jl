struct AuxiliaryConstrInfo
    coeffs::Vector{Tuple{String,Float64}}
    duty::ClMP.Duty
    sense::CL.ConstrSense
    rhs::Float64
end

function get_vars_info(form::CL.Formulation)
    names = String[]
    kinds = ClMP.VarKind[]
    duties = ClMP.Duty{ClMP.Variable}[]
    costs = Float64[]
    bounds = Tuple{Float64,Float64}[]
    for (varid, var) in CL.getvars(form)
        push!(names, CL.getname(form, var))
        push!(kinds, CL.getperenkind(form, var))
        push!(duties, CL.getduty(varid))
        push!(costs, CL.getperencost(form, var))
        push!(bounds, (CL.getperenlb(form, var), CL.getperenub(form, var)))
    end
    return names, kinds, duties, costs, bounds
end

function get_constrs_info(form::CL.Formulation)
    infos = AuxiliaryConstrInfo[]
    coeff_matrix = CL.getcoefmatrix(form)
    for (constrid, constr) in CL.getconstrs(form)
        coeffs = Tuple{String,Float64}[]
        for (varid, coeff) in @view coeff_matrix[constrid, :]
            push!(coeffs, (CL.getname(form, varid), coeff))
        end
        duty = CL.getduty(constrid)
        sense = CL.getperensense(form, constr)
        rhs = CL.getperenrhs(form, constr)
        push!(infos, AuxiliaryConstrInfo(coeffs, duty, sense, rhs))
    end
    return infos
end

function no_objective_function1()
    s = """
    SP
        Min
            - 2y1 + y2
        S.t.
            - 6.3y1 + 3y2 == 5.9
    Continuous
        pricing
            y1, y2
    bounds
        y1 >= 1
        1 <= y2
    """
    @test_throws UndefObjectiveParserError reformfromstring(s)
end
register!(integration_tests, "parser", no_objective_function1)

function no_objective_function2()
    s = """
        Master
            max
            such that
                x + y1 <= 50.3
        SP
            max
                - 2y1 + y2
            such that
                - 6.3y1 + 3y2 == 5.9
        Continuous
            pure
                x
            representative
                y1
            pricing
                y2
        bounds
            y1 >= 1
            1 <= y2
    """
    @test_throws UndefObjectiveParserError reformfromstring(s)
end
register!(integration_tests, "parser", no_objective_function2)

function no_sp_vars_in_master()
    # no sp variable present in master
    s = """
       master
           maximize
               x + 5*y
           st
               2x - y <= 25
       Bin
           pure
               x
       Int
           pure
               y
       bounds
           y <= 10
   """
    env, master, subproblems, constraints, _ = reformfromstring(s)

    @test CL.getobjsense(master) == CL.MaxSense

    names, kinds, duties, costs, bounds = get_vars_info(master)
    @test names == ["y", "x"]
    @test kinds == [ClMP.Integ, ClMP.Binary]
    @test duties == [ClMP.MasterPureVar, ClMP.MasterPureVar]
    @test costs == [5.0, 1.0]
    @test bounds == [(-Inf, 10.0), (0.0, 1.0)]

    @test isempty(subproblems)
end
register!(integration_tests, "parser", no_sp_vars_in_master)

function rep_var_in_master_but_no_sp()
    # representative variable present in master but no subproblem
    s = """
     master
         maximise
             x + 5*y - w
         such that
             2x - y + w <= 25
     Bin
         pure
             x
     Int
         pure
             y
         representative
             w
     bounds
         y <= 10
     """
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", rep_var_in_master_but_no_sp)

function rep_var_not_in_obj()
    # representative variable not present in OF
    s = """
    master
        maximum
            3*x
        such that
            x - y1 <= 25
    dw_sp
        maximum
            6y2 - 2.0*y1
        such that
            y1 - y2 >= 25
    cont
        pure
            x
        pricing
            y2
        representative
            y1
    bounds
        x >= 10
    """
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", rep_var_not_in_obj)

function master_var_not_in_obj()
    # master variable not present in OF
    s = """
    master
        min
            3*x
        such that
            x + y >= 25
    integers
        pures
            x, y
    bounds
        x, y >= 5
"""
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", master_var_not_in_obj)

function var_in_obj_with_no_duty_and_kind()
    # variable in OF with no duty and kind defined
    s = """
        master
            min
                3*x + 7w
            st
                x + w == 25
        int
            pure
                x
        bounds
            2 <= x, w <= 10
    """
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", var_in_obj_with_no_duty_and_kind)

function var_in_constr_with_no_duty_and_kind()
    # variable in constraint with no duty and kind defined
    s = """
        master
            minimise
                3*x + 7w
            such that
                x + w - z == 25
        int
            pure
                x, w
        bounds
            2 <= x, w <= 10
    """
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", var_in_constr_with_no_duty_and_kind)

function subprob_var_with_no_duty_and_kind()

    # subproblem variable with no duty and kind defined
    s = """
        master
            min
                3*x - w
            such that
                x + w == 25
        dw_sp
            min
                y
            such that
                y >= 25
        integer
            pure
                x, w
        bound
            2 <= x, w <= 10
    """
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", subprob_var_with_no_duty_and_kind)

function missing_duty_and_kind_section()

    # no duty/kind section defined
    s = """
        master
            minimum
                3*x - y
            such that
                x + y == 25
        bounds
            2 <= x, y <= 10
    """
    @test_throws UndefVarParserError reformfromstring(s)
end
register!(integration_tests, "parser", missing_duty_and_kind_section)

function minimize_no_bounds()
    s = """
        Master
            Minimize
            2*x + 4.5*y1
            Subject To
            x + y1 <= 10.5

        SP
            Min
            y1 + y2
            St
            - 6.3y1 + 3y2 == 5.9

        Continuous
            pure
                x
            representative
                y1
            pricing
                y2
    """
    env, master, subproblems, constraints, _ = reformfromstring(s)

    @test CL.getobjsense(master) == CL.MinSense

    names, kinds, duties, costs, bounds = get_vars_info(master)
    @test names == ["x", "y1"]
    @test kinds == [ClMP.Continuous, ClMP.Continuous]
    @test duties == [ClMP.MasterPureVar, ClMP.MasterRepPricingVar]
    @test costs == [2.0, 4.5]
    @test bounds == [(-Inf, Inf), (-Inf, Inf)]

    constrs = get_constrs_info(master)
    c1 = constrs[1] # x + y1 <= 10.5
    @test c1.coeffs == [("y1", 1.0), ("x", 1.0)]
    @test c1.duty == ClMP.MasterMixedConstr
    @test c1.sense == CL.Less
    @test c1.rhs == 10.5

    sp1 = subproblems[1]
    @test CL.getobjsense(sp1) == CL.MinSense

    names, kinds, duties, costs, bounds = get_vars_info(sp1)
    @test names == ["y2", "y1"]
    @test kinds == [ClMP.Continuous, ClMP.Continuous]
    @test duties == [ClMP.DwSpPricingVar, ClMP.DwSpPricingVar]
    @test costs == [1.0, 1.0]
    @test bounds == [(-Inf, Inf), (-Inf, Inf)]

    constrs = get_constrs_info(sp1)
    c1 = constrs[1] # - 6.3y1 + 3y2 == 5.9
    @test c1.coeffs == [("y1", -6.3), ("y2", 3.0)]
    @test c1.duty == ClMP.DwSpPureConstr
    @test c1.sense == CL.Equal
    @test c1.rhs == 5.9
end
register!(integration_tests, "parser", minimize_no_bounds)

function minimize_test1()
    s = """
        master
            min
            2*x - 5w + y1 + y2
            s.t.
            x - 3y1 + 8*y2 >= 20
            x + w <= 9

        dw_sp
            min
            4.5*y1 - 3*z_1 + z_2
            s.t.
            6.3y1 + z_1 == 5
            z_1 - 5*z_2 >= 4.2

        dw_sp
            min
            9*y2 + 2.2*z_3
            s.t.
            2*z_3 - 3y2 >= 3.8

        integers
            pures
                x, w
        binaries
            representatives
                y1, y2
        continuous
            pricing
                z_1, z_2, z_3

        bounds
            20 >= x >= 0
            0 <= y1 <= 1
            z_1, z_2 >= 6.2
    """
    env, master, subproblems, constraints, _ = reformfromstring(s)

    @test CL.getobjsense(master) == CL.MinSense

    names, kinds, duties, costs, bounds = get_vars_info(master)
    @test names == ["w", "x", "y2", "y1"]
    @test kinds == [ClMP.Integ, ClMP.Integ, ClMP.Binary, ClMP.Binary]
    @test duties == [ClMP.MasterPureVar, ClMP.MasterPureVar, ClMP.MasterRepPricingVar, ClMP.MasterRepPricingVar]
    @test costs == [-5.0, 2.0, 1.0, 1.0]
    @test bounds == [(-Inf, Inf), (0.0, 20.0), (0.0, 1.0), (0.0, 1.0)]

    constrs = get_constrs_info(master)
    c1 = constrs[1] # x + w <= 9
    @test c1.coeffs == [("w", 1.0), ("x", 1.0)]
    @test c1.duty == ClMP.MasterPureConstr
    @test c1.sense == CL.Less
    @test c1.rhs == 9.0

    c2 = constrs[2] # x - 3y1 + 8*y2 >= 20
    @test c2.coeffs == [("y2", 8.0), ("y1", -3.0), ("x", 1.0)]
    @test c2.duty == ClMP.MasterMixedConstr
    @test c2.sense == CL.Greater
    @test c2.rhs == 20.0

    sp1 = subproblems[1]
    @test CL.getobjsense(sp1) == CL.MinSense

    names, kinds, duties, costs, bounds = get_vars_info(sp1)
    @test names == ["y2", "z_3"]
    @test kinds == [ClMP.Binary, ClMP.Continuous]
    @test duties == [ClMP.DwSpPricingVar, ClMP.DwSpPricingVar]
    @test costs == [9.0, 2.2]
    @test bounds == [(0.0, 1.0), (-Inf, Inf)]

    constrs = get_constrs_info(sp1)
    c1 = constrs[1] # 2*z_3 - 3*y2 >= 3.8
    @test c1.coeffs == [("z_3", 2.0), ("y2", -3.0)]
    @test c1.duty == ClMP.DwSpPureConstr
    @test c1.sense == CL.Greater
    @test c1.rhs == 3.8

    sp2 = subproblems[2]
    @test CL.getobjsense(sp2) == CL.MinSense

    names, kinds, duties, costs, bounds = get_vars_info(sp2)
    @test names == ["z_1", "z_2", "y1"]
    @test kinds == [ClMP.Continuous, ClMP.Continuous, ClMP.Binary]
    @test duties == [ClMP.DwSpPricingVar, ClMP.DwSpPricingVar, ClMP.DwSpPricingVar]
    @test costs == [-3.0, 1.0, 4.5]
    @test bounds == [(6.2, Inf), (6.2, Inf), (0.0, 1.0)]

    constrs = get_constrs_info(sp2)
    c1 = constrs[1] # 6.3y1 + z_1 == 5
    @test c1.coeffs == [("y1", 6.3), ("z_1", 1.0)]
    @test c1.duty == ClMP.DwSpPureConstr
    @test c1.sense == CL.Equal
    @test c1.rhs == 5.0

    c2 = constrs[2] # z_1 - 5*z_2 >= 4.2
    @test c2.coeffs == [("z_2", -5.0), ("z_1", 1.0)]
    @test c2.duty == ClMP.DwSpPureConstr
    @test c2.sense == CL.Greater
    @test c2.rhs == 4.2
end
register!(integration_tests, "parser", minimize_test1)

function minimize_test2()
    s = """
    master
        min
        3*y + 2*z
        s.t.
        y + z >= 1

    continuous
        pure
            y
        artificial
            z
"""
    env, master, subproblems, constraints, _ = reformfromstring(s)

    names, kinds, duties, costs, bounds = get_vars_info(master)
    @test names == ["y", "z"]
    @test kinds == [ClMP.Continuous, ClMP.Continuous]
    @test duties == [ClMP.MasterPureVar, ClMP.MasterArtVar]
    @test costs == [3.0, 2.0]
    @test bounds == [(-Inf, Inf), (-Inf, Inf)]
end
register!(integration_tests, "parser", minimize_test2)

function minimize_test3()
    # Original formulation is the following:
    # min
    # x1 + 4x2 + 2y1 + 3y2
    # s.t.
    # x1 + x2 >= 0
    # - x1 + 3x2 - y1 + 2y2 >= 2
    # x1 + 3x2 + y1 + y2 >= 3
    # y1 + y2 >= 0

    s = """
        master
            min
            x1 + 4x2 + z
            s.t.
            x1 + x2 >= 0

        benders_sp
            min
            0x1 + 0x2 + 2y1 + 3y2 + z
            s.t.
            -x1 + 3x2 + 2y1 + 3y2 >= 2 {BendTechConstr}
            x1 + 3x2 + y1 + y2 >= 3 {BendTechConstr}
            y1 + y2 >= 0

        integers
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
            a11 >= 0
            a12 >= 0
            a21 >= 0
            a22 >= 0
    """
    env, master, subproblems, constraints, _ = reformfromstring(s)

    @test CL.getobjsense(master) == CL.MinSense

    # TODO: this test is order dependant and the order may change each time we change the test
    # or the code. Make the test independent of the order.

    names, kinds, duties, costs, bounds = get_vars_info(master)
    @test names == ["z", "x2", "x1"]
    @test kinds == [ClMP.Continuous, ClMP.Integ, ClMP.Integ]
    @test duties == [ClMP.MasterBendSecondStageCostVar, ClMP.MasterPureVar, ClMP.MasterPureVar]
    @test costs == [1.0, 4.0, 1.0]
    @test bounds == [(-Inf, Inf), (0.0, Inf), (0, Inf)]

    constrs = get_constrs_info(master)
    c1 = constrs[1] # x1 + x2 >= 0
    @test c1.coeffs == [("x1", 1.0), ("x2", 1.0)]
    @test c1.duty == ClMP.MasterPureConstr
    @test c1.sense == CL.Greater
    @test c1.rhs == 0.0

    sp1 = subproblems[1]
    @test CL.getobjsense(sp1) == CL.MinSense

    names, kinds, duties, costs, bounds = get_vars_info(sp1)
    @test names == ["z", "y2", "y1", "x2", "x1"] 
    @test kinds == [ClMP.Continuous, ClMP.Continuous, ClMP.Continuous, ClMP.Integ, ClMP.Integ]
    @test duties == [ClMP.BendSpCostRepVar, ClMP.BendSpSepVar, ClMP.BendSpSepVar, ClMP.BendSpFirstStageRepVar, ClMP.BendSpFirstStageRepVar]
    @test costs == [1.0, 3.0, 2.0, 0.0, 0.0]
    @test bounds == [(-Inf, Inf), (0.0, Inf), (0.0, Inf), (0.0, Inf), (0.0, Inf)]
    @test !isnothing(sp1.duty_data.second_stage_cost_var)

    constrs = get_constrs_info(sp1)
    c1 = constrs[1] # x1 + 3x2 + y1 + y2 >= 3
    @test c1.coeffs == [("x1", 1.0), ("y1", 1.0), ("x2", 3.0), ("y2", 1.0)]
    @test c1.duty == ClMP.BendSpTechnologicalConstr
    @test c1.sense == CL.Greater
    @test c1.rhs == 3.0

    c2 = constrs[2] # y1 + y2 >= 0
    @test c2.coeffs == [("y1", 1.0), ("y2", 1.0)]
    @test c2.duty == ClMP.BendSpPureConstr
    @test c2.sense == CL.Greater
    @test c2.rhs == 0.0

    c3 = constrs[3] # -x1 + 3x2 + 2y1 + 3y2 >= 2
    @test c3.coeffs == [("x1", -1.0), ("y1", 2.0), ("x2", 3.0), ("y2", 3.0)]
    @test c3.duty == ClMP.BendSpTechnologicalConstr
    @test c3.sense == CL.Greater
    @test c3.rhs == 2.0
end
register!(integration_tests, "parser", minimize_test3)
struct AuxiliaryConstrInfo
    coeffs::Vector{Tuple{String,Float64}}
    duty::ClMP.Duty
    sense::CL.ConstrSense
    rhs::Float64
end

function get_vars_info(form::CL.Formulation)
    names = []
    kinds = []
    duties = []
    costs = []
    bounds = []
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
        coeffs = []
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

@testset "Integration - parser" begin

    @testset "no objective function" begin
        # master not defined
        s = """
            SP
                - 6.3y1 + 3y2 == 5.9
            Continuous
                pricing
                    y1, y2
            bounds
                y1 >= 1
                1 <= y2
        """
        @test_throws ErrorException CL.reformfromstring(s)

        # OF not defined
        s = """
            Master
                max
                such that
                    x + y1 + y2 <= 50.3
            SP
                - 6.3y1 + 3y2 == 5.9
            Continuous
                pure
                    x
                pricing
                    y1, y2
            bounds
                y1 >= 1
                1 <= y2
        """
        @test_throws ErrorException CL.reformfromstring(s)
    end

    @testset "no subproblems" begin
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
        env, master, subproblems, constraints = CL.reformfromstring(s)

        @test CL.getobjsense(master) == CL.MaxSense

        names, kinds, duties, costs, bounds = get_vars_info(master)
        @test names == ["y", "x"]
        @test kinds == [ClMP.Integ, ClMP.Binary]
        @test duties == [ClMP.MasterPureVar, ClMP.MasterPureVar]
        @test costs == [5.0, 1.0]
        @test bounds == [(-Inf, 10.0), (0.0, 1.0)]

        @test isempty(subproblems)

        # sp variable present in master but no subproblem
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
                pricing
                    w
            bounds
                y <= 10
        """
        @test_throws ErrorException CL.reformfromstring(s)
    end

    @testset "variables not defined" begin
        # subproblem variables not present in OF
        s = """
            master
                maximum
                    3*x
                such that
                    x - y1 <= 25
            dw_sp
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
        @test_throws ErrorException CL.reformfromstring(s)

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
        @test_throws ErrorException CL.reformfromstring(s)

        # variable in OF with no duty and kind defined
        s = """
            master
                min
                    3*x + 7w - y
                st
                    x + w == 25
            dw_sp
                y >= 25
            int
                pure
                    x
                pricing
                    y
            bounds
                2 <= x, w <= 10
        """
        @test_throws ErrorException CL.reformfromstring(s)

        # variable in constraint with no duty and kind defined
        s = """
            master
                minimise
                    3*x + 7w - y
                such that
                    x + w - z == 25
            dw_sp
                y >= 25
            int
                pure
                    x, w
                pricing
                    y
            bounds
                2 <= x, w <= 10
        """
        @test_throws ErrorException CL.reformfromstring(s)

        # subproblem variable with no duty and kind defined
        s = """
            master
                min
                    3*x - y
                such that
                    x + y == 25
            dw_sp
                y >= 25
            integer
                pure
                    x
            bound
                2 <= x <= 10
        """
        @test_throws ErrorException CL.reformfromstring(s)

        # no duty/kind section defined
        s = """
            master
                minimum
                    3*x - y
                such that
                    x + y == 25
            dw_sp
                y >= 25
            bounds
                2 <= x <= 10
        """
        @test_throws ErrorException CL.reformfromstring(s)
    end

    @testset "minimize no bounds and representatives" begin
        s = """
            Master
                Minimize
                2*x + 4.5y1 + y2
                Subject To
                x + y1 <= 10.5
                x + y2 >= 3

            SP
                - 6.3y1 + 3y2 == 5.9

            Continuous
                pure
                    x
                pricing
                    y1, y2
        """
        env, master, subproblems, constraints = CL.reformfromstring(s)

        @test CL.getobjsense(master) == CL.MinSense

        names, kinds, duties, costs, bounds = get_vars_info(master)
        @test names == ["y2", "x", "y1"]
        @test kinds == [ClMP.Continuous, ClMP.Continuous, ClMP.Continuous]
        @test duties == [ClMP.MasterRepPricingVar, ClMP.MasterPureVar, ClMP.MasterRepPricingVar]
        @test costs == [1.0, 2.0, 4.5]
        @test bounds == [(-Inf, Inf), (-Inf, Inf), (-Inf, Inf)]

        constrs = get_constrs_info(master)
        c1 = constrs[1] # x + y2 >= 3
        @test c1.coeffs == [("y2", 1.0), ("x", 1.0)]
        @test c1.duty == ClMP.MasterMixedConstr
        @test c1.sense == CL.Greater
        @test c1.rhs == 3.0

        c1 = constrs[2] # - 6.3y1 + 3y2 == 5.9
        @test c1.coeffs == [("y1", -6.3), ("y2", 3.0)]
        @test c1.duty == ClMP.MasterMixedConstr
        @test c1.sense == CL.Equal
        @test c1.rhs == 5.9

        c1 = constrs[3] # x + y1 <= 10.5
        @test c1.coeffs == [("y1", 1.0), ("x", 1.0)]
        @test c1.duty == ClMP.MasterMixedConstr
        @test c1.sense == CL.Less
        @test c1.rhs == 10.5

        sp1 = subproblems[1]
        names, kinds, duties, costs, bounds = get_vars_info(sp1)
        @test names == ["y2", "y1"]
        @test kinds == [ClMP.Continuous, ClMP.Continuous]
        @test duties == [ClMP.DwSpPricingVar, ClMP.DwSpPricingVar]
        @test costs == [1.0, 4.5]
        @test bounds == [(-Inf, Inf), (-Inf, Inf)]
    end

    @testset "minimize multiple kinds, duties, subproblems and bounds" begin
        s = """
            master
                min
                2*x - 5w + 4.5y1 + 9*y2 - 3z_1 + z_2 + 2.2*z_3
                s.t.
                x - 3y1 + 8*y2 + z_1 >= 20
                x + w <= 9

            dw_sp
                6.3y1 + z_1 == 5
                z_2 - 5*y2 >= 4.2

            dw_sp
                2*z_3 + y1 - 3*y2 >= 3.8

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
        env, master, subproblems, constraints = CL.reformfromstring(s)

        @test CL.getobjsense(master) == CL.MinSense

        names, kinds, duties, costs, bounds = get_vars_info(master)
        @test names == ["z_1", "y1", "y2", "z_2", "x", "w", "z_3"]
        @test kinds == [ClMP.Continuous, ClMP.Binary, ClMP.Binary, ClMP.Continuous, ClMP.Integ, ClMP.Integ, ClMP.Continuous]
        @test duties == [ClMP.MasterRepPricingVar, ClMP.MasterRepPricingVar, ClMP.MasterRepPricingVar, ClMP.MasterRepPricingVar, ClMP.MasterPureVar, ClMP.MasterPureVar, ClMP.MasterRepPricingVar]
        @test costs == [-3.0, 4.5, 9.0, 1.0, 2.0, -5.0, 2.2]
        @test bounds == [(6.2, Inf), (0.0, 1.0), (0.0, 1.0), (6.2, Inf), (0.0, 20.0), (-Inf, Inf), (-Inf, Inf)]

        constrs = get_constrs_info(master)
        c1 = constrs[1] # z_2 - 5*y2 >= 4.2
        @test c1.coeffs == [("y2", -5.0), ("z_2", 1.0)]
        @test c1.duty == ClMP.MasterMixedConstr
        @test c1.sense == CL.Greater
        @test c1.rhs == 4.2

        c2 = constrs[2] # 6.3y1 + z_1 == 5
        @test c2.coeffs == [("y1", 6.3), ("z_1", 1.0)]
        @test c2.duty == ClMP.MasterMixedConstr
        @test c2.sense == CL.Equal
        @test c2.rhs == 5.0

        c3 = constrs[3] # x + w <= 9
        @test c3.coeffs == [("w", 1.0), ("x", 1.0)]
        @test c3.duty == ClMP.MasterPureConstr
        @test c3.sense == CL.Less
        @test c3.rhs == 9.0

        c4 = constrs[4] # 2*z_3 + y1 - 3*y2 >= 3.8
        @test c4.coeffs == [("z_3", 2.0), ("y1", 1.0), ("y2", -3.0)]
        @test c4.duty == ClMP.MasterMixedConstr
        @test c4.sense == CL.Greater
        @test c4.rhs == 3.8

        c5 = constrs[5] # x - 3y1 + 8*y2 + z_1 >= 20
        @test c5.coeffs == [("y1", -3.0), ("z_1", 1.0), ("y2", 8.0), ("x", 1.0)]
        @test c5.duty == ClMP.MasterMixedConstr
        @test c5.sense == CL.Greater
        @test c5.rhs == 20.0

        sp1 = subproblems[1]
        names, kinds, duties, costs, bounds = get_vars_info(sp1)
        @test names == ["y1", "y2", "z_3"]
        @test kinds == [ClMP.Binary, ClMP.Binary, ClMP.Continuous]
        @test duties == [ClMP.DwSpPricingVar, ClMP.DwSpPricingVar, ClMP.DwSpPricingVar]
        @test costs == [4.5, 9.0, 2.2]
        @test bounds == [(0.0, 1.0), (0.0, 1.0), (-Inf, Inf)]

        sp2 = subproblems[2]
        names, kinds, duties, costs, bounds = get_vars_info(sp2)
        @test names == ["z_1", "y1", "y2", "z_2"]
        @test kinds == [ClMP.Continuous, ClMP.Binary, ClMP.Binary, ClMP.Continuous]
        @test duties == [ClMP.DwSpPricingVar, ClMP.DwSpPricingVar, ClMP.DwSpPricingVar, ClMP.DwSpPricingVar]
        @test costs == [-3.0, 4.5, 9.0, 1.0]
        @test bounds == [(6.2, Inf), (0.0, 1.0), (0.0, 1.0), (6.2, Inf)]
    end
end

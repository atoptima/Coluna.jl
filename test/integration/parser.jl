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

    @testset "multiple kinds, duties, subproblems and bounds" begin
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

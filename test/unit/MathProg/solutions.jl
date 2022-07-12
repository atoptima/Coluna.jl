@testset "MathProg - solution" begin
    @testset "isless - min sense" begin
        form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
        var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
        constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
        
        primalsol1 = ClMP.PrimalSolution(form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY)
        primalsol2 = ClMP.PrimalSolution(form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY)
        @test isless(primalsol1, primalsol2) # primalsol1 is worse than primalsol2 for min sense

        dualsol1 = ClMP.DualSolution(form, [ClMP.getid(constr)], [1.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 1.0, ClB.UNKNOWN_FEASIBILITY)
        dualsol2 = ClMP.DualSolution(form, [ClMP.getid(constr)], [0.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 0.0, ClB.UNKNOWN_FEASIBILITY)
        @test isless(dualsol2, dualsol1) # dualsol2 is worse than dualsol1 for min sense
    end

    @testset "isless - max sense" begin
        # MaxSense
        form = ClMP.create_formulation!(
            Env{ClMP.VarId}(Coluna.Params()), ClMP.Original(), obj_sense = Coluna.MathProg.MaxSense
        )
        var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
        constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)

        primalsol1 = ClMP.PrimalSolution(form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY)
        primalsol2 = ClMP.PrimalSolution(form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY)
        @test isless(primalsol2, primalsol1) # primalsol2 is worse than primalsol1 for max sense

        dualsol1 = ClMP.DualSolution(form, [ClMP.getid(constr)], [1.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 1.0, ClB.UNKNOWN_FEASIBILITY)
        dualsol2 = ClMP.DualSolution(form, [ClMP.getid(constr)], [0.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 0.0, ClB.UNKNOWN_FEASIBILITY)
        @test isless(dualsol1, dualsol2) # dualsol1 is worse than dualsol2 for max sense
    end

    @testset "isequal" begin
        form = ClMP.create_formulation!(
            Env{ClMP.VarId}(Coluna.Params()), ClMP.Original(), obj_sense = Coluna.MathProg.MaxSense
        )
        var1 = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
        var2 = ClMP.setvar!(form, "var2", ClMP.OriginalVar)

        primalsol1 = ClMP.PrimalSolution(form, [ClMP.getid(var1), ClMP.getid(var2)], [1.0, 2.0], 1.0, ClB.FEASIBLE_SOL)
        primalsol2 = ClMP.PrimalSolution(form, [ClMP.getid(var1), ClMP.getid(var2)], [1.0, 2.0], 1.0, ClB.FEASIBLE_SOL)
        @test primalsol1 == primalsol2
        
        constr1 = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
        constr2 = ClMP.setconstr!(form, "constr2", ClMP.OriginalConstr)
        dualsol1 = ClMP.DualSolution(
            form, 
            [ClMP.getid(constr2), ClMP.getid(constr1)],
            [-6.0, 1.0], 
            ClMP.VarId[ClMP.getid(var1)],
            Float64[2.0],
            ClMP.ActiveBound[ClMP.LOWER],
            1.0,
            ClB.FEASIBLE_SOL
        )
        dualsol2 = ClMP.DualSolution(
            form,
            [ClMP.getid(constr2), ClMP.getid(constr1)],
            [-6.0, 1.0], 
            ClMP.VarId[ClMP.getid(var1)],
            Float64[2.0],
            ClMP.ActiveBound[ClMP.LOWER],
            1.0,
            ClB.FEASIBLE_SOL
        )
        @test dualsol1 == dualsol2
    end
end
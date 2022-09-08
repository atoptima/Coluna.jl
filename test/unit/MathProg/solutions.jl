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

    @testset "lin alg 1 - vec basic op" begin
        form = ClMP.create_formulation!(
            Env{ClMP.VarId}(Coluna.Params()), ClMP.Original(), obj_sense = Coluna.MathProg.MaxSense
        )
        var1 = ClMP.setvar!(form, "var1", ClMP.OriginalVar; cost = 1.0)
        var2 = ClMP.setvar!(form, "var2", ClMP.OriginalVar; cost = 0.5)
        var3 = ClMP.setvar!(form, "var3", ClMP.OriginalVar; cost = -0.25)

        nzinds1 = [ClMP.getid(var1), ClMP.getid(var2)]
        nzvals1 = [1.0, 2.0]

        nzinds2 = [ClMP.getid(var1), ClMP.getid(var2), ClMP.getid(var3)]
        nzvals2 = [1.0, 2.0, 4.0]

        primalsol1 = ClMP.PrimalSolution(form, nzinds1, nzvals1, 2.0, ClB.FEASIBLE_SOL)
        primalsol2 = ClMP.PrimalSolution(form, nzinds2, nzvals2, 1.0, ClB.FEASIBLE_SOL)
    
        a = 2 * primalsol1
        b = primalsol1 + primalsol2
        c = primalsol1 - primalsol2

        @test ClB.getvalue(a) == 2 * ClB.getvalue(primalsol1)
        @test ClB.getvalue(b) == ClB.getvalue(primalsol1) + ClB.getvalue(primalsol2)
        @test ClB.getvalue(c) == ClB.getvalue(primalsol1) - ClB.getvalue(primalsol2)

        @test ClB.getstatus(a) == ClB.UNKNOWN_SOLUTION_STATUS
        @test ClB.getstatus(b) == ClB.UNKNOWN_SOLUTION_STATUS
        @test ClB.getstatus(c) == ClB.UNKNOWN_SOLUTION_STATUS

        @test findnz(a.solution.sol) == (nzinds1, 2*nzvals1)
        @test findnz(b.solution.sol) == (nzinds2, [nzvals1..., 0.0] + nzvals2)
        @test findnz(c.solution.sol) == ([ClMP.getid(var3)], [-4.0])
    end

    @testset "lin alg 2 - transpose" begin
        form = ClMP.create_formulation!(
            Env{ClMP.VarId}(Coluna.Params()), ClMP.Original(), obj_sense = Coluna.MathProg.MaxSense
        )
        var1 = ClMP.setvar!(form, "var1", ClMP.OriginalVar; cost = 1.0)
        var2 = ClMP.setvar!(form, "var2", ClMP.OriginalVar; cost = 0.5)
        var3 = ClMP.setvar!(form, "var3", ClMP.OriginalVar; cost = -0.25)

        nzinds1 = [ClMP.getid(var1), ClMP.getid(var2)]
        nzvals1 = [12.0, 4.0]
        vec1 = sparsevec(ClMP.getuid.(nzinds1), nzvals1, 4)
        primalsol1 = ClMP.PrimalSolution(form, nzinds1, nzvals1, 14.0, ClB.FEASIBLE_SOL)

        nzinds2 = [ClMP.getid(var1), ClMP.getid(var2), ClMP.getid(var3)]
        nzvals2 = [1.0, 2.0, 4.0]
        vec2 = sparsevec(ClMP.getuid.(nzinds2), nzvals2, 4)
        primalsol2 = ClMP.PrimalSolution(form, nzinds2, nzvals2, 1.0, ClB.FEASIBLE_SOL)

        a = transpose(vec1) * vec2
        b = transpose(primalsol1) * primalsol2
        @test a == b
    end

    @testset "lin alg 3 - spMv" begin
        form = ClMP.create_formulation!(
            Env{ClMP.VarId}(Coluna.Params()), ClMP.Original(), obj_sense = Coluna.MathProg.MaxSense
        )
        var1 = ClMP.setvar!(form, "var1", ClMP.OriginalVar; cost = 1.0)
        var2 = ClMP.setvar!(form, "var2", ClMP.OriginalVar; cost = 0.5)
        var3 = ClMP.setvar!(form, "var3", ClMP.OriginalVar; cost = -0.25)
        var4 = ClMP.setvar!(form, "var4", ClMP.OriginalVar; cost = 1.0)
        var5 = ClMP.setvar!(form, "var5", ClMP.OriginalVar; cost = 1.0)

        nzrows = ClMP.getid.([var1, var1, var2, var4, var4, var5]) # 5 rows
        nzcols = ClMP.getid.([var2, var3, var4, var1, var3, var1]) # 4 cols
        nzvals = [1.0, 2.5, 1.0, 4.0, 5.0, 1.2]

        int_nzrows = ClMP.getuid.(nzrows)
        int_nzcols = ClMP.getuid.(nzcols)

        dyn_mat = DynamicSparseArrays.dynamicsparse(nzrows, nzcols, nzvals) 
        mat = SparseArrays.sparse(int_nzrows, int_nzcols, nzvals, 5, 4)

        nzinds_sol1 = ClMP.getid.([var1, var3])::Vector{VarId}
        nzvals_sol1 = [2.0, 4.0]
        sol_len4 = ClMP.PrimalSolution(form, nzinds_sol1, nzvals_sol1, 2.0, ClB.FEASIBLE_SOL)
        vec_len4 = sparsevec(nzinds_sol1, nzvals_sol1, 4)
        int_vec_len4 = sparsevec(ClMP.getuid.(nzinds_sol1), nzvals_sol1, 4)

        nzinds_sol2 = ClMP.getid.([var2, var4])::Vector{VarId}
        nzvals_sol2 = [2.5, 4.5]
        sol_len5 = ClMP.PrimalSolution(form, nzinds_sol2, nzvals_sol2, 2.0, ClB.FEASIBLE_SOL)
        vec_len5 = sparsevec(nzinds_sol2, nzvals_sol2, 5)
        int_vec_len5 = sparsevec(ClMP.getuid.(nzinds_sol2), nzvals_sol2, 5)

        a = mat * int_vec_len4
        b = dyn_mat * sol_len4
        c = dyn_mat * vec_len4
        @test a == b == c

        e = transpose(mat) * int_vec_len5
        f = transpose(dyn_mat) * sol_len5
        g = transpose(dyn_mat) * vec_len5
        @test e == f == g 
    end
end
@testset "MathProg - variable" begin
    @testset "getters and setters" begin
        form = ClMP.create_formulation!(Env(Coluna.Params()), ClMP.Original())
        var = ClMP.setvar!(
            form, "var1", ClMP.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
            kind = ClMP.Integ, inc_val = 4.0
        )

        varid = ClMP.getid(var)

        @test ClMP.getperencost(form, varid) == 2.0
        @test ClMP.getperenlb(form, varid) == -1.0
        @test ClMP.getperenub(form, varid) == 1.0
        @test ClMP.getperensense(form, varid) == ClMP.Free
        @test ClMP.getperenkind(form, varid) == ClMP.Integ
        @test ClMP.getperenincval(form, varid) == 4.0

        @test ClMP.getcurcost(form, varid) == 2.0
        @test ClMP.getcurlb(form, varid) == -1.0
        @test ClMP.getcurub(form, varid) == 1.0
        @test ClMP.getcursense(form, varid) == ClMP.Free
        @test ClMP.getcurkind(form, varid) == ClMP.Integ
        @test ClMP.getcurincval(form, varid) == 4.0

        ClMP.setcurcost!(form, varid, 3.0)
        ClMP.setcurlb!(form, varid, -2.0)
        ClMP.setcurub!(form, varid, 2.0)
        ClMP.setcurkind!(form, varid, ClMP.Continuous)
        ClMP.setcurincval!(form, varid, 3.0)

        @test ClMP.getcurcost(form, varid) == 3.0
        @test ClMP.getcurlb(form, varid) == -2.0
        @test ClMP.getcurub(form, varid) == 2.0
        @test ClMP.getcursense(form, varid) == ClMP.Free
        @test ClMP.getcurkind(form, varid) == ClMP.Continuous
        @test ClMP.getcurincval(form, varid) == 3.0

        ClMP.reset!(form, varid)
        @test ClMP.getcurcost(form, varid) == 2.0
        @test ClMP.getcurlb(form, varid) == -1.0
        @test ClMP.getcurub(form, varid) == 1.0
        @test ClMP.getcursense(form, varid) == ClMP.Free
        @test ClMP.getcurkind(form, varid) == ClMP.Integ
        @test ClMP.getcurincval(form, varid) == 4.0
    end

    @testset "record" begin
        v_rec = ClMP.MoiVarRecord(; index = ClMP.MoiVarIndex(-15))

        @test ClMP.getindex(v_rec) == ClMP.MoiVarIndex(-15)
        @test ClMP.getbounds(v_rec) == ClMP.MoiVarBound(-1)

        ClMP.setindex!(v_rec, ClMP.MoiVarIndex(-20))
        ClMP.setbounds!(v_rec, ClMP.MoiVarBound(10))

        @test ClMP.getindex(v_rec) == ClMP.MoiVarIndex(-20)
        @test ClMP.getbounds(v_rec) == ClMP.MoiVarBound(10)
    end
end
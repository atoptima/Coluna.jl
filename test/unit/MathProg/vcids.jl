@testset "MathProg - variable and constraint ids" begin
    @testset "_create_hash" begin
        uid = 1
        origin_form_uid = 2
        proc_uid = 3

        hash1 = Coluna.MathProg._create_hash(uid)
        hash2 = Coluna.MathProg._create_hash(Int8(uid))
        hash3 = Coluna.MathProg._create_hash(UInt16(uid))

        @test hash1 === hash2
        @test hash2 === hash3
    end

    @testset "id equality" begin
        # vid1 & vid2 have same uid 1. vid3 has uid 2.
        vid1 = ClMP.VarId(ClMP.OriginalVar, 1, 1)
        vid2 = ClMP.VarId(ClMP.DwSpPricingVar, 1, 2)
        vid3 = ClMP.VarId(ClMP.OriginalVar, 2, 1)

        @test vid1 == vid2
        @test vid1 != vid3

        dict = Dict{ClMP.VarId, Float64}()
        dict[vid1] = 1.0
        dict[vid3] = 2.0

        @test dict[vid1] == 1.0
        @test dict[vid2] == 1.0
        @test dict[vid3] == 2.0

        dict[vid2] = 3.0

        @test dict[vid1] == 3.0
        @test dict[vid2] == 3.0
        @test dict[vid3] == 2.0

        @test haskey(dict, vid1)
        @test haskey(dict, vid2)
        @test haskey(dict, vid3)
    end
end
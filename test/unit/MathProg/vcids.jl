@testset "MathProg - variable and constraint ids" begin
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

    @testset "math operations" begin
        vid1 = ClMP.VarId(ClMP.OriginalVar, 1, 1)
        @test vid1 + 1 == 2
        @test vid1 - 1 == 0

        @test vid1 < 2
        @test vid1 <= 2
        @test 2 >= vid1
        @test 2 > vid1
        @test vid1 == 1
        @test isequal(vid1, 1)

        vid2 = ClMP.VarId(ClMP.OriginalVar, 2, 1)
        @test vid1 < vid2
        @test vid1 <= vid2
        @test vid2 >= vid1
        @test vid2 > vid1

        vid3 = ClMP.VarId(ClMP.OriginalVar, 2, 2)
        @test vid2 <= vid3
        @test vid2 >= vid3
        @test vid2 == vid3
        @test isequal(vid2, vid3)

        @test vid1 + vid2 == 3
        @test vid1 - vid2 == -1
        @test vid1 * vid2 == 2
    end
end
@testset "MathProg - solshashtable" begin
    x = ClMP.VarId(ClMP.OriginalVar, 1, 1)
    y = ClMP.VarId(ClMP.OriginalVar, 2, 1)
    z = ClMP.VarId(ClMP.OriginalVar, 3, 1)
    col1 = ClMP.VarId(ClMP.MasterCol, 1, 2)
    sol1 = [(x, 1.0), (z, 2.0)]
    col2 = ClMP.VarId(ClMP.MasterCol, 2, 2)
    sol2 = [(x, 2.0), (y, -1.0)]
    col3 = ClMP.VarId(ClMP.MasterCol, 3, 2)
    sol3 = [(y, -1.0), (z, 3.0)]
    col4 = ClMP.VarId(ClMP.MasterCol, 4, 2)
    sol4 = [(x, 1.0)]
    col5 = ClMP.VarId(ClMP.MasterCol, 5, 2)
    sol5 = [(z, -2.0), (y, 1.0)]
    sht = ClMP.SolutionsHashTable()
    push!(ClMP.getcolids(sht, sol1), col1)
    push!(ClMP.getcolids(sht, sol2), col2)
    push!(ClMP.getcolids(sht, sol3), col3)
    push!(ClMP.getcolids(sht, sol4), col4)
    push!(ClMP.getcolids(sht, sol5), col5)
    @test ClMP.getcolids(sht, sol1) == [col1]
    @test ClMP.getcolids(sht, sol2) == [col2]
    @test ClMP.getcolids(sht, sol3) == [col3, col5]
    @test ClMP.getcolids(sht, sol4) == [col4]
    @test ClMP.getcolids(sht, sol5) == [col3, col5]
end

@testset "ColunaBase - hash table 1" begin
    x = 'A'
    y = 'B'
    z = 'C'

    col1 = 1
    sol1 = [(x, 1.0), (z, 2.0)]

    col2 = 2
    sol2 = [(x, 2.0), (y, -1.0)]

    col3 = 3
    sol3 = [(y, -1.0), (z, 3.0)]

    col4 = 4
    sol4 = [(x, 1.0)]

    col5 = 5
    sol5 = [(z, -2.0), (y, 1.0)]

    ht = ClB.HashTable{Char,Int}()

    ClB.savesolid!(ht, col1, sol1)
    ClB.savesolid!(ht, col2, sol2)
    ClB.savesolid!(ht, col3, sol3)
    ClB.savesolid!(ht, col4, sol4)
    ClB.savesolid!(ht, col5, sol5)

    @test ClB.getsolids(ht, sol1) == [col1]
    @test ClB.getsolids(ht, sol2) == [col2]
    @test ClB.getsolids(ht, sol3) == [col3, col5]
    @test ClB.getsolids(ht, sol4) == [col4]
    @test ClB.getsolids(ht, sol5) == [col3, col5]
end

# Same test as "hash table 1" but we use VarIds from Coluna.
@testset "ColunaBase - hash table 2" begin
    x = ClMP.VarId(ClMP.OriginalVar, 1, 1)
    y = ClMP.VarId(ClMP.OriginalVar, 2, 1)
    z = ClMP.VarId(ClMP.OriginalVar, 3, 1)

    col1 = ClMP.VarId(ClMP.MasterCol, 4, 2)
    sol1 = [(x, 1.0), (z, 2.0)]

    col2 = ClMP.VarId(ClMP.MasterCol, 5, 2)
    sol2 = [(x, 2.0), (y, -1.0)]

    col3 = ClMP.VarId(ClMP.MasterCol, 6, 2)
    sol3 = [(y, -1.0), (z, 3.0)]

    col4 = ClMP.VarId(ClMP.MasterCol, 7, 2)
    sol4 = [(x, 1.0)]

    col5 = ClMP.VarId(ClMP.MasterCol, 8, 2)
    sol5 = [(z, -2.0), (y, 1.0)]

    ht = ClB.HashTable{ClMP.VarId, ClMP.VarId}()

    ClB.savesolid!(ht, col1, sol1)
    ClB.savesolid!(ht, col2, sol2)
    ClB.savesolid!(ht, col3, sol3)
    ClB.savesolid!(ht, col4, sol4)
    ClB.savesolid!(ht, col5, sol5)

    @test ClB.getsolids(ht, sol1) == [col1]
    @test ClB.getsolids(ht, sol2) == [col2]
    @test ClB.getsolids(ht, sol3) == [col3, col5]
    @test ClB.getsolids(ht, sol4) == [col4]
    @test ClB.getsolids(ht, sol5) == [col3, col5]
end

function vcdict_unit_tests()
    vcdict_base_unit_tests()
end

function vcdict_base_unit_tests()
    elems = Dict(1=>false, 2=> true, 3=> true, 4=>false)
    a = CL.MembersVector{Int, Bool, Float64}(elems)
    a[1] = 1
    @test a[1] == 1.0
    @test a[2] == 0.0
    @test a[:] == a

    b = CL.MembersVector{Int, Bool, Float64}(elems)
    b[4] = 2.0
    b[1] = 1.5
    b[2] = 8.0

    sum_id = 0
    sum_val = 0.0
    for (id, val) in b
        sum_id += id
        sum_val += val
    end
    @test sum_id == 7
    @test sum_val == 11.5

    c = merge(+, a, b)
    @test c[1] == 2.5
    d = reduce(+, c)
    @test d == 12.5

    cols_elems = Dict(1 => true, 2 => true, 4 => false, 5 => false)
    rows_elems = Dict(1 => true, 2 => false, 3 => false, 6 => true)
    m = CL.OldMembersMatrix{Int,Bool,Int,Bool,Float64}(cols_elems, rows_elems)
    m[2,1] = 1.0
    @test m[2,1] == 1.0
    @test m[:,1][2] == 1.0
    @test m[2,:][1] == 1.0
    
    new_column = Dict{Int, Float64}()
    new_column[2] = 9.0
    new_column[5] = 2.0

    m[:, 2] = new_column
    @test m[:, 2] == new_column
    @test m[5, 2] == 2.0

    for (id, col) in CL.columns(m)
        println("$id -> $col")
        @show m[:, id]
    end

end
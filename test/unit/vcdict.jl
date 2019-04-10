function vcdict_unit_tests()
    vcdict_base_unit_tests()
end

function vcdict_base_unit_tests()
    a = CL.MembersVector{Int, Float64}()
    a[1] = 1
    @test a[1] == 1.0
    @test a[2] == 0.0
    @test a[:] == a

    b = CL.MembersVector{Int, Float64}()
    b[4] = 2.0
    b[1] = 1.5

    sum_id = 0
    sum_val = 0.0
    for (id, val) in b
        sum_id += id
        sum_val += val
    end
    @test sum_id == 5
    @test sum_val == 3.5

    c = merge(+, a, b)
    @test c[1] == 2.5
    d = reduce(+, c)
    @test d == 4.5

    cols_elems = Dict(1 => true, 2 => true, 4 => false, 5 => false)
    rows_elems = Dict(1 => true, 2 => false, 3 => false, 6 => true)
    m = CL.MembersMatrix{Int,Bool,Int,Bool,Float64}(cols_elems, rows_elems)
    m[1,2] = 1.0
    @test m[1,2] == 1.0
    @test m[1,:][2] == 1.0
    @test m[:,2][1] == 1.0
    
    new_column = CL.MembersVector{Int, Float64}()
    new_column[2] = 9.0
    new_column[5] = 2.0

    CL.setcolumn!(m, 2, new_column)
    @test m[2, :] == new_column
    @test m[2, 5] == 2.0

    
end
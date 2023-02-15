DynamicSparseArrays.semaphore_key(::Type{Char}) = ' '
Base.zero(::Type{Char}) = ' '
DynamicSparseArrays.semaphore_key(::Type{Int}) = 0

function coefmatrix_factory()
    rows = ['a', 'a', 'b', 'b', 'd', 'f']
    cols = [1, 2, 3, 1, 7, 1]
    vals = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    buffer = ClMP.FormulationBuffer{Int,Nothing,Char,Nothing}()
    matrix = ClMP.CoefficientMatrix{Char,Int,Float64}(buffer)
    for (i,j,v) in Iterators.zip(rows, cols, vals)
        matrix[i,j] = v
    end
    return rows, cols, vals, matrix
end

@testset "MathProg - coefficient matrix" begin
    @testset "close fill mode" begin
        rows, cols, vals, matrix = coefmatrix_factory()
        closefillmode!(matrix)
        for (i,j,v) in Iterators.zip(rows, cols, vals)
            @test matrix[i,j] == v
        end
    end

    @testset "view col" begin
        rows, cols, vals, matrix = coefmatrix_factory()
        closefillmode!(matrix)

        for (row, val) in @view matrix[:, 1]
            @test val == matrix[row,1]
        end
    end

    @testset "view row" begin
        rows, cols, vals, matrix = coefmatrix_factory()
        closefillmode!(matrix)

        for (col, val) in @view matrix['a', :]
            @test val == matrix['a', col]
        end
    end

    @testset "transpose" begin
        rows, cols, vals, matrix = coefmatrix_factory()
        closefillmode!(matrix)

        transposed_matrix = transpose(matrix)

        for (i,j,v) in Iterators.zip(rows, cols, vals)
            @test transposed_matrix[j,i] == matrix[i,j] == v
        end
    end
end
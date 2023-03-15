Coluna.MustImplement.@mustimplement "API" mi_f1()
Coluna.MustImplement.@mustimplement "API" mi_f2(a, b)
mi_f2(a::Int, b::Int) = a+b

@testset "MustImplement" begin
    @test_throws Coluna.MustImplement.IncompleteInterfaceError mi_f1()
    @test_throws Coluna.MustImplement.IncompleteInterfaceError mi_f2("a", "b")
    @test mi_f2(1,2) == 3
end
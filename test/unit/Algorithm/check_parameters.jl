struct Algorithm1 <: Coluna.AlgoAPI.AbstractAlgorithm
    a::Int
    b::Int
end

ClA.check_parameter(::Algorithm1, ::Val{:a}, value, reform) = 0 <= value <= 1
ClA.check_parameter(::Algorithm1, ::Val{:b}, value, reform) = 1 <= value <= 2

struct Algorithm2 <: Coluna.AlgoAPI.AbstractAlgorithm
    alg1::Algorithm1
    c::String
end

ClA.get_child_algorithms(a::Algorithm2, reform::ClMP.Reformulation) = Dict("alg1" => (a.alg1, reform))

# We check that the parameters of the child algorithm is consistent with the expected value.
ClA.check_parameter(::Algorithm2, ::Val{:alg1}, value, reform) = value.a != -1
ClA.check_parameter(::Algorithm2, ::Val{:c}, value, reform) = length(value) == 4

struct Algorithm3 <: Coluna.AlgoAPI.AbstractAlgorithm
    d::String
    e::Int
end

ClA.check_parameter(::Algorithm3, ::Val{:d}, value, reform) = length(value) == 3
ClA.check_parameter(::Algorithm3, ::Val{:e}, value, reform) = 5 <= value <= 8

struct Algorithm4 <: Coluna.AlgoAPI.AbstractAlgorithm
    alg2::Algorithm2
    alg3::Algorithm3
end

ClA.get_child_algorithms(a::Algorithm4, reform::ClMP.Reformulation) = Dict(
    "alg2" => (a.alg2, reform),
    "alg3" => (a.alg3, reform)
)

ClA.check_parameter(::Algorithm4, ::Val{:alg2}, value, reform) = true
ClA.check_parameter(::Algorithm4, ::Val{:alg3}, value, reform) = true

function check_parameters_1()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())
    reform = ClMP.Reformulation(env)
    alg1 = Algorithm1(1, 2) # ok, ok
    alg2 = Algorithm2(alg1, "3") # ok, not ok
    alg3 = Algorithm3("4", 5)    # not ok, ok
    top_algo = Algorithm4(alg2, alg3)
    inconsistencies = ClA.check_alg_parameters(top_algo, reform)
    @test (:c, alg2, "3") ∈ inconsistencies
    @test (:d, alg3, "4") ∈ inconsistencies
    @test length(inconsistencies) == 2
end
register!(unit_tests, "Algorithm", check_parameters_1)

# we test with all checks returning false
function check_parameters_2()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())
    reform = ClMP.Reformulation(env)
    alg1 = Algorithm1(-1, -3) # not ok, not ok
    alg2 = Algorithm2(alg1, "N")  # not ok, not ok
    alg3 = Algorithm3("N", 4)     # not ok, not ok
    top_algo = Algorithm4(alg2, alg3)
    inconsistencies = ClA.check_alg_parameters(top_algo, reform)
    @test (:a, alg1, -1) ∈ inconsistencies
    @test (:b, alg1, -3) ∈ inconsistencies
    @test (:c, alg2, "N") ∈ inconsistencies
    @test (:alg1, alg2, alg1) ∈ inconsistencies
    @test (:d, alg3, "N") ∈ inconsistencies
    @test (:e, alg3, 4) ∈ inconsistencies
    @test length(inconsistencies) == 6
end
register!(unit_tests, "Algorithm", check_parameters_2)
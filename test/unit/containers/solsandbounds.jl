function bound_unit()
    Primal = Coluna.AbstractPrimalSpace
    Dual = Coluna.AbstractDualSpace
    MinSense = Coluna.AbstractMinSense
    MaxSense = Coluna.AbstractMaxSense

    @testset "Bound" begin
        pb = Coluna.Containers.Bound{Primal,MinSense}()
        @test pb == Inf
        
        pb = Coluna.Containers.Bound{Primal,MaxSense}()
        @test pb == -Inf

        db = Coluna.Containers.Bound{Dual,MinSense}()
        @test db == -Inf

        db = Coluna.Containers.Bound{Dual,MaxSense}()
        @test db == Inf

        pb = Coluna.Containers.Bound{Primal,MinSense}(100)
        @test pb == 100

        db = Coluna.Containers.Bound{Dual,MinSense}(-π)
        @test db == -π
    end

    @testset "isbetter" begin
        # In minimization, pb with value 10 is better than pb with value 15
        pb1 = Coluna.Containers.Bound{Primal,MinSense}(10.0)
        pb2 = Coluna.Containers.Bound{Primal,MinSense}(15.0)
        @test Coluna.Containers.isbetter(pb1, pb2) == !Coluna.Containers.isbetter(pb2, pb1) == true

        # In maximization, pb with value 15 is better than pb with value 10
        pb1 = Coluna.Containers.Bound{Primal,MaxSense}(10.0)
        pb2 = Coluna.Containers.Bound{Primal,MaxSense}(15.0)
        @test Coluna.Containers.isbetter(pb2, pb1) == !Coluna.Containers.isbetter(pb1, pb2) == true

        # In minimization, db with value 15 is better than db with value 10
        db1 = Coluna.Containers.Bound{Dual,MinSense}(15.0)
        db2 = Coluna.Containers.Bound{Dual,MinSense}(10.0)
        @test Coluna.Containers.isbetter(db1, db2) == !Coluna.Containers.isbetter(db2, db1) == true

        # In maximization, db with value 10 is better than db with value 15
        db1 = Coluna.Containers.Bound{Dual,MaxSense}(15.0)
        db2 = Coluna.Containers.Bound{Dual,MaxSense}(10.0)
        @test Coluna.Containers.isbetter(db2, db1) == !Coluna.Containers.isbetter(db1, db2) == true

        # Cannot compare a primal & a dual bound
        db1 = Coluna.Containers.Bound{Dual,MaxSense}(-10.0)
        @test_throws MethodError Coluna.Containers.isbetter(db1, pb1)

        # Cannot compare a bound from maximization & a bound from minimization
        db2 = Coluna.Containers.Bound{Dual,MinSense}(10.0)
        @test_throws MethodError Coluna.Containers.isbetter(db1, db2)
    end

    @testset "diff" begin
        # Compute distance between primal bound and dual bound
        # In minimization, if pb = 10 & db = 5, distance is 5
        pb = Coluna.Containers.Bound{Primal,MinSense}(10)
        db = Coluna.Containers.Bound{Dual,MinSense}(5)
        @test Coluna.Containers.diff(pb, db) == Coluna.Containers.diff(db, pb) == 5

        # In maximisation if pb = 10 & db = 5, distance is -5
        pb = Coluna.Containers.Bound{Primal,MaxSense}(10)
        db = Coluna.Containers.Bound{Dual,MaxSense}(5)
        @test Coluna.Containers.diff(pb, db) == Coluna.Containers.diff(db, pb) == -5

        # Cannot compute the distance between two primal bounds
        pb1 = Coluna.Containers.Bound{Primal,MaxSense}(10)
        pb2 = Coluna.Containers.Bound{Primal,MaxSense}(15)
        @test_throws MethodError Coluna.Containers.diff(pb1, pb2)

        # Cannot compute the distance between two dual bounds
        db1 = Coluna.Containers.Bound{Dual,MaxSense}(5)
        db2 = Coluna.Containers.Bound{Dual,MaxSense}(50)
        @test_throws MethodError Coluna.Containers.diff(db1, db2)

        # Cannot compute the distance between two bounds from different sense
        pb = Coluna.Containers.Bound{Primal,MaxSense}(10)
        db = Coluna.Containers.Bound{Dual,MinSense}(5)
        @test_throws MethodError Coluna.Containers.diff(pb, db)
    end

    @testset "gap" begin
        # In minimisation, gap = (pb - db)/db
        pb = Coluna.Containers.Bound{Primal,MinSense}(10.0)
        db = Coluna.Containers.Bound{Dual,MinSense}(5.0)
        @test Coluna.Containers.gap(pb, db) == Coluna.Containers.gap(db, pb) == (10.0-5.0)/5.0
    
        # In maximisation, gap = (db - pb)/pb
        pb = Coluna.Containers.Bound{Primal,MaxSense}(5.0)
        db = Coluna.Containers.Bound{Dual,MaxSense}(10.0)
        @test Coluna.Containers.gap(pb, db) == Coluna.Containers.gap(db, pb) == (10.0-5.0)/5.0
    
        pb = Coluna.Containers.Bound{Primal,MinSense}(10.0)
        db = Coluna.Containers.Bound{Dual,MinSense}(-5.0)
        @test Coluna.Containers.gap(pb, db) == Coluna.Containers.gap(db, pb) == (10.0+5.0)/5.0   

        # Cannot compute the gap between 2 primal bounds
        pb1 = Coluna.Containers.Bound{Primal,MaxSense}(10)
        pb2 = Coluna.Containers.Bound{Primal,MaxSense}(15)
        @test_throws MethodError Coluna.Containers.gap(pb1, pb2)

        # Cannot compute the gap between 2 dual bounds
        db1 = Coluna.Containers.Bound{Dual,MaxSense}(5)
        db2 = Coluna.Containers.Bound{Dual,MaxSense}(50)
        @test_throws MethodError Coluna.Containers.gap(db1, db2)

        # Cannot compute the gap between 2 bounds with different sense
        pb = Coluna.Containers.Bound{Primal,MaxSense}(10)
        db = Coluna.Containers.Bound{Dual,MinSense}(5)
        @test_throws MethodError Coluna.Containers.gap(pb, db)
    end

    @testset "printbounds" begin
        # In minimisation sense
        pb1 = Coluna.Containers.Bound{Primal, MinSense}(100)
        db1 = Coluna.Containers.Bound{Dual, MinSense}(-100)
        # TODO

        # In maximisation sense
        pb2 = Coluna.Containers.Bound{Primal, MaxSense}(-100)
        db2 = Coluna.Containers.Bound{Dual, MaxSense}(100)
        # TODO
    end

    @testset "show" begin
        pb = Coluna.Containers.Bound{Primal,MaxSense}(4)
        @test repr(pb) == "4.0"
    end

    @testset "Promotions & conversions" begin
        pb = Coluna.Containers.Bound{Primal,MaxSense}(4.0)
        @test eltype(promote(pb, 1)) == typeof(pb)
        @test eltype(promote(pb, 2.0)) == typeof(pb)
        @test eltype(promote(pb, π)) == typeof(pb)
        @test eltype(promote(pb, 1, 2.0, π)) == typeof(pb)

        @test typeof(pb + 1) == typeof(pb) # check that promotion works

        @test pb < 5
        @test pb > 3
        @test pb <= 4
        @test pb >= 4
        @test pb == 4
        @test pb != 3
        @test pb + 1 == 5
        @test pb - 1 == 3
        @test pb / 4 == 1
        @test pb * 2 == 8

        db = Coluna.Containers.Bound{Dual,MaxSense}(2.5)
        # In a given sense, promotion of pb & a db gives a float
        @test eltype(promote(pb, db)) == Float64

        # Promotion between two bounds of different senses does not work
        pb1 = Coluna.Containers.Bound{Primal,MaxSense}(2.5)
        pb2 = Coluna.Containers.Bound{Primal,MinSense}(2.5)
        @test_throws ErrorException promote(pb1, pb2)

        db1 = Coluna.Containers.Bound{Dual,MaxSense}(2.5)
        db2 = Coluna.Containers.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(db1, db2)

        pb = Coluna.Containers.Bound{Primal,MaxSense}(2.5)
        db = Coluna.Containers.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(pb, db)
    end
end

function fake_solution_factory(nbdecisions)
    decisions = Set{Int}()
    i = 0
    while i < nbdecisions
        v = rand(rng, 1:100)
        if v ∉ decisions
            push!(decisions, v)
            i += 1
        end
    end
    solution = Dict{Int, Float64}()
    for d in decisions
        solution[d] = rand(rng, 0:0.0001:1000)
    end
    return solution
end

function test_solution_iterations(solution::Coluna.Containers.Solution, dict::Dict)
    prev_decision = nothing
    for (decision, value) in solution
        if prev_decision != nothing
            @test prev_decision < decision
        end
        @test solution[decision] == dict[decision]
        solution[decision] += 1
        @test solution[decision] == dict[decision] + 1
    end
    return
end

function solution_unit()
    Primal = Coluna.AbstractPrimalSpace
    Dual = Coluna.AbstractDualSpace
    MinSense = Coluna.AbstractMinSense
    MaxSense = Coluna.AbstractMaxSense

    PrimalSolution{S} = Coluna.Containers.Solution{Primal,S,Int,Float64}
    DualSolution{S} = Coluna.Containers.Solution{Dual,S,Int,Float64}

    dict_sol = fake_solution_factory(100)
    primal_sol = PrimalSolution{MinSense}(dict_sol, 12.3)
    test_solution_iterations(primal_sol, dict_sol)
    @test Coluna.Containers.getvalue(primal_sol) == 12.3
    Coluna.Containers.setvalue!(primal_sol, 123.4)
    @test Coluna.Containers.getvalue(primal_sol) == 123.4
    @test typeof(Coluna.Containers.getbound(primal_sol)) == Coluna.Containers.Bound{Primal,MinSense}
    
    dict_sol = fake_solution_factory(100)
    dual_sol = DualSolution{MaxSense}(dict_sol, 32.1)
    test_solution_iterations(dual_sol, dict_sol)
    @test Coluna.Containers.getvalue(dual_sol) == 32.1
    Coluna.Containers.setvalue!(dual_sol, 432.1)
    @test Coluna.Containers.getvalue(dual_sol) == 432.1
    @test typeof(Coluna.Containers.getbound(dual_sol)) == Coluna.Containers.Bound{Dual,MaxSense}
    return
end

# function solution_constructors_and_getters_and_setters_tests()
#     counter = ClF.Counter()
#     f1 = ClF.Formulation{ClF.Original}(counter, obj_sense = ClF.MinSense) 
#     primal_sol = ClF.PrimalSolution(f1)

#     f2 = ClF.Formulation{ClF.Original}(counter, obj_sense = ClF.MaxSense)
#     dual_sol = ClF.DualSolution(f2)

#     @test ClF.getbound(primal_sol) == ClF.PrimalBound{ClF.MinSense}(Inf)
#     @test ClF.getvalue(primal_sol) == Inf
#     @test ClF.getsol(primal_sol) == Dict{ClF.Id{ClF.Variable},Float64}()

#     @test ClF.getbound(dual_sol) == ClF.DualBound{ClF.MaxSense}(Inf)
#     @test ClF.getvalue(dual_sol) == Inf
#     @test ClF.getsol(dual_sol) == Dict{ClF.Id{ClF.Constraint},Float64}()

#     primal_sol = ClF.PrimalSolution(f1, -12.0, Dict{ClF.Id{ClF.Variable},Float64}())
#     dual_sol = ClF.DualSolution(f2, -13.0, Dict{ClF.Id{ClF.Constraint},Float64}())

#     @test ClF.getbound(primal_sol) == ClF.PrimalBound{ClF.MinSense}(-12.0)
#     @test ClF.getvalue(primal_sol) == -12.0
#     @test ClF.getsol(primal_sol) == Dict{ClF.Id{ClF.Variable},Float64}()

#     @test ClF.getbound(dual_sol) == ClF.DualBound{ClF.MaxSense}(-13.0)
#     @test ClF.getvalue(dual_sol) == -13.0
#     @test ClF.getsol(dual_sol) == Dict{ClF.Id{ClF.Constraint},Float64}()

# end

# function solution_base_functions_tests()

#     sol = Dict{ClF.Id{ClF.Variable},Float64}()
#     sol[ClF.Id{ClF.Variable}(1, 10)] = 1.0
#     sol[ClF.Id{ClF.Variable}(2, 10)] = 2.0
    
#     counter = ClF.Counter()
#     f = ClF.Formulation{ClF.Original}(counter, obj_sense = ClF.MinSense) 
#     primal_sol = ClF.PrimalSolution(f, ClF.PrimalBound{ClF.MinSense}(3.0), sol)
    
#     copy_sol = ClF.Base.copy(primal_sol)
#     @test copy_sol.bound === primal_sol.bound
#     @test copy_sol.sol == primal_sol.sol

#     @test ClF.Base.length(primal_sol) == 2
#     for (v, val) in primal_sol
#         @test typeof(v) <: ClF.Id
#         @test typeof(val) == Float64
#     end

# end

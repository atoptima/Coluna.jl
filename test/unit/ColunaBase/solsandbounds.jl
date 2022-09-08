const Primal = Coluna.AbstractPrimalSpace
const Dual = Coluna.AbstractDualSpace
const MinSense = Coluna.AbstractMinSense
const MaxSense = Coluna.AbstractMaxSense

struct FakeModel <: ClB.AbstractModel 
    id::Int
end
FakeModel() = FakeModel(1)

const Solution = ClB.Solution{FakeModel,Int,Float64}

@testset "ColunaBase - bound" begin
    @testset "constructors" begin
        # Make sure that Coluna initializes bounds to infinity.
        # Check that initial value of the bound is correct.
        pb = ClB.Bound{Primal,MinSense}()
        @test pb == Inf
        @test ClB.getvalue(pb) == Inf
        
        pb = ClB.Bound{Primal,MaxSense}()
        @test pb == -Inf
        @test ClB.getvalue(pb) == -Inf
        
        db = ClB.Bound{Dual,MinSense}()
        @test db == -Inf
        @test ClB.getvalue(db) == -Inf
        
        db = ClB.Bound{Dual,MaxSense}()
        @test db == Inf
        @test ClB.getvalue(db) == Inf
        
        pb = ClB.Bound{Primal,MinSense}(100)
        @test pb == 100
        @test ClB.getvalue(pb) == 100
        @test typeof(float(db)) <: Float64

        db = ClB.Bound{Dual,MinSense}(-π)
        @test db == -π
        @test ClB.getvalue(db) == -π
    end

    @testset "isbetter" begin
        # In minimization, pb with value 10 is better than pb with value 15
        pb1 = ClB.Bound{Primal,MinSense}(10.0)
        pb2 = ClB.Bound{Primal,MinSense}(15.0)
        @test ClB.isbetter(pb1, pb2) == !ClB.isbetter(pb2, pb1) == true

        # In maximization, pb with value 15 is better than pb with value 10
        pb1 = ClB.Bound{Primal,MaxSense}(10.0)
        pb2 = ClB.Bound{Primal,MaxSense}(15.0)
        @test ClB.isbetter(pb2, pb1) == !ClB.isbetter(pb1, pb2) == true

        # In minimization, db with value 15 is better than db with value 10
        db1 = ClB.Bound{Dual,MinSense}(15.0)
        db2 = ClB.Bound{Dual,MinSense}(10.0)
        @test ClB.isbetter(db1, db2) == !ClB.isbetter(db2, db1) == true

        # In maximization, db with value 10 is better than db with value 15
        db1 = ClB.Bound{Dual,MaxSense}(15.0)
        db2 = ClB.Bound{Dual,MaxSense}(10.0)
        @test ClB.isbetter(db2, db1) == !ClB.isbetter(db1, db2) == true

        # Cannot compare a primal & a dual bound
        db1 = ClB.Bound{Dual,MaxSense}(-10.0)
        @test_throws MethodError ClB.isbetter(db1, pb1)

        # Cannot compare a bound from maximization & a bound from minimization
        db2 = ClB.Bound{Dual,MinSense}(10.0)
        @test_throws MethodError ClB.isbetter(db1, db2)
    end

    @testset "diff" begin
        # Compute distance between primal bound and dual bound
        # In minimization, if pb = 10 & db = 5, distance is 5
        pb = ClB.Bound{Primal,MinSense}(10)
        db = ClB.Bound{Dual,MinSense}(5)
        @test ClB.diff(pb, db) == ClB.diff(db, pb) == 5

        # In maximisation if pb = 10 & db = 5, distance is -5
        pb = ClB.Bound{Primal,MaxSense}(10)
        db = ClB.Bound{Dual,MaxSense}(5)
        @test ClB.diff(pb, db) == ClB.diff(db, pb) == -5

        # Cannot compute the distance between two primal bounds
        pb1 = ClB.Bound{Primal,MaxSense}(10)
        pb2 = ClB.Bound{Primal,MaxSense}(15)
        @test_throws MethodError ClB.diff(pb1, pb2)

        # Cannot compute the distance between two dual bounds
        db1 = ClB.Bound{Dual,MaxSense}(5)
        db2 = ClB.Bound{Dual,MaxSense}(50)
        @test_throws MethodError ClB.diff(db1, db2)

        # Cannot compute the distance between two bounds from different sense
        pb = ClB.Bound{Primal,MaxSense}(10)
        db = ClB.Bound{Dual,MinSense}(5)
        @test_throws MethodError ClB.diff(pb, db)
    end

    @testset "gap" begin
        # In minimisation, gap = (pb - db)/db
        pb = ClB.Bound{Primal,MinSense}(10.0)
        db = ClB.Bound{Dual,MinSense}(5.0)
        @test ClB.gap(pb, db) == ClB.gap(db, pb) == (10.0-5.0)/5.0
    
        # In maximisation, gap = (db - pb)/pb
        pb = ClB.Bound{Primal,MaxSense}(5.0)
        db = ClB.Bound{Dual,MaxSense}(10.0)
        @test ClB.gap(pb, db) == ClB.gap(db, pb) == (10.0-5.0)/5.0
    
        pb = ClB.Bound{Primal,MinSense}(10.0)
        db = ClB.Bound{Dual,MinSense}(-5.0)
        @test ClB.gap(pb, db) == ClB.gap(db, pb) == (10.0+5.0)/5.0   

        # Cannot compute the gap between 2 primal bounds
        pb1 = ClB.Bound{Primal,MaxSense}(10)
        pb2 = ClB.Bound{Primal,MaxSense}(15)
        @test_throws MethodError ClB.gap(pb1, pb2)

        # Cannot compute the gap between 2 dual bounds
        db1 = ClB.Bound{Dual,MaxSense}(5)
        db2 = ClB.Bound{Dual,MaxSense}(50)
        @test_throws MethodError ClB.gap(db1, db2)

        # Cannot compute the gap between 2 bounds with different sense
        pb = ClB.Bound{Primal,MaxSense}(10)
        db = ClB.Bound{Dual,MinSense}(5)
        @test_throws MethodError ClB.gap(pb, db)
    end

    @testset "printbounds" begin
        # In minimisation sense
        pb1 = ClB.Bound{Primal, MinSense}(100)
        db1 = ClB.Bound{Dual, MinSense}(-100)
        io = IOBuffer()
        ClB.printbounds(db1, pb1, io)
        @test String(take!(io)) == "[ -100.0000 , 100.0000 ]"

        # In maximisation sense
        pb2 = ClB.Bound{Primal, MaxSense}(-100)
        db2 = ClB.Bound{Dual, MaxSense}(100)
        io = IOBuffer()
        ClB.printbounds(db2, pb2, io)
        @test String(take!(io)) == "[ -100.0000 , 100.0000 ]"
    end

    @testset "show" begin
        pb = ClB.Bound{Primal,MaxSense}(4)
        io = IOBuffer()
        show(io, pb)
        @test String(take!(io)) == "4.0" 
    end

    @testset "promotions & conversions" begin
        pb = ClB.Bound{Primal,MaxSense}(4.0)
        db = ClB.Bound{Dual,MaxSense}(2.0)
        @test eltype(promote(pb, 1)) == typeof(pb)
        @test eltype(promote(pb, 2.0)) == typeof(pb)
        @test eltype(promote(pb, π)) == typeof(pb)
        @test eltype(promote(pb, 1, 2.0, π)) == typeof(pb)
        @test eltype(promote(pb, db)) == Float64
        @test promote_rule(eltype(pb), Integer) == typeof(pb)
        @test promote_rule(eltype(pb), Float64) == typeof(pb)
        @test promote_rule(eltype(pb), Irrational) == typeof(pb)
        @test promote_rule(eltype(pb), eltype(db)) == Float64

        @test typeof(pb + 1) == typeof(pb) # check that promotion works

        @test convert(Float64, pb) == pb.value
        @test convert(Integer, pb) == pb.value
        @test convert(Irrational, pb) == pb.value
        @test convert(ClB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, 4.0) == ClB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}(4.0)
        @test convert(ClB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, 4) == ClB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}(4)
        @test convert(ClB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, π) == ClB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}(π)
        
        pb_plus_1 = ClB.Bound{Primal,MaxSense}(5.0)

        @test -pb == ClB.Bound{Primal,MaxSense}(-4.0)
        @test pb + pb == 8
        @test pb - pb == 0
        @test pb * pb == 16
        @test pb / pb == 1
        @test pb == pb
        @test pb < pb_plus_1
        @test pb <= pb
        @test pb >= pb
        @test pb_plus_1 > pb
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

        db = ClB.Bound{Dual,MaxSense}(2.5)
        # In a given sense, promotion of pb & a db gives a float
        @test eltype(promote(pb, db)) == Float64

        # Promotion between two bounds of different senses does not work
        pb1 = ClB.Bound{Primal,MaxSense}(2.5)
        pb2 = ClB.Bound{Primal,MinSense}(2.5)
        @test_throws ErrorException promote(pb1, pb2)

        db1 = ClB.Bound{Dual,MaxSense}(2.5)
        db2 = ClB.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(db1, db2)

        pb = ClB.Bound{Primal,MaxSense}(2.5)
        db = ClB.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(pb, db)
    end
end

@testset "ColunaBase - MOI <-> Coluna Termination Status" begin
    statuses_bijection = [
        (MOI.OPTIMIZE_NOT_CALLED, ClB.OPTIMIZE_NOT_CALLED),
        (MOI.OPTIMAL, ClB.OPTIMAL),
        (MOI.INFEASIBLE, ClB.INFEASIBLE),
        (MOI.DUAL_INFEASIBLE, ClB.DUAL_INFEASIBLE),
        (MOI.INFEASIBLE_OR_UNBOUNDED, ClB.INFEASIBLE_OR_UNBOUNDED),
        (MOI.TIME_LIMIT, ClB.TIME_LIMIT),
        (MOI.NODE_LIMIT, ClB.NODE_LIMIT),
        (MOI.OTHER_LIMIT, ClB.OTHER_LIMIT),
    ]

    statuses_surjection = [
        (MOI.ALMOST_OPTIMAL, ClB.UNCOVERED_TERMINATION_STATUS),
        (MOI.SLOW_PROGRESS, ClB.UNCOVERED_TERMINATION_STATUS),
        (MOI.MEMORY_LIMIT, ClB.UNCOVERED_TERMINATION_STATUS),
        (MOI.ALMOST_OPTIMAL, ClB.UNCOVERED_TERMINATION_STATUS)
    ]

    for (moi_status, coluna_status) in statuses_bijection
        @test ClB.convert_status(moi_status) == coluna_status
        @test ClB.convert_status(coluna_status) == moi_status
    end

    for (moi_status, coluna_status) in statuses_surjection
        @test ClB.convert_status(moi_status) == coluna_status
        @test ClB.convert_status(coluna_status) == MOI.OTHER_LIMIT
    end
end

@testset "ColunaBase - MOI Result Status Code" begin
    @test ClB.convert_status(MOI.NO_SOLUTION) == ClB.UNKNOWN_SOLUTION_STATUS
    @test ClB.convert_status(MOI.FEASIBLE_POINT) == ClB.FEASIBLE_SOL
    @test ClB.convert_status(MOI.INFEASIBLE_POINT) == ClB.INFEASIBLE_SOL
    @test ClB.convert_status(MOI.NEARLY_FEASIBLE_POINT) == ClB.UNCOVERED_SOLUTION_STATUS 
end

@testset "ColunaBase - Coluna Solution Status" begin
    @test ClB.convert_status(ClB.FEASIBLE_SOL) == MOI.FEASIBLE_POINT
    @test ClB.convert_status(ClB.INFEASIBLE_SOL) == MOI.INFEASIBLE_POINT
    @test ClB.convert_status(ClB.UNCOVERED_SOLUTION_STATUS) == MOI.OTHER_RESULT_STATUS
end

function solution_factory(nbdecisions)
    decisions = Set{Int}()
    i = 0
    while i < nbdecisions
        v = rand(rng, 1:100)
        if v ∉ decisions
            push!(decisions, v)
            i += 1
        end
    end
    dict = Dict{Int, Float64}()
    soldecisions = Vector{Int}()
    solvals = Vector{Float64}()
    for d in decisions
        val = rand(rng, 0:0.0001:1000)
        dict[d] = val
        push!(soldecisions, d)
        push!(solvals, val)
    end
    return dict, soldecisions, solvals
end

function test_solution_iterations(solution::ClB.Solution, dict::Dict)
    prev_decision = nothing
    for (decision, value) in solution
        if prev_decision !== nothing
            @test prev_decision < decision
        end
        @test solution[decision] == dict[decision]
        solution[decision] += 1
        @test solution[decision] == dict[decision] + 1
    end
    return
end

@testset "ColunaBase - Solution" begin
    @testset "constructor, iterate, and print" begin
        model = FakeModel()

        dict_sol, soldecs, solvals = solution_factory(100)
        primal_sol = Solution(model, soldecs, solvals, 12.3, ClB.FEASIBLE_SOL)
        test_solution_iterations(primal_sol, dict_sol)
        @test ClB.getvalue(primal_sol) == 12.3
        @test ClB.getstatus(primal_sol) == ClB.FEASIBLE_SOL
        
        dict_sol = Dict(1 => 2.0, 2 => 3.0, 3 => 4.0)
        primal_sol = Solution(model, collect(keys(dict_sol)), collect(values(dict_sol)), 0.0, ClB.FEASIBLE_SOL)
        
        @test length(primal_sol) == typemax(Coluna.MAX_NB_ELEMS)
        @test nnz(primal_sol) == 3
        @test primal_sol[1] == 2.0
        primal_sol[1] = 5.0 # change the value
        @test primal_sol[1] == 5.0
        
        io = IOBuffer()
        show(io, primal_sol)

        @test String(take!(io)) == "Solution\n| 1 = 5.0\n| 2 = 3.0\n| 3 = 4.0\n└ value = 0.00 \n"
    end

    @testset "isequal" begin
        model = FakeModel()
        model2 = FakeModel(2)

        dict_sol = Dict(1 => 2.0, 2 => 5.0, 3 => 8.0, 9 => 15.0)
        dict_sol2 = Dict(1 => 2.0, 2 => 5.0, 3 => 7.0, 9 => 15.0) # key 3 has different value
        dict_sol3 = Dict(1 => 2.0, 2 => 5.0, 3 => 8.0, 9 => 15.0, 10 => 11.0) # new key 10
        dict_sol4 = Dict(1 => 2.0, 2 => 5.0, 3 => 8.0) # missing key 9

        sol1 = Solution(model, collect(keys(dict_sol)), collect(values(dict_sol)), 12.0, ClB.FEASIBLE_SOL)
        sol2 = Solution(model, collect(keys(dict_sol)), collect(values(dict_sol)), 12.0, ClB.FEASIBLE_SOL)
        sol3 = Solution(model, collect(keys(dict_sol)), collect(values(dict_sol)), 15.0, ClB.FEASIBLE_SOL)
        sol4 = Solution(model, collect(keys(dict_sol)), collect(values(dict_sol)), 12.0, ClB.INFEASIBLE_SOL)
        sol5 = Solution(model2, collect(keys(dict_sol)), collect(values(dict_sol)), 12.0, ClB.FEASIBLE_SOL)
        sol6 = Solution(model, collect(keys(dict_sol2)), collect(values(dict_sol2)), 12.0, ClB.FEASIBLE_SOL)
        sol7 = Solution(model, collect(keys(dict_sol3)), collect(values(dict_sol3)), 12.0, ClB.FEASIBLE_SOL)
        sol8 = Solution(model, collect(keys(dict_sol4)), collect(values(dict_sol4)), 12.0, ClB.FEASIBLE_SOL)
        
        @test sol1 == sol2
        @test sol1 != sol3 # different cost
        @test sol1 != sol4 # different solution status
        @test sol1 != sol5 # different model
        @test sol1 != sol6 # different solution
        @test sol1 != sol7
        @test sol1 != sol8
    end
end

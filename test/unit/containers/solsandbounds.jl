Primal = Coluna.AbstractPrimalSpace
Dual = Coluna.AbstractDualSpace
MinSense = Coluna.AbstractMinSense
MaxSense = Coluna.AbstractMaxSense

CB = Coluna.ColunaBase

struct FakeModel <: CB.AbstractModel end

function bound_unit()
    @testset "Bound" begin
        # Make sure that Coluna initializes bounds to infinity.
        # Check that initial value of the bound is correct.
        pb = CB.Bound{Primal,MinSense}()
        @test pb == Inf
        @test CB.getvalue(pb) == Inf
        
        pb = CB.Bound{Primal,MaxSense}()
        @test pb == -Inf
        @test CB.getvalue(pb) == -Inf
        
        db = CB.Bound{Dual,MinSense}()
        @test db == -Inf
        @test CB.getvalue(db) == -Inf
        
        db = CB.Bound{Dual,MaxSense}()
        @test db == Inf
        @test CB.getvalue(db) == Inf
        
        pb = CB.Bound{Primal,MinSense}(100)
        @test pb == 100
        @test CB.getvalue(pb) == 100
        @test typeof(float(db)) <: Float64

        db = CB.Bound{Dual,MinSense}(-π)
        @test db == -π
        @test CB.getvalue(db) == -π
    end

    @testset "isbetter" begin
        # In minimization, pb with value 10 is better than pb with value 15
        pb1 = CB.Bound{Primal,MinSense}(10.0)
        pb2 = CB.Bound{Primal,MinSense}(15.0)
        @test CB.isbetter(pb1, pb2) == !CB.isbetter(pb2, pb1) == true

        # In maximization, pb with value 15 is better than pb with value 10
        pb1 = CB.Bound{Primal,MaxSense}(10.0)
        pb2 = CB.Bound{Primal,MaxSense}(15.0)
        @test CB.isbetter(pb2, pb1) == !CB.isbetter(pb1, pb2) == true

        # In minimization, db with value 15 is better than db with value 10
        db1 = CB.Bound{Dual,MinSense}(15.0)
        db2 = CB.Bound{Dual,MinSense}(10.0)
        @test CB.isbetter(db1, db2) == !CB.isbetter(db2, db1) == true

        # In maximization, db with value 10 is better than db with value 15
        db1 = CB.Bound{Dual,MaxSense}(15.0)
        db2 = CB.Bound{Dual,MaxSense}(10.0)
        @test CB.isbetter(db2, db1) == !CB.isbetter(db1, db2) == true

        # Cannot compare a primal & a dual bound
        db1 = CB.Bound{Dual,MaxSense}(-10.0)
        @test_throws MethodError CB.isbetter(db1, pb1)

        # Cannot compare a bound from maximization & a bound from minimization
        db2 = CB.Bound{Dual,MinSense}(10.0)
        @test_throws MethodError CB.isbetter(db1, db2)
    end

    @testset "diff" begin
        # Compute distance between primal bound and dual bound
        # In minimization, if pb = 10 & db = 5, distance is 5
        pb = CB.Bound{Primal,MinSense}(10)
        db = CB.Bound{Dual,MinSense}(5)
        @test CB.diff(pb, db) == CB.diff(db, pb) == 5

        # In maximisation if pb = 10 & db = 5, distance is -5
        pb = CB.Bound{Primal,MaxSense}(10)
        db = CB.Bound{Dual,MaxSense}(5)
        @test CB.diff(pb, db) == CB.diff(db, pb) == -5

        # Cannot compute the distance between two primal bounds
        pb1 = CB.Bound{Primal,MaxSense}(10)
        pb2 = CB.Bound{Primal,MaxSense}(15)
        @test_throws MethodError CB.diff(pb1, pb2)

        # Cannot compute the distance between two dual bounds
        db1 = CB.Bound{Dual,MaxSense}(5)
        db2 = CB.Bound{Dual,MaxSense}(50)
        @test_throws MethodError CB.diff(db1, db2)

        # Cannot compute the distance between two bounds from different sense
        pb = CB.Bound{Primal,MaxSense}(10)
        db = CB.Bound{Dual,MinSense}(5)
        @test_throws MethodError CB.diff(pb, db)
    end

    @testset "gap" begin
        # In minimisation, gap = (pb - db)/db
        pb = CB.Bound{Primal,MinSense}(10.0)
        db = CB.Bound{Dual,MinSense}(5.0)
        @test CB.gap(pb, db) == CB.gap(db, pb) == (10.0-5.0)/5.0
    
        # In maximisation, gap = (db - pb)/pb
        pb = CB.Bound{Primal,MaxSense}(5.0)
        db = CB.Bound{Dual,MaxSense}(10.0)
        @test CB.gap(pb, db) == CB.gap(db, pb) == (10.0-5.0)/5.0
    
        pb = CB.Bound{Primal,MinSense}(10.0)
        db = CB.Bound{Dual,MinSense}(-5.0)
        @test CB.gap(pb, db) == CB.gap(db, pb) == (10.0+5.0)/5.0   

        # Cannot compute the gap between 2 primal bounds
        pb1 = CB.Bound{Primal,MaxSense}(10)
        pb2 = CB.Bound{Primal,MaxSense}(15)
        @test_throws MethodError CB.gap(pb1, pb2)

        # Cannot compute the gap between 2 dual bounds
        db1 = CB.Bound{Dual,MaxSense}(5)
        db2 = CB.Bound{Dual,MaxSense}(50)
        @test_throws MethodError CB.gap(db1, db2)

        # Cannot compute the gap between 2 bounds with different sense
        pb = CB.Bound{Primal,MaxSense}(10)
        db = CB.Bound{Dual,MinSense}(5)
        @test_throws MethodError CB.gap(pb, db)
    end

    @testset "printbounds" begin
        # In minimisation sense
        pb1 = CB.Bound{Primal, MinSense}(100)
        db1 = CB.Bound{Dual, MinSense}(-100)
        io = IOBuffer()
        CB.printbounds(db1, pb1, io)
        @test String(take!(io)) == "[ -100.0000 , 100.0000 ]"

        # In maximisation sense
        pb2 = CB.Bound{Primal, MaxSense}(-100)
        db2 = CB.Bound{Dual, MaxSense}(100)
        io = IOBuffer()
        CB.printbounds(db2, pb2, io)
        @test String(take!(io)) == "[ -100.0000 , 100.0000 ]"
    end

    @testset "show" begin
        pb = CB.Bound{Primal,MaxSense}(4)
        io = IOBuffer()
        show(io, pb)
        @test String(take!(io)) == "4.0" 
    end

    @testset "Promotions & conversions" begin
        pb = CB.Bound{Primal,MaxSense}(4.0)
        db = CB.Bound{Dual,MaxSense}(2.0)
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
        @test convert(CB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, 4.0) == CB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}(4.0)
        @test convert(CB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, 4) == CB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}(4)
        @test convert(CB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, π) == CB.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}(π)
        
        pb_plus_1 = CB.Bound{Primal,MaxSense}(5.0)

        @test -pb == CB.Bound{Primal,MaxSense}(-4.0)
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

        db = CB.Bound{Dual,MaxSense}(2.5)
        # In a given sense, promotion of pb & a db gives a float
        @test eltype(promote(pb, db)) == Float64

        # Promotion between two bounds of different senses does not work
        pb1 = CB.Bound{Primal,MaxSense}(2.5)
        pb2 = CB.Bound{Primal,MinSense}(2.5)
        @test_throws ErrorException promote(pb1, pb2)

        db1 = CB.Bound{Dual,MaxSense}(2.5)
        db2 = CB.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(db1, db2)

        pb = CB.Bound{Primal,MaxSense}(2.5)
        db = CB.Bound{Dual,MinSense}(2.5)
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

function test_solution_iterations(solution::CB.Solution, dict::Dict)
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

function solution_unit()
    @testset "MOI Termination Status" begin
        @test CB.convert_status(MOI.OPTIMAL) == CB.OPTIMAL
        @test CB.convert_status(MOI.INFEASIBLE) == CB.INFEASIBLE
        @test CB.convert_status(MOI.TIME_LIMIT) == CB.TIME_LIMIT
        @test CB.convert_status(MOI.NODE_LIMIT) == CB.NODE_LIMIT
        @test CB.convert_status(MOI.OTHER_LIMIT) == CB.OTHER_LIMIT
        @test CB.convert_status(MOI.MEMORY_LIMIT) == CB.UNCOVERED_TERMINATION_STATUS
    end

    @testset "Coluna Termination Status" begin
        @test CB.convert_status(CB.OPTIMAL) == MOI.OPTIMAL
        @test CB.convert_status(CB.INFEASIBLE) == MOI.INFEASIBLE
        @test CB.convert_status(CB.TIME_LIMIT) == MOI.TIME_LIMIT
        @test CB.convert_status(CB.NODE_LIMIT) == MOI.NODE_LIMIT
        @test CB.convert_status(CB.OTHER_LIMIT) == MOI.OTHER_LIMIT
        @test CB.convert_status(CB.UNCOVERED_TERMINATION_STATUS) == MOI.OTHER_LIMIT
    end

    @testset "MOI Result Status Code" begin
        @test CB.convert_status(MOI.NO_SOLUTION) == CB.UNKNOWN_SOLUTION_STATUS
        @test CB.convert_status(MOI.FEASIBLE_POINT) == CB.FEASIBLE_SOL
        @test CB.convert_status(MOI.INFEASIBLE_POINT) == CB.INFEASIBLE_SOL
        @test CB.convert_status(MOI.NEARLY_FEASIBLE_POINT) == CB.UNCOVERED_SOLUTION_STATUS 
    end

    @testset "Coluna Solution Status" begin
        @test CB.convert_status(CB.FEASIBLE_SOL) == MOI.FEASIBLE_POINT
        @test CB.convert_status(CB.INFEASIBLE_SOL) == MOI.INFEASIBLE_POINT
        @test CB.convert_status(CB.UNCOVERED_SOLUTION_STATUS) == MOI.OTHER_RESULT_STATUS
    end

    @testset "Solution" begin
        model = FakeModel()

        Solution = CB.Solution{FakeModel,Int,Float64}

        dict_sol, soldecs, solvals = fake_solution_factory(100)
        primal_sol = Solution(model, soldecs, solvals, 12.3, CB.FEASIBLE_SOL)
        test_solution_iterations(primal_sol, dict_sol)
        @test CB.getvalue(primal_sol) == 12.3
        @test CB.getstatus(primal_sol) == CB.FEASIBLE_SOL
        
        dict_sol = Dict(1 => 2.0, 2 => 3.0, 3 => 4.0)
        primal_sol = Solution(model, collect(keys(dict_sol)), collect(values(dict_sol)), 0.0, Coluna.ColunaBase.FEASIBLE_SOL)
        
        @test iterate(primal_sol) == iterate(primal_sol.sol)
        _, state = iterate(primal_sol)
        @test iterate(primal_sol, state) == iterate(primal_sol.sol, state)
        @test length(primal_sol) == 3
        @test primal_sol[1] == 2.0
        primal_sol[1] = 5.0 # change the value
        @test primal_sol[1] == 5.0
        
        io = IOBuffer()
        show(io, primal_sol)

        @test String(take!(io)) == "Solution\n| 1 = 5.0\n| 2 = 3.0\n| 3 = 4.0\n└ value = 0.00 \n"
    end

    @testset "Solution isless" begin
        # MinSense
        form = create_formulation!(Env(Coluna.Params()), Original())
        var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
        constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
        
        primalsol1 = PrimalSolution(form, [getid(var)], [0.0], 1.0, CB.UNKNOWN_FEASIBILITY)
        primalsol2 = PrimalSolution(form, [getid(var)], [1.0], 0.0, CB.UNKNOWN_FEASIBILITY)
        @test isless(primalsol1, primalsol2) # primalsol1 is worse than primalsol2 for min sense

        dualsol1 = DualSolution(form, [getid(constr)], [0.0], 1.0, CB.UNKNOWN_FEASIBILITY)
        dualsol2 = DualSolution(form, [getid(constr)], [1.0], 0.0, CB.UNKNOWN_FEASIBILITY)
        @test isless(dualsol2, dualsol1) # dualsol2 is worse than dualsol1 for min sense

        # MaxSense
        form = create_formulation!(
            Env(Coluna.Params()), Original(), obj_sense = Coluna.MathProg.MaxSense
        )
        var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
        constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)

        primalsol1 = PrimalSolution(form, [getid(var)], [0.0], 1.0, CB.UNKNOWN_FEASIBILITY)
        primalsol2 = PrimalSolution(form, [getid(var)], [1.0], 0.0, CB.UNKNOWN_FEASIBILITY)
        @test isless(primalsol2, primalsol1) # primalsol2 is worse than primalsol1 for max sense

        dualsol1 = DualSolution(form, [getid(constr)], [0.0], 1.0, CB.UNKNOWN_FEASIBILITY)
        dualsol2 = DualSolution(form, [getid(constr)], [1.0], 0.0, CB.UNKNOWN_FEASIBILITY)
        @test isless(dualsol1, dualsol2) # dualsol1 is worse than dualsol2 for max sense
    end
    return
end
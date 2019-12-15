function solsandbounds_unit_tests()
    bounds_constructors_and_getters_tests()
    bounds_isbetter_tests()
    bounds_diff_tests()
    bounds_gap_tests()
    bounds_base_functions_tests()
    solution_constructors_and_getters_and_setters_tests()
    solution_base_functions_tests()
end

function bounds_constructors_and_getters_tests()

    pb = ClF.PrimalBound{ClF.MinSense}()
    @test ClF.getvalue(pb) == Inf
    pb = ClF.PrimalBound{ClF.MaxSense}()
    @test ClF.getvalue(pb) == -Inf

    db = ClF.DualBound{ClF.MinSense}()
    @test ClF.getvalue(db) == -Inf
    db = ClF.DualBound{ClF.MaxSense}()
    @test ClF.getvalue(db) == +Inf

    db = ClF.DualBound{ClF.MinSense}(10)
    @test ClF.getvalue(db) == 10.0
    pb = ClF.PrimalBound{ClF.MinSense}(-13.02)
    @test ClF.getvalue(pb) == -13.02

end

function bounds_isbetter_tests()

    pb1 = ClF.PrimalBound{ClF.MinSense}(10.0)
    pb2 = ClF.PrimalBound{ClF.MinSense}(15.0)
    @test ClF.isbetter(pb1, pb2) == !ClF.isbetter(pb2, pb1) == true

    pb1 = ClF.PrimalBound{ClF.MaxSense}(10.0)
    pb2 = ClF.PrimalBound{ClF.MaxSense}(15.0)
    @test ClF.isbetter(pb1, pb2) == !ClF.isbetter(pb2, pb1) == false

end

function bounds_diff_tests()

    pb = ClF.PrimalBound{ClF.MinSense}(10.0)
    db = ClF.DualBound{ClF.MinSense}(5.0)
    @test ClF.diff(pb, db) == ClF.diff(db, pb) == 5.0

    pb = ClF.PrimalBound{ClF.MaxSense}(10.0)
    db = ClF.DualBound{ClF.MaxSense}(5.0)
    @test ClF.diff(pb, db) == ClF.diff(db, pb) == -5.0

end

function bounds_gap_tests()

    pb = ClF.PrimalBound{ClF.MinSense}(10.0)
    db = ClF.DualBound{ClF.MinSense}(5.0)
    @test ClF.gap(pb, db) == ClF.gap(db, pb) == (10.0-5.0)/5.0

    pb = ClF.PrimalBound{ClF.MaxSense}(5.0)
    db = ClF.DualBound{ClF.MaxSense}(10.0)
    @test ClF.gap(pb, db) == ClF.gap(db, pb) == (10.0-5.0)/5.0

    pb = ClF.PrimalBound{ClF.MinSense}(10.0)
    db = ClF.DualBound{ClF.MinSense}(-5.0)
    @test ClF.gap(pb, db) == ClF.gap(db, pb) == (10.0+5.0)/5.0

end

function bounds_base_functions_tests()

    pb1 = ClF.PrimalBound{ClF.MinSense}(10.0)
    pb2 = ClF.PrimalBound{ClF.MinSense}(12.0)

    @test ClF.Base.promote_rule(ClF.PrimalBound{ClF.MinSense}, Float64) == ClF.PrimalBound{ClF.MinSense}
    @test ClF.Base.convert(Float64, pb1) == 10.0
    @test ClF.Base.convert(ClF.PrimalBound{ClF.MinSense}, 10.0) === pb1
    @test pb1 * pb2 == ClF.PrimalBound{ClF.MinSense}(120.0)
    @test pb1 - pb2 == ClF.PrimalBound{ClF.MinSense}(-2.0)
    @test pb1 + pb2 == ClF.PrimalBound{ClF.MinSense}(22.0)
    @test pb2 / pb1 == ClF.PrimalBound{ClF.MinSense}(1.2)
    @test ClF.Base.isless(pb1, 20.0) == true
    @test ClF.Base.isless(pb2, pb1) == false

end

function solution_constructors_and_getters_and_setters_tests()
    counter = ClF.Counter()
    f1 = ClF.Formulation{ClF.Original}(counter, obj_sense = ClF.MinSense) 
    primal_sol = ClF.PrimalSolution(f1)

    f2 = ClF.Formulation{ClF.Original}(counter, obj_sense = ClF.MaxSense)
    dual_sol = ClF.DualSolution(f2)

    @test ClF.getbound(primal_sol) == ClF.PrimalBound{ClF.MinSense}(Inf)
    @test ClF.getvalue(primal_sol) == Inf
    @test ClF.getsol(primal_sol) == Dict{ClF.Id{ClF.Variable},Float64}()

    @test ClF.getbound(dual_sol) == ClF.DualBound{ClF.MaxSense}(Inf)
    @test ClF.getvalue(dual_sol) == Inf
    @test ClF.getsol(dual_sol) == Dict{ClF.Id{ClF.Constraint},Float64}()

    primal_sol = ClF.PrimalSolution(f1, -12.0, Dict{ClF.Id{ClF.Variable},Float64}())
    dual_sol = ClF.DualSolution(f2, -13.0, Dict{ClF.Id{ClF.Constraint},Float64}())

    @test ClF.getbound(primal_sol) == ClF.PrimalBound{ClF.MinSense}(-12.0)
    @test ClF.getvalue(primal_sol) == -12.0
    @test ClF.getsol(primal_sol) == Dict{ClF.Id{ClF.Variable},Float64}()

    @test ClF.getbound(dual_sol) == ClF.DualBound{ClF.MaxSense}(-13.0)
    @test ClF.getvalue(dual_sol) == -13.0
    @test ClF.getsol(dual_sol) == Dict{ClF.Id{ClF.Constraint},Float64}()

end

function solution_base_functions_tests()

    sol = Dict{ClF.Id{ClF.Variable},Float64}()
    sol[ClF.Id{ClF.Variable}(1, 10)] = 1.0
    sol[ClF.Id{ClF.Variable}(2, 10)] = 2.0
    
    counter = ClF.Counter()
    f = ClF.Formulation{ClF.Original}(counter, obj_sense = ClF.MinSense) 
    primal_sol = ClF.PrimalSolution(f, ClF.PrimalBound{ClF.MinSense}(3.0), sol)
    
    copy_sol = ClF.Base.copy(primal_sol)
    @test copy_sol.bound === primal_sol.bound
    @test copy_sol.sol == primal_sol.sol

    @test ClF.Base.length(primal_sol) == 2
    for (v, val) in primal_sol
        @test typeof(v) <: ClF.Id
        @test typeof(val) == Float64
    end

end

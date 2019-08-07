function solsandbounds_unit_tests()
    bounds_constructors_and_getters_tests()
    bounds_isbetter_tests()
    bounds_absolutegap_tests()
    bounds_relativegap_tests()
    bounds_base_functions_tests()
    solution_constructors_and_getters_and_setters_tests()
    solution_base_functions_tests()
end

function bounds_constructors_and_getters_tests()

    pb = CL.PrimalBound{CL.MinSense}()
    @test CL.getvalue(pb) == Inf
    pb = CL.PrimalBound{CL.MaxSense}()
    @test CL.getvalue(pb) == -Inf

    db = CL.DualBound{CL.MinSense}()
    @test CL.getvalue(db) == -Inf
    db = CL.DualBound{CL.MaxSense}()
    @test CL.getvalue(db) == +Inf

    db = CL.DualBound{CL.MinSense}(10)
    @test CL.getvalue(db) == 10.0
    pb = CL.PrimalBound{CL.MinSense}(-13.02)
    @test CL.getvalue(pb) == -13.02

end

function bounds_isbetter_tests()

    pb1 = CL.PrimalBound{CL.MinSense}(10.0)
    pb2 = CL.PrimalBound{CL.MinSense}(15.0)
    @test CL.isbetter(pb1, pb2) == !CL.isbetter(pb2, pb1) == true

    pb1 = CL.PrimalBound{CL.MaxSense}(10.0)
    pb2 = CL.PrimalBound{CL.MaxSense}(15.0)
    @test CL.isbetter(pb1, pb2) == !CL.isbetter(pb2, pb1) == false

end

function bounds_absolutegap_tests()

    pb = CL.PrimalBound{CL.MinSense}(10.0)
    db = CL.DualBound{CL.MinSense}(5.0)
    @test CL.absolutegap(pb, db) == CL.absolutegap(db, pb) == 5.0

    pb = CL.PrimalBound{CL.MaxSense}(10.0)
    db = CL.DualBound{CL.MaxSense}(5.0)
    @test CL.absolutegap(pb, db) == CL.absolutegap(db, pb) == -5.0

end

function bounds_relativegap_tests()

    pb = CL.PrimalBound{CL.MinSense}(10.0)
    db = CL.DualBound{CL.MinSense}(5.0)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == (10.0-5.0)/5.0

    pb = CL.PrimalBound{CL.MaxSense}(5.0)
    db = CL.DualBound{CL.MaxSense}(10.0)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == (10.0-5.0)/5.0

    pb = CL.PrimalBound{CL.MinSense}(0.0)
    db = CL.DualBound{CL.MinSense}(0.0)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == 0.0

    pb = CL.PrimalBound{CL.MinSense}(1.0)
    db = CL.DualBound{CL.MinSense}(1.0)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == 0.0

    pb = CL.PrimalBound{CL.MinSense}(Inf)
    db = CL.DualBound{CL.MinSense}(-Inf)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == Inf

    pb = CL.PrimalBound{CL.MinSense}(Inf)
    db = CL.DualBound{CL.MinSense}(Inf)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == Inf

    pb = CL.PrimalBound{CL.MinSense}(Inf)
    db = CL.DualBound{CL.MinSense}(-2)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == Inf

    pb = CL.PrimalBound{CL.MinSense}(12)
    db = CL.DualBound{CL.MinSense}(-Inf)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == Inf

    pb = CL.PrimalBound{CL.MinSense}(-2)
    db = CL.DualBound{CL.MinSense}(-Inf)
    @test CL.relativegap(pb, db) == CL.relativegap(db, pb) == Inf

end

function bounds_base_functions_tests()

    pb1 = CL.PrimalBound{CL.MinSense}(10.0)
    pb2 = CL.PrimalBound{CL.MinSense}(12.0)

    @test CL.Base.promote_rule(CL.PrimalBound{CL.MinSense}, Float64) == CL.PrimalBound{CL.MinSense}
    @test CL.Base.convert(Float64, pb1) == 10.0
    @test CL.Base.convert(CL.PrimalBound{CL.MinSense}, 10.0) === pb1
    @test pb1 * pb2 == CL.PrimalBound{CL.MinSense}(120.0)
    @test pb1 - pb2 == CL.PrimalBound{CL.MinSense}(-2.0)
    @test pb1 + pb2 == CL.PrimalBound{CL.MinSense}(22.0)
    @test pb2 / pb1 == CL.PrimalBound{CL.MinSense}(1.2)
    @test CL.Base.isless(pb1, 20.0) == true
    @test CL.Base.isless(pb2, pb1) == false

end

function solution_constructors_and_getters_and_setters_tests()
    counter = CL.Counter()
    f1 = CL.Formulation{CL.Original}(counter, obj_sense = CL.MinSense) 
    primal_sol = CL.PrimalSolution(f1)

    f2 = CL.Formulation{CL.Original}(counter, obj_sense = CL.MaxSense)
    dual_sol = CL.DualSolution(f2)

    @test CL.getbound(primal_sol) == CL.PrimalBound{CL.MinSense}(Inf)
    @test CL.getvalue(primal_sol) == Inf
    @test CL.getsol(primal_sol) == Dict{CL.Id{CL.Variable},Float64}()

    @test CL.getbound(dual_sol) == CL.DualBound{CL.MaxSense}(Inf)
    @test CL.getvalue(dual_sol) == Inf
    @test CL.getsol(dual_sol) == Dict{CL.Id{CL.Constraint},Float64}()

    primal_sol = CL.PrimalSolution(f1, -12.0, Dict{CL.Id{CL.Variable},Float64}())
    dual_sol = CL.DualSolution(f2, -13.0, Dict{CL.Id{CL.Constraint},Float64}())

    @test CL.getbound(primal_sol) == CL.PrimalBound{CL.MinSense}(-12.0)
    @test CL.getvalue(primal_sol) == -12.0
    @test CL.getsol(primal_sol) == Dict{CL.Id{CL.Variable},Float64}()

    @test CL.getbound(dual_sol) == CL.DualBound{CL.MaxSense}(-13.0)
    @test CL.getvalue(dual_sol) == -13.0
    @test CL.getsol(dual_sol) == Dict{CL.Id{CL.Constraint},Float64}()

end

function solution_base_functions_tests()

    sol = Dict{CL.Id{CL.Variable},Float64}()
    sol[CL.Id{CL.Variable}(1, 10)] = 1.0
    sol[CL.Id{CL.Variable}(2, 10)] = 2.0
    
    counter = CL.Counter()
    f = CL.Formulation{CL.Original}(counter, obj_sense = CL.MinSense) 
    primal_sol = CL.PrimalSolution(f, CL.PrimalBound{CL.MinSense}(3.0), sol)
    
    copy_sol = CL.Base.copy(primal_sol)
    @test copy_sol.bound === primal_sol.bound
    @test copy_sol.sol == primal_sol.sol

    @test CL.Base.length(primal_sol) == 2
    for (v, val) in primal_sol
        @test typeof(v) <: CL.Id
        @test typeof(val) == Float64
    end

end

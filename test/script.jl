using Coluna

using Cbc
using MathOptInterface, MathOptInterface.Utilities

const MOIU = MathOptInterface.Utilities
const MOI = MathOptInterface
const CL = Coluna

function testdefaultbuilders()

    useroptimizer = CbcOptimizer()
    ## Problem builder
    problem = CL.Problem{CL.SimpleVarIndexManager,CL.SimpleConstrIndexManager}(useroptimizer)
    x1 = CL.VarConstr(problem, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0)
    x2 = CL.VarConstr(x1)
    x3 = CL.Variable(problem, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0)
    x4 = CL.Variable(x3)
    x5 = CL.SubProbVar(problem, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0, problem, -Inf, Inf, -Inf, Inf)
    x6 = CL.MasterVar(problem, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0)
    x7 = CL.MasterVar(x3)
    x7 = CL.MasterVar(x6)

    constr1 = CL.Constraint(problem, "knapConstr", 5.0, 'L', 'M', 's')
    constr2 = CL.MasterConstr(problem, "knapConstr", 5.0, 'L', 'M', 's')

end

function testpuremaster()
    useroptimizer = CbcOptimizer()

    problem = CL.SimpleProblem(useroptimizer)

    x1 = CL.MasterVar(problem, "x1", -10.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x2 = CL.MasterVar(problem, "x2", -15.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x3 = CL.MasterVar(problem, "x3", -20.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)

    CL.addvariable(problem, x1)
    CL.addvariable(problem, x2)
    CL.addvariable(problem, x3)

    constr = CL.MasterConstr(problem, "knapConstr", 5.0, 'L', 'M', 's')

    CL.addconstraint(problem, constr)

    CL.addmembership(x1, constr, 2.0)
    CL.addmembership(x2, constr, 3.0)
    CL.addmembership(x3, constr, 4.0)

    CL.optimize(problem)
end

testdefaultbuilders()
testpuremaster()
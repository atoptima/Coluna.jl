import Coluna
using Base.Test

import Cbc
import MathOptInterface, MathOptInterface.Utilities

const MOIU = MathOptInterface.Utilities
const MOI = MathOptInterface
const CL = Coluna

include("colgenroot.jl")
include("branching.jl")

function testdefaultbuilders()

    user_optimizer = Cbc.CbcOptimizer()
    ## Problem builder
    counter = CL.VarConstrCounter(0)
    problem = CL.SimpleCompactProblem(user_optimizer, counter)
    x1 = CL.VarConstr(problem.counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0)
    x2 = CL.VarConstr(x1, problem.counter)
    x3 = CL.Variable(problem.counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0)
    x4 = CL.Variable(x3, problem.counter)
    x5 = CL.SubprobVar(problem.counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0,
                       -Inf, Inf, -Inf, Inf)
    x6 = CL.MasterVar(problem.counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0)
    x7 = CL.MasterVar(x3, problem.counter)
    x7 = CL.MasterVar(x6, problem.counter)

    constr1 = CL.Constraint(problem.counter, "knapConstr", 5.0, 'L', 'M', 's')
    constr2 = CL.MasterConstr(problem.counter, "knapConstr", 5.0, 'L', 'M', 's')


    ### Model constructors
    params = CL.Params()
    counter = CL.VarConstrCounter(0)
    masteroptimizer = Cbc.CbcOptimizer()
    master_problem = CL.SimpleCompactProblem(masteroptimizer, counter)
    pricingoptimizer = Cbc.CbcOptimizer()
    pricing_probs = Vector{CL.Problem}()
    push!(pricing_probs, CL.SimpleCompactProblem(pricingoptimizer, counter))
    callback = CL.Callback()
    extended_problem = CL.ExtendedProblemConstructor(master_problem,
        pricing_probs, CL.Problem[], counter, params, params.cut_up, params.cut_lo)
    model = CL.ModelConstructor(extended_problem, callback, params)


    ### Algorithms constructors
    alg_setup_node = CL.AlgToSetupNode(extended_problem,
        CL.ProblemSetupInfo(0), false)
    alg_preprocess_node = CL.AlgToPreprocessNode()
    alg_eval_node = CL.AlgToEvalNode()
    alg_setdown_node = CL.AlgToSetdownNode(extended_problem)
    alg_vect_primal_heur_node = CL.AlgToPrimalHeurInNode[]
    alg_generate_children_nodes = CL.AlgToGenerateChildrenNodes(CL.MostFractionalRule(), 2)


    ### Node constructors
    rootNode = CL.Node(model, params.cut_lo, CL.ProblemSetupInfo(0), CL.EvalInfo())
    rootNode = CL.Node(model, params.cut_lo, CL.ProblemSetupInfo(0), CL.EvalInfo(),
        alg_setup_node, alg_preprocess_node, alg_eval_node, alg_setdown_node,
        alg_vect_primal_heur_node, alg_generate_children_nodes)

    chhild1 = CL.NodeWithParent(model, params.cut_lo, CL.ProblemSetupInfo(0),
        CL.EvalInfo(), rootNode)


end

function testpuremaster()
    counter = CL.VarConstrCounter(0)
    user_optimizer = Cbc.CbcOptimizer()

    problem = CL.SimpleCompactProblem(user_optimizer, counter)

    x1 = CL.MasterVar(problem.counter, "x1", -10.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x2 = CL.MasterVar(problem.counter, "x2", -15.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x3 = CL.MasterVar(problem.counter, "x3", -20.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)

    CL.add_variable(problem, x1)
    CL.add_variable(problem, x2)
    CL.add_variable(problem, x3)

    constr = CL.MasterConstr(problem.counter, "knapConstr", 5.0, 'L', 'M', 's')

    CL.add_constraint(problem, constr)

    CL.add_membership(x1, constr, problem, 2.0)
    CL.add_membership(x2, constr, problem, 3.0)
    CL.add_membership(x3, constr, problem, 4.0)

    CL.optimize(problem)

    @test MOI.get(problem.optimizer, MOI.ObjectiveValue()) == -25
end

function test_master_plus_branching()
    counter = CL.VarConstrCounter(0)
    user_optimizer = Cbc.CbcOptimizer()

    problem = CL.SimpleCompactProblem(user_optimizer, counter)

    x1 = CL.MasterVar(problem.counter, "x1", -10.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x2 = CL.MasterVar(problem.counter, "x2", -15.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x3 = CL.MasterVar(problem.counter, "x3", -20.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)

    CL.add_variable(problem, x1)
    CL.add_variable(problem, x2)
    CL.add_variable(problem, x3)

    constr = CL.MasterConstr(problem.counter, "knapConstr", 5.0, 'L', 'M', 's')

    CL.add_constraint(problem, constr)

    CL.add_membership(x1, constr, problem, 2.0)
    CL.add_membership(x2, constr, problem, 3.0)
    CL.add_membership(x3, constr, problem, 4.0)


    ### Model constructors
    params = CL.Params()
    counter = CL.VarConstrCounter(0)
    masteroptimizer = Cbc.CbcOptimizer()
    master_problem = CL.SimpleCompactProblem(masteroptimizer, counter)
    pricingoptimizer = Cbc.CbcOptimizer()
    callback = CL.Callback()
    extended_problem = CL.ExtendedProblemConstructor(master_problem,
        CL.Problem[], CL.Problem[], counter, params, params.cut_up, params.cut_lo)
    model = CL.ModelConstructor(extended_problem, callback, params)

    CL.solve(model)

end


testdefaultbuilders()
testpuremaster()
testcolgenatroot()
test_master_plus_branching()

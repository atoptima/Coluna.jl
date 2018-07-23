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


    ### Info constructors
    stab_info = CL.StabilizationInfo(master_problem, params)
    lp_basis = CL.LpBasisRecord()
    cg_eval_info = CL.ColGenEvalInfo(stab_info, lp_basis, 0.5)
    lp_eval_info = CL.LpEvalInfo(stab_info)


    ### Algorithms constructors
    alg_setup_node = CL.AlgToSetupNode(extended_problem,
        CL.ProblemSetupInfo(0), false)
    alg_preprocess_node = CL.AlgToPreprocessNode()
    alg_eval_node = CL.AlgToEvalNode(extended_problem)
    alg_to_eval_by_lp = CL.AlgToEvalNodeByLp(extended_problem)
    alg_to_eval_by_cg = CL.AlgToEvalNodeByColGen(extended_problem)
    alg_setdown_node = CL.AlgToSetdownNode(extended_problem)
    alg_vect_primal_heur_node = CL.AlgToPrimalHeurInNode[]
    alg_generate_children_nodes = CL.AlgToGenerateChildrenNodes(extended_problem)
    usual_branching_algo = CL.UsualBranchingAlg(extended_problem)


    ### Node constructors
    rootNode = CL.Node(model.extended_problem, params.cut_lo, CL.ProblemSetupInfo(0), cg_eval_info)
    child1 = CL.NodeWithParent(model.extended_problem, rootNode)


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

function branch_and_bound_test_instance()
    counter = CL.VarConstrCounter(0)
    mastero_ptimizer = Cbc.CbcOptimizer()

    master_problem = CL.SimpleCompactProblem(mastero_ptimizer, counter)

    x1 = CL.MasterVar(master_problem.counter, "x1", -10.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
    x2 = CL.MasterVar(master_problem.counter, "x2", -15.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
    x3 = CL.MasterVar(master_problem.counter, "x3", -20.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)

    CL.add_variable(master_problem, x1)
    CL.add_variable(master_problem, x2)
    CL.add_variable(master_problem, x3)

    constr = CL.MasterConstr(master_problem.counter, "knapConstr", 6.0, 'L', 'M', 's')

    CL.add_constraint(master_problem, constr)

    CL.add_membership(x1, constr, master_problem, 2.0)
    CL.add_membership(x2, constr, master_problem, 3.0)
    CL.add_membership(x3, constr, master_problem, 4.0)


    ### Model constructors
    params = CL.Params()
    counter = CL.VarConstrCounter(0)
    pricingoptimizer = Cbc.CbcOptimizer()
    callback = CL.Callback()
    extended_problem = CL.ExtendedProblemConstructor(master_problem,
        CL.Problem[], CL.Problem[], counter, params, params.cut_up, params.cut_lo)
    model = CL.ModelConstructor(extended_problem, callback, params)

    CL.solve(model)

end

function branch_and_bound_bigger_instance()
    counter = CL.VarConstrCounter(0)
    mastero_ptimizer = Cbc.CbcOptimizer()

    master_problem = CL.SimpleCompactProblem(mastero_ptimizer, counter)


    nb_bins = 3
    n_items = 4
    profits = [-10.0, -15.0, -20.0, -50.0]
    weights = [  4.0,   5.0,   6.0,  10.0]
    binscap = [ 10.0,  2.0,  10.0]


    knap_constrs = CL.MasterConstr[]
    for i in 1:nb_bins
        constr = CL.MasterConstr(master_problem.counter,
            string("knapConstr", i), binscap[i], 'L', 'M', 's')
        push!(knap_constrs, constr)
        CL.add_constraint(master_problem, constr)
    end

    cover_constrs = CL.MasterConstr[]
    for j in 1:n_items
        constr = CL.MasterConstr(master_problem.counter,
            string("CoverCons", j), 1.0, 'L', 'M', 's')
        push!(cover_constrs, constr)
        CL.add_constraint(master_problem, constr)
    end

    x_vars = Vector{Vector{CL.MasterVar}}()
    for j in 1:n_items
        x_vec = CL.MasterVar[]
        for i in 1:nb_bins
            x_var = CL.MasterVar(master_problem.counter, string("x(", j, ",", i, ")"),
                profits[j], 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
            push!(x_vec, x_var)
            CL.add_variable(master_problem, x_var)
            CL.add_membership(x_var, cover_constrs[j], master_problem, 1.0)
            CL.add_membership(x_var, knap_constrs[i], master_problem, weights[j])
        end
        push!(x_vars, x_vec)
    end

    ### Model constructors
    params = CL.Params()
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
branch_and_bound_test_instance()
branch_and_bound_bigger_instance()

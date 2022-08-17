using Coluna.Algorithm
using Coluna.MathProg
using Parameters

function user_algorithms_tests()
    conseq_colgen_test()
end

@with_kw struct ConsecutiveColGen <: AbstractOptimizationAlgorithm
    colgen = ColumnGeneration(smoothing_stabilization = 1.0)
    preprocess = PreprocessAlgorithm(preprocess_subproblems = true, printing = true)
    rm_heur = RestrictedMasterIPHeuristic()
    num_calls_to_col_gen = 3  
end

function Coluna.Algorithm.get_child_algorithms(
    algo::ConsecutiveColGen, reform::Reformulation
)
    return [(algo.colgen, reform), (algo.preprocess, reform), (algo.rm_heur, reform)]
end 

function Coluna.Algorithm.get_units_usage(
    algo::ConsecutiveColGen, reform::Reformulation
) 
    master = Coluna.MathProg.getmaster(reform)
    return [
        (reform, Coluna.Algorithm.PreprocessingUnit, Coluna.Algorithm.READ_AND_WRITE),
        (master, Coluna.Algorithm.PartialSolutionUnit, Coluna.Algorithm.READ_AND_WRITE)
    ]
end

function Coluna.Algorithm.run!(
    algo::ConsecutiveColGen, env::Env, reform::Reformulation, input::OptimizationInput
)
    master = Coluna.MathProg.getmaster(reform)
    optstate = getoptstate(input)

    cg_run_number = 1

    while cg_run_number <= algo.num_calls_to_col_gen 

        cg_output = run!(algo.colgen, env, reform, OptimizationInput(optstate))
        cg_optstate = getoptstate(cg_output)
        add_ip_primal_sols!(optstate, get_ip_primal_sols(cg_optstate)...)

        primal_sol = get_best_lp_primal_sol(cg_optstate)

        if cg_run_number == 1
            set_ip_dual_bound!(optstate, get_ip_dual_bound(cg_optstate))
        end

        var_vals = [(var, val) for (var, val) in primal_sol] 
        isempty(var_vals) && break

        sort!(var_vals, by = x -> last(x), rev = true)

        preprocess_unit = ClB.getstorageunit(reform, PreprocessingUnit)
        partsol_unit = ClB.getstorageunit(master, PartialSolutionUnit)
    
        add_to_localpartialsol!(preprocess_unit, first(var_vals[1]), 1.0)
        add_to_solution!(partsol_unit, first(var_vals[1]), 1.0)

        prp_output = run!(algo.preprocess, env, reform, EmptyInput())
        #isinfeasible(prp_output) && break
        prp_output.infeasible && break
    
        cg_run_number += 1
    end

    heur_output = run!(algo.rm_heur, env, reform, OptimizationInput(optstate))
    add_ip_primal_sols!(optstate, get_ip_primal_sols(getoptstate(heur_output))...)

    setterminationstatus!(optstate, getterminationstatus(getoptstate(heur_output)))

    return OptimizationOutput(optstate)
end

@testset "Old - conseq colgen test" begin
    data = ClD.GeneralizedAssignment.data("mediumgapcuts3.txt")

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "params" => CL.Params(solver = ConsecutiveColGen(num_calls_to_col_gen = 3)),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)

    BD.objectiveprimalbound!(model, 2000.0)
    BD.objectivedualbound!(model, 0.0)

    JuMP.optimize!(model)    

    @test JuMP.objective_value(model) < 2000.0
end
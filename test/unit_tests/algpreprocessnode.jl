function alg_preprocess_node_unit_tests()
    run_alg_preprocess_node()
end

function run_alg_preprocess_node()

    nb_jobs, nb_machs = (7, 2)
    caps = [5.0, 8.0]
    costs = [ [8.0, 5.0, 11.0, 21.0, 6.0, 5.0, 19.0], [1.0, 12.0, 11.0, 12.0, 14.0, 8.0, 5.0] ] 
    weights = [ [6.0, 3.0, 3.0, 1.0, 2.0, 1.0, 1.0], [5.0, 1.0, 1.0, 3.0, 1.0, 5.0, 4.0] ] 


    moi_model, vars, cover_constrs, knp_constrs = build_colgen_gap_model_with_moi(nb_jobs,
                                                           nb_machs, caps, costs, weights)  
    coluna_optimizer = moi_model.optimizer
    MOI.copy_to(coluna_optimizer, moi_model.model_cache)

    coluna_model = coluna_optimizer.inner
    CL.set_prob_ref_to_problem_dict(coluna_model.extended_problem)

    root = CL.create_root_node(coluna_model.extended_problem)
    alg_setup = CL.AlgToSetupRootNode(coluna_model.extended_problem, root.problem_setup_info)
    alg_preprocess = CL.AlgToPreprocessNode(coluna_model.extended_problem)

    CL.run(alg_setup, root)
    CL.run(alg_preprocess, root)

    @test length(alg_preprocess.preprocessed_vars) == 6
    for (m,j) in [(1,1), (2,1), (2,6), (2,7), (1,6), (1,7)]
        @test coluna_optimizer.varmap[vars[m][j]] in alg_preprocess.preprocessed_vars
    end

    #TODO: test preprocessed constraints
end

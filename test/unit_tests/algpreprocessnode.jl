function alg_preprocess_node_unit_tests()
    run_test_small_gap_with_bounded_vars()
    run_test_small_gap_with_unbounded_vars()
    run_detailed_test_small_gap()
end

function run_test_small_gap_with_bounded_vars()

    nb_jobs, nb_machs = (7, 2)
    caps = [5.0, 8.0]
    costs = [ [8.0, 5.0, 11.0, 21.0, 6.0, 5.0, 19.0], [1.0, 12.0, 11.0, 12.0, 14.0, 8.0, 5.0] ] 
    weights = [ [6.0, 3.0, 3.0, 1.0, 2.0, 1.0, 1.0], [5.0, 1.0, 1.0, 3.0, 1.0, 5.0, 4.0] ] 

    moi_model, vars, cover_constrs, knp_constrs = build_colgen_gap_model_with_moi(nb_jobs,
                                                           nb_machs, caps, costs, weights, true)  
    coluna_optimizer = moi_model.optimizer
    MOI.copy_to(coluna_optimizer, moi_model.model_cache)

    coluna_model = coluna_optimizer.inner
    CL.set_prob_ref_to_problem_dict(coluna_model.extended_problem)

    root = CL.create_root_node(coluna_model.extended_problem)
    alg_setup = CL.AlgToSetupRootNode(coluna_model.extended_problem, 
                                      root.problem_setup_info, root.local_branching_constraints)
    alg_preprocess = CL.AlgToPreprocessNode(root.depth, coluna_model.extended_problem)

    CL.run(alg_setup)
    CL.run(alg_preprocess)

    @test length(alg_preprocess.preprocessed_vars) == 6
    for (m,j) in [(1,1), (2,1), (2,6), (2,7), (1,6), (1,7)]
        @test coluna_optimizer.varmap[vars[m][j]] in alg_preprocess.preprocessed_vars
    end

    #TODO: test preprocessed constraints
end

function run_test_small_gap_with_unbounded_vars()

    nb_jobs, nb_machs = (7, 2)
    caps = [5.0, 8.0]
    costs = [ [8.0, 5.0, 11.0, 21.0, 6.0, 5.0, 19.0], [1.0, 12.0, 11.0, 12.0, 14.0, 8.0, 5.0] ] 
    weights = [ [6.0, 3.0, 3.0, 1.0, 2.0, 1.0, 1.0], [5.0, 1.0, 1.0, 3.0, 1.0, 5.0, 4.0] ] 

    moi_model, vars, cover_constrs, knp_constrs = build_colgen_gap_model_with_moi(nb_jobs,
                                                           nb_machs, caps, costs, weights, false)  
    coluna_optimizer = moi_model.optimizer
    MOI.copy_to(coluna_optimizer, moi_model.model_cache)

    coluna_model = coluna_optimizer.inner
    CL.set_prob_ref_to_problem_dict(coluna_model.extended_problem)

    root = CL.create_root_node(coluna_model.extended_problem)
    alg_setup = CL.AlgToSetupRootNode(coluna_model.extended_problem, 
                                      root.problem_setup_info, root.local_branching_constraints)
    alg_preprocess = CL.AlgToPreprocessNode(root.depth, coluna_model.extended_problem)

    CL.run(alg_setup)
    CL.run(alg_preprocess)

    @test length(alg_preprocess.preprocessed_vars) == 14

    #TODO: test preprocessed constraints
end

function run_detailed_test_small_gap()

    nb_jobs, nb_machs = (7, 2)
    caps = [5.0, 8.0]
    costs = [ [8.0, 5.0, 11.0, 21.0, 6.0, 5.0, 19.0], [1.0, 12.0, 11.0, 12.0, 14.0, 8.0, 5.0] ] 
    weights = [ [6.0, 3.0, 3.0, 1.0, 2.0, 1.0, 1.0], [5.0, 1.0, 1.0, 3.0, 1.0, 5.0, 4.0] ] 

    bounds = []

    #TODO: execute more iterations with different instances
    while true
        moi_model, vars, cover_constrs, knp_constrs = build_colgen_gap_model_with_moi(nb_jobs,
                                                        nb_machs, caps, costs, weights, true)  
        coluna_optimizer = moi_model.optimizer
        MOI.copy_to(coluna_optimizer, moi_model.model_cache)

        coluna_model = coluna_optimizer.inner
        CL.set_prob_ref_to_problem_dict(coluna_model.extended_problem)

        root = CL.create_root_node(coluna_model.extended_problem)

        alg_setup = CL.AlgToSetupRootNode(coluna_model.extended_problem, 
                                          root.problem_setup_info, root.local_branching_constraints)
        alg_preprocess = CL.AlgToPreprocessNode(root.depth, coluna_model.extended_problem)

        CL.run(alg_setup)
        CL.run(alg_preprocess)

        for m in 1:nb_machs, j in 1:nb_jobs
            var = coluna_optimizer.varmap[vars[m][j]] 
            if var in alg_preprocess.preprocessed_vars
                model, x_vars = build_gap_coluna_model(nb_jobs, nb_machs, caps, costs, weights)  
                #add a constraint enforcing the opposite value for
                #the preprocessed var
                master_problem = model.extended_problem.master_problem
                constr = CL.MasterConstr(master_problem.counter,
                                         string("Bound_", m, "_", j), 1.0 - var.cur_lb, 'E', 'M', 's')
                CL.add_constraint(master_problem, constr; update_moi = true)
                CL.add_membership(x_vars[m][j], constr, 1.0; optimizer = master_problem.optimizer)
                #the model must be infeasible
                model.params.apply_preprocessing = false
                CL.solve(model)
                @test model.extended_problem.primal_inc_bound == Inf
            end
        end

        break
    end
end

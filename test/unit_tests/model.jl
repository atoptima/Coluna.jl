import DataStructures
global const DS = DataStructures
function model_unit_tests()

    model_tests()
    create_root_node_tests()
    set_model_optimizers_tests()
    prepare_node_for_treatment_tests()
    print_info_before_solving_node_tests()
    update_search_trees_tests()
    update_cur_valid_dual_bound_tests()
    update_cur_valid_dual_bound_root_node_tests()
    update_primal_inc_solution_tests()
    update_model_incumbents_tests()
    generate_and_write_bap_tree_tests()
    optimize_model_tests()
    solve_tests()

end

function model_tests()
    model = CL.ModelConstructor(false)
    @test model.extended_problem == nothing
    @test model.prob_counter.value == -1
    @test model.problemidx_optimizer_map == Dict{Int,MOI.AbstractOptimizer}()
    model = CL.ModelConstructor(true)
    @test model.extended_problem != nothing
    @test model.prob_counter.value == 0
    @test model.problemidx_optimizer_map == Dict{Int,MOI.AbstractOptimizer}()
end

function create_root_node_tests()
    extended_problem = create_extended_problem()
    node = CL.create_root_node(extended_problem)
    @test typeof(node) == CL._Node
    @test node.node_inc_lp_dual_bound == extended_problem.dual_inc_bound
    @test node.node_inc_ip_dual_bound == extended_problem.dual_inc_bound
    @test node.node_inc_lp_primal_bound == extended_problem.primal_inc_bound
    @test node.node_inc_ip_primal_bound == extended_problem.primal_inc_bound
end

function set_model_optimizers_tests()
    model = CL.ModelConstructor(true)
    try CL.set_model_optimizers(model)
        error("Coluna did not throw error when asked to initialize unexisting optimizer.")
    catch err
        @test err == ErrorException("Optimizer was not set to master problem.")
    end
    @test model.extended_problem.master_problem.optimizer == nothing
    @test length(model.extended_problem.pricing_vect) == 0


    model = CL.ModelConstructor()
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    prob_counter = model.prob_counter
    master_problem = extended_problem.master_problem
    masteroptimizer = GLPK.Optimizer()
    model.problemidx_optimizer_map[master_problem.prob_ref] = masteroptimizer
    pricingoptimizer = GLPK.Optimizer()
    pricingprob = CL.SimpleCompactProblem(prob_counter, counter)
    push!(extended_problem.pricing_vect, pricingprob)
    model.problemidx_optimizer_map[pricingprob.prob_ref] = pricingoptimizer
    CL.set_model_optimizers(model)
    @test typeof(model.extended_problem.master_problem.optimizer) <: MOI.ModelLike
    @test length(model.extended_problem.pricing_vect) == 1
    @test typeof(model.extended_problem.pricing_vect[1].optimizer) <: MOI.ModelLike
end

function prepare_node_for_treatment_tests()
    # Tests for root node
    extended_problem = create_extended_problem()
    node = CL.create_root_node(extended_problem)

    treat_algs = CL.TreatAlgs()
    node.evaluated = false
    extended_problem.params.use_restricted_master_heur = true
    @test CL.prepare_node_for_treatment(extended_problem, node, treat_algs, -10) == true
    @test length(treat_algs.alg_vect_primal_heur_node) == 1
    @test typeof(treat_algs.alg_eval_node) == CL._AlgToEvalNodeBySimplexColGen
    @test typeof(treat_algs.alg_setup_node) == CL._AlgToSetupRootNode
    @test typeof(treat_algs.alg_setdown_node) == CL._AlgToSetdownNodeFully
    @test typeof(treat_algs.alg_generate_children_nodes) == CL._UsualBranchingAlg

    treat_algs = CL.TreatAlgs()
    node.evaluated = true
    extended_problem.params.use_restricted_master_heur = false
    @test CL.prepare_node_for_treatment(extended_problem, node, treat_algs, -10) == true
    @test length(treat_algs.alg_vect_primal_heur_node) == 0
    @test typeof(treat_algs.alg_eval_node) == CL._AlgLike
    @test typeof(treat_algs.alg_setup_node) == CL._AlgToSetupRootNode
    @test typeof(treat_algs.alg_setdown_node) == CL._AlgToSetdownNodeFully
    @test typeof(treat_algs.alg_generate_children_nodes) == CL._UsualBranchingAlg

    # Tests for children nodes
    extended_problem = create_extended_problem()
    node = CL.NodeWithParent(extended_problem, node)

    treat_algs = CL.TreatAlgs()
    node.evaluated = false
    extended_problem.params.use_restricted_master_heur = true
    extended_problem.primal_inc_bound = 10.0
    node.node_inc_ip_dual_bound = 11.0
    @test CL.prepare_node_for_treatment(extended_problem, node, treat_algs, -10) == false
    @test length(treat_algs.alg_vect_primal_heur_node) == 0
    @test typeof(treat_algs.alg_eval_node) == CL._AlgLike
    @test typeof(treat_algs.alg_setup_node) == CL._AlgLike
    @test typeof(treat_algs.alg_setdown_node) == CL._AlgLike
    @test typeof(treat_algs.alg_generate_children_nodes) == CL._AlgLike

    treat_algs = CL.TreatAlgs()
    node.evaluated = false
    extended_problem.primal_inc_bound = 10.0
    node.node_inc_ip_dual_bound = 0.0
    @test CL.prepare_node_for_treatment(extended_problem, node, treat_algs, 0) == true
    @test length(treat_algs.alg_vect_primal_heur_node) == 0
    @test typeof(treat_algs.alg_setup_node) == CL._AlgToSetupBranchingOnly
    @test typeof(treat_algs.alg_setdown_node) == CL._AlgToSetdownNodeFully
    @test typeof(treat_algs.alg_eval_node) == CL._AlgToEvalNodeBySimplexColGen
    @test typeof(treat_algs.alg_generate_children_nodes) == CL._UsualBranchingAlg

    treat_algs = CL.TreatAlgs()
    node.evaluated = true
    extended_problem.primal_inc_bound = 10.0
    node.node_inc_ip_dual_bound = 0.0
    @test CL.prepare_node_for_treatment(extended_problem, node, treat_algs, -32) == true
    @test length(treat_algs.alg_vect_primal_heur_node) == 0
    @test typeof(treat_algs.alg_setup_node) == CL._AlgToSetupFull
    @test typeof(treat_algs.alg_setdown_node) == CL._AlgToSetdownNodeFully
    @test typeof(treat_algs.alg_eval_node) == CL._AlgLike
    @test typeof(treat_algs.alg_generate_children_nodes) == CL._UsualBranchingAlg
end

function print_info_before_solving_node_tests()
    # TODO: Test if problem is not modified inside function
    extended_problem = create_extended_problem()
    extended_problem.dual_inc_bound = -12.3
    extended_problem.primal_inc_bound = 103.2
    backup_stdout = stdout
    (rd, wr) = redirect_stdout()
    CL.print_info_before_solving_node(extended_problem, 10, 11, -32)
    close(wr)
    s = String(readavailable(rd))
    close(rd)
    redirect_stdout(backup_stdout)
    @test s == "10 open nodes. Treating node -32.\nCurrent best known bounds : [ -12.3 , 103.2 ]\n************************************************************\n"
end

function update_search_trees_tests()
    extended_problem = create_extended_problem()
    search_tree = DS.Queue{CL.Node}()
    extended_problem.params.open_nodes_limit = 100
    global_nodes_treat_order = 1
    nb_treated_nodes = 0
    node = CL.create_root_node(extended_problem)
    childs = [CL.NodeWithParent(extended_problem, node) for i in 1:3]
    for i in 1:3
        push!(node.children, childs[i])
    end
    CL.update_search_trees(node, search_tree, extended_problem)
    @test length(search_tree) == 3

    search_tree = DS.Queue{CL.Node}()
    extended_problem.params.open_nodes_limit = 2
    CL.update_search_trees(node, search_tree, extended_problem)
    @test length(search_tree) == 2
end

function calculate_subtree_size_tests()
    # This function is empty, but may be called
    extended_problem = create_extended_problem()
    node = CL.create_root_node(extended_problem)
    CL.calculate_subtree_size(node, 10)
end

function update_cur_valid_dual_bound_tests()
    extended_problem = create_extended_problem()
    search_tree = DS.Queue{CL.Node}()
    r_node = CL.create_root_node(extended_problem)
    node = CL.NodeWithParent(extended_problem, r_node)
    extended_problem.dual_inc_bound = -10.3
    extended_problem.primal_inc_bound = 23.5

    # Tests when search tree is empty
    CL.update_cur_valid_dual_bound(extended_problem, node, search_tree)
    @test extended_problem.dual_inc_bound == 23.5

    # Creates search tree that is not empty
    child_1 = CL.NodeWithParent(extended_problem, node)
    child_2 = CL.NodeWithParent(extended_problem, node)
    child_3 = CL.NodeWithParent(extended_problem, node)
    search_tree = DS.Queue{CL.Node}()
    DS.enqueue!(search_tree, child_1)
    DS.enqueue!(search_tree, child_2)
    DS.enqueue!(search_tree, child_3)

    # Tests when there is nothing to improve
    child_1.node_inc_ip_dual_bound = 111.5
    child_2.node_inc_ip_dual_bound = 34.5
    child_3.node_inc_ip_dual_bound = 54.3
    CL.update_cur_valid_dual_bound(extended_problem, node, search_tree)
    @test extended_problem.dual_inc_bound == 23.5

    # Tests when bound should be updated
    child_1.node_inc_ip_dual_bound = 0.5
    child_2.node_inc_ip_dual_bound = 1.5
    child_3.node_inc_ip_dual_bound = 0.3
    CL.update_cur_valid_dual_bound(extended_problem, node, search_tree)
    @test extended_problem.dual_inc_bound == 0.3
end

function update_cur_valid_dual_bound_root_node_tests()
    extended_problem = create_extended_problem()
    search_tree = DS.Queue{CL.Node}()
    node = CL.create_root_node(extended_problem)

    # Tests when bound should be updated
    extended_problem.dual_inc_bound = -10.3
    node.node_inc_ip_dual_bound = 12.9
    CL.update_cur_valid_dual_bound(extended_problem, node, search_tree)
    @test extended_problem.dual_inc_bound == 12.9

    # Tests when there is nothing to improve
    extended_problem.dual_inc_bound = 20.3
    node.node_inc_ip_dual_bound = 12.9
    CL.update_cur_valid_dual_bound(extended_problem, node, search_tree)
    @test extended_problem.dual_inc_bound == 20.3
end

function update_primal_inc_solution_tests()
    extended_problem = create_extended_problem()
    extended_problem.primal_inc_bound = 12.0
    vars = create_array_of_vars(3, CL.Variable)
    var_val_map = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    sol = CL.PrimalSolution(11.0, var_val_map)
    CL.update_primal_inc_solution(extended_problem, sol)
    @test extended_problem.primal_inc_bound == sol.cost
    @test extended_problem.solution.cost == sol.cost
    @test haskey(extended_problem.solution.var_val_map, vars[1])
    @test haskey(extended_problem.solution.var_val_map, vars[2])
    @test !haskey(extended_problem.solution.var_val_map, vars[3])

    extended_problem.primal_inc_bound = 5.5
    extended_problem.solution = CL.PrimalSolution(0.0, Dict{CL.Variable,Float64}())
    CL.update_primal_inc_solution(extended_problem, sol)
    @test extended_problem.primal_inc_bound == 5.5
    @test extended_problem.solution.cost == 0.0
    @test length(extended_problem.solution.var_val_map) == 0
end

function update_model_incumbents_tests()
    extended_problem = create_extended_problem()
    search_tree = DS.Queue{CL.Node}()
    r_node = CL.create_root_node(extended_problem)
    node = CL.NodeWithParent(extended_problem, r_node)
    extended_problem.dual_inc_bound = -10.3
    extended_problem.primal_inc_bound = 23.5

    # Fow the dual part
    node.dual_bound_is_updated = true
    child_1 = CL.NodeWithParent(extended_problem, node)
    child_2 = CL.NodeWithParent(extended_problem, node)
    child_3 = CL.NodeWithParent(extended_problem, node)
    search_tree = DS.Queue{CL.Node}()
    DS.enqueue!(search_tree, child_1)
    DS.enqueue!(search_tree, child_2)
    DS.enqueue!(search_tree, child_3)
    child_1.node_inc_ip_dual_bound = 0.5
    child_2.node_inc_ip_dual_bound = 1.5
    child_3.node_inc_ip_dual_bound = 0.3
    CL.update_cur_valid_dual_bound(extended_problem, node, search_tree)

    # Fow the primal part
    node.ip_primal_bound_is_updated = true
    extended_problem.primal_inc_bound = 12.0
    vars = create_array_of_vars(3, CL.Variable)
    var_val_map = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    sol = CL.PrimalSolution(11.0, var_val_map)
    node.node_inc_ip_primal_sol = sol
    CL.update_model_incumbents(extended_problem, node, search_tree)
    @test extended_problem.dual_inc_bound == 0.3
    @test extended_problem.primal_inc_bound == sol.cost
    @test extended_problem.solution.cost == sol.cost
    @test haskey(extended_problem.solution.var_val_map, vars[1])
    @test haskey(extended_problem.solution.var_val_map, vars[2])
    @test !haskey(extended_problem.solution.var_val_map, vars[3])
end

function generate_and_write_bap_tree_tests()
    # This function is empty
end

function solve_tests()
    model = CL.ModelConstructor()
    extended_problem = create_cg_extended_problem()
    model.extended_problem = extended_problem
    CL.solve(model)
    @test model.extended_problem === extended_problem
    @test extended_problem.primal_inc_bound == 2.0
    @test extended_problem.dual_inc_bound == 2.0
end

function optimize_model_tests()
    extended_problem = create_cg_extended_problem()
    CL.optimize(extended_problem)
    @test extended_problem.primal_inc_bound == 2.0
    @test extended_problem.dual_inc_bound == 2.0
end

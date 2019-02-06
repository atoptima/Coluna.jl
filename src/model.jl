@enum(SEARCHSTRATEGY,BestDualBoundThanDF,DepthFirstWithWorseBound,
BestLpBound, DepthFirstWithBetterBound)

@hl mutable struct Callback end

mutable struct Model # user model
    extended_problem::Union{Nothing, ExtendedProblem}
    callback::Callback
    params::Params
    prob_counter::ProblemCounter
    problemidx_optimizer_map::Dict{Int,MOI.AbstractOptimizer}
end

function ModelConstructor(params = Params();
                          with_extended_prob = true)

    callback = Callback()
    prob_counter = ProblemCounter(-1) # like cplex convention of prob_ref
    vc_counter = VarConstrCounter(0)
    if with_extended_prob
        extended_problem = ExtendedProblem(prob_counter, vc_counter, params,
                                           params.cut_up, params.cut_lo)
    else
        extended_problem = nothing
    end
    return Model(extended_problem, callback, params, prob_counter,
                 Dict{Int,MOI.AbstractOptimizer}())
end

function create_root_node(extended_problem::ExtendedProblem)::Node
    return Node(extended_problem, extended_problem.dual_inc_bound,
        ProblemSetupInfo())
end

function set_model_optimizers(model::Model)
    initialize_problem_optimizer(model.extended_problem,
                                 model.problemidx_optimizer_map)
end


### For root node
function prepare_node_for_treatment(extended_problem::ExtendedProblem,
        node::Node, treat_algs::TreatAlgs, global_nodes_treat_order::Int)
    println("************************************************************")
    println("Preparing root node for treatment.")

    treat_algs.alg_setup_node = AlgToSetupRootNode(extended_problem,
        node.problem_setup_info, node.local_branching_constraints)

    treat_algs.alg_preprocess_node = AlgToPreprocessNode(node.depth, extended_problem)
    treat_algs.alg_setdown_node = AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = UsualBranchingAlg(node.depth,
                                                               extended_problem)

    if !node.evaluated
        ## Dispatched according to eval_info
        # treat_algs.alg_eval_node = AlgToEvalNodeByLp(extended_problem)
        treat_algs.alg_eval_node = AlgToEvalNodeBySimplexColGen(extended_problem)
    end

    if extended_problem.params.use_restricted_master_heur
        push!(treat_algs.alg_vect_primal_heur_node,
                AlgToPrimalHeurByRestrictedMip(extended_problem))
    end

    return true
end

function prepare_node_for_treatment(extended_problem::ExtendedProblem,
        node::NodeWithParent, treat_algs::TreatAlgs,
        global_nodes_treat_order::Int)

    println("************************************************************")
    println("Preparing node ", global_nodes_treat_order,
        " for treatment. Parent is ", node.parent.treat_order, ".")
    println("Current primal bound is ", extended_problem.primal_inc_bound)
    println("Subtree dual bound is ", node.node_inc_ip_dual_bound)

    if is_to_be_pruned(node, extended_problem.primal_inc_bound)
        println("Node is conquered, no need for treating it.")
        return false
    end

    if global_nodes_treat_order == node.parent.treat_order+1
        treat_algs.alg_setup_node = AlgToSetupBranchingOnly(extended_problem,
            node.problem_setup_info, node.local_branching_constraints)
    else
        treat_algs.alg_setup_node = AlgToSetupFull(extended_problem,
            node.problem_setup_info, node.local_branching_constraints)
    end

    treat_algs.alg_preprocess_node = AlgToPreprocessNode(node.depth, extended_problem)
    treat_algs.alg_setdown_node = AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = UsualBranchingAlg(node.depth,
                                                               extended_problem)

    if !node.evaluated
        ## Dispatched according to eval_info (?)
        # treat_algs.alg_eval_node = AlgToEvalNodeByLp(extended_problem)
        treat_algs.alg_eval_node = AlgToEvalNodeBySimplexColGen(extended_problem)
    end

    return true
end

function print_info_before_solving_node(problem::ExtendedProblem,
        primal_tree_nb_open_nodes::Int, sec_tree_nb_open_nodes::Int,
        treat_order::Int)

    print(primal_tree_nb_open_nodes)
    println(" open nodes. Treating node ", treat_order, ".")
    #" Parent is ", node.parent.treat_order, ".")
    # probPtr()->printDynamicVarConstrStats(os); //, true);
    # printTime(diffcpu(bapcodInit().startTime(), "bcTimeMain"), os);
    println("Current best known bounds : [ ", problem.dual_inc_bound,  " , ",
        problem.primal_inc_bound, " ]")
    println("************************************************************")

end

function update_search_trees(cur_node::Node, search_tree::DS.Queue,
        extended_problem::ExtendedProblem)
    params = extended_problem.params
    for child_node in cur_node.children
        # push!(bap_tree_nodes, child_node)
        # if child_node.dual_bound_is_updated
        #     update_cur_valid_dual_bound(model, child_node)
        # end
        if length(search_tree) < params.open_nodes_limit
            DS.enqueue!(search_tree, child_node)
        else
            println("Limit on the number of open nodes is reached and",
                    "no secondary tree is implemented.")
            # enqueue(secondary_search_tree, child_node)
        end
    end
end

# function calculate_subtree_size(node::Node, sub_tree_size_by_depth::Int)
# end

function update_cur_valid_dual_bound(problem::ExtendedProblem,
        node::NodeWithParent, search_tree::DS.Queue{Node})
    ## update subtree dual bound. Utility of this is questionable
    # node.sub_tree_dual_bound = node.node_inc_ip_dual_bound
    if isempty(search_tree)
        problem.dual_inc_bound = problem.primal_inc_bound
    end
    worst_dual_bound = Inf
    for node in search_tree
        if node.node_inc_ip_dual_bound < worst_dual_bound
            worst_dual_bound = node.node_inc_ip_dual_bound
        end
    end
    if worst_dual_bound != Inf
        problem.dual_inc_bound = min(worst_dual_bound, problem.primal_inc_bound)
    end
end

function update_cur_valid_dual_bound(problem::ExtendedProblem,
        node::Node, search_tree::DS.Queue{Node})
    if node.node_inc_ip_dual_bound > problem.dual_inc_bound
        problem.dual_inc_bound = node.node_inc_ip_dual_bound
    end
end

function update_primal_inc_solution(problem::ExtendedProblem, sol::PrimalSolution)
    if sol.cost < problem.primal_inc_bound
        problem.solution = PrimalSolution(sol.cost, sol.var_val_map)
        problem.primal_inc_bound = sol.cost
        @logmsg LogLevel(-1) string("New incumbent IP solution with cost: ",
                                    problem.solution.cost)
    end
end

function update_model_incumbents(problem::ExtendedProblem, node::Node,
        search_tree::DS.Queue{Node})
    if node.ip_primal_bound_is_updated

        update_primal_inc_solution(problem, node.node_inc_ip_primal_sol)
    end
    if (node.dual_bound_is_updated &&
                length(search_tree)
                <= problem.params.limit_on_tree_size_to_update_best_dual_bound)
        update_cur_valid_dual_bound(problem, node, search_tree)
    end
end

function generate_and_write_bap_tree(nodes::Vector{Node})
    @logmsg LogLevel(-4) "Generation of bap_tree is not yet implemented."
end

# Add Manager to take care of parallelism.
# Maybe inside optimize!(extended_problem::ExtendedProblem) (?)

function solve(model::Model)
    status = optimize!(model.extended_problem)
    println(model.extended_problem.timer_output)
end

# Behaves like optimize!(problem::Problem), but sets parameters before
# function optimize!(problem::ExtendedProblem)
function optimize!(extended_problem::ExtendedProblem)
    set_prob_ref_to_problem_dict(extended_problem)
    search_tree = DS.Queue{Node}()
    params = extended_problem.params
    global_nodes_treat_order = 1
    nb_treated_nodes = 0
    DS.enqueue!(search_tree, create_root_node(extended_problem))
    bap_treat_order = 1 # Only usefull for printing
    is_primary_tree_node = true
    treat_algs = TreatAlgs()
    treated_nodes = Node[]

    #global ep_ = extended_problem

    while (!isempty(search_tree) && nb_treated_nodes < params.max_num_nodes)


        # if empty(secondary_search_tree)
        #     cur_node = pop!(search_tree)
        # else
            cur_node = DS.dequeue!(search_tree)
        # end
        cur_node_evaluated_before = cur_node.evaluated

        if prepare_node_for_treatment(extended_problem, cur_node,
                treat_algs, global_nodes_treat_order)

            print_info_before_solving_node(extended_problem,
                length(search_tree) + ((is_primary_tree_node) ? 1 : 0),
                0 + ((is_primary_tree_node) ? 0 : 1), global_nodes_treat_order)

            # if !cur_node_evaluated_before
            #     set_branch_and_price_order(cur_node, bap_treat_order)
            #     bap_treat_order += 1
            #     # nice_print(cur_node, true)
            # end

            if !treat(cur_node, treat_algs, global_nodes_treat_order,
                extended_problem.primal_inc_bound)
                println("error: branch-and-price is interrupted")
                break
            end
            push!(treated_nodes, cur_node)
            global_nodes_treat_order += 1
            nb_treated_nodes += 1

            @logmsg LogLevel(-4) "Node bounds after evaluation:"
            @logmsg LogLevel(-4) string("Primal ip bound: ",
                                        cur_node.node_inc_ip_primal_bound)
            @logmsg LogLevel(-4) string("Dual ip bound: ",
                                        cur_node.node_inc_ip_dual_bound)
            @logmsg LogLevel(-4) string("Primal lp bound: ",
                                        cur_node.node_inc_lp_primal_bound)
            @logmsg LogLevel(-4) string("Dual lp bound: ",
                                        cur_node.node_inc_lp_dual_bound)

            # the output of the treated node are the generated child nodes and
            # possibly the updated bounds and the
            # updated solution, we should update primal bound before dual one
            # as the dual bound will be limited by the primal one
            update_search_trees(cur_node, search_tree, extended_problem)
            update_model_incumbents(extended_problem, cur_node, search_tree)

            @logmsg LogLevel(-4) string("number of nodes: ", length(search_tree))

        end

        if isempty(cur_node.children)
            # calculate_subtree_size(cur_node, 1)
            # calculate_subtree_size(cur_node, sub_tree_size_by_depth)
        end
    end

    @logmsg LogLevel(-4) "Search is finished."
    @logmsg LogLevel(-4) "Primal bound: $(extended_problem.primal_inc_bound)"
    @logmsg LogLevel(-4) "Dual bound: $(extended_problem.dual_inc_bound)"
    # println("Best solution found:")
    # for kv in extended_problem.solution.var_val_map
    #     println("var: ", kv[1].name, ": ", kv[2])
    # end
    generate_and_write_bap_tree(treated_nodes)
    return "dummy_status"
end

mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
    dw_pricing_sp_lb::Dict{FormId, Id} # Attribute has ambiguous name
    dw_pricing_sp_ub::Dict{FormId, Id}
    timer_output::TimerOutputs.TimerOutput
    # strategy::AbstractStrategy
end

Reformulation(prob::AbstractProblem) = Reformulation(prob, DirectMip)

function Reformulation(prob::AbstractProblem, method::SolutionMethod)
    return Reformulation(method,
                         nothing,
                         nothing,
                         Vector{AbstractFormulation}(),
                         Dict{FormId, Int}(),
                         Dict{FormId, Int}(),
                         prob.timer_output)
end

getmaster(r::Reformulation) = r.master
setmaster!(r::Reformulation, f) = r.master = f
add_dw_pricing_sp!(r::Reformulation, f) = push!(r.dw_pricing_subprs, f)

function load_problem_in_optimizer(reformulation::Reformulation)

    load_problem_in_optimizer(reformulation.master)
    for problem in reformulation.dw_pricing_subprs
        load_problem_in_optimizer(problem)
    end
end

function initialize_moi_optimizer(reformulation::Reformulation,
                                  master_factory::JuMP.OptimizerFactory,
                                  pricing_factory::JuMP.OptimizerFactory)
    initialize_moi_optimizer(reformulation.master, master_factory)
    for problem in reformulation.dw_pricing_subprs
        initialize_moi_optimizer(problem, pricing_factory)
    end
end

function optimize!(reformulation::Reformulation)
    println("\e[1;32m Here starts optimization \e[00m")
    println("\e[1;35m it runs only FV draft algorithm \e[00m")

    # r = StrategyRecord()
    # apply(MockStrategy, reformulation, nothing, r, nothing)

    search_tree = SearchTree(_params_.search_strategy)
    search(search_tree, reformulation)

    return getstatus(reformulation)
end



    # add_node(search_tree, RootNode())

    # bap_treat_order = 1 # Only usefull for printing
    # treated_nodes = Node[]
    # while (!isempty(search_tree) && search_tree.nb_treated_nodes < params.max_num_nodes)

    #     cur_node = pop_node!(search_tree)
    #     # cur_node_evaluated_before = cur_node.evaluated
    #     treat_algs = TreatAlgs()

    #     if prepare_node_for_treatment(reformulation, cur_node,
    #             treat_algs, search_tree.treat_order)

    #         print_info_before_solving_node(search_tree, reformulation)

    #         # if !cur_node_evaluated_before
    #         #     set_branch_and_price_order(cur_node, bap_treat_order)
    #         #     bap_treat_order += 1
    #         #     # nice_print(cur_node, true)
    #         # end

    #         if !treat(cur_node, treat_algs, global_treat_order,
    #             reformulation.primal_inc_bound)
    #             error("ERROR: branch-and-price is interrupted")
    #             break
    #         end
    #         push!(treated_nodes, cur_node)
    #         global_treat_order.value += 1
    #         nb_treated_nodes += 1

    #         @logmsg LogLevel(-4) "Node bounds after evaluation:"
    #         @logmsg LogLevel(-4) string("Primal ip bound: ",
    #                                     cur_node.node_inc_ip_primal_bound)
    #         @logmsg LogLevel(-4) string("Dual ip bound: ",
    #                                     cur_node.node_inc_ip_dual_bound)
    #         @logmsg LogLevel(-4) string("Primal lp bound: ",
    #                                     cur_node.node_inc_lp_primal_bound)
    #         @logmsg LogLevel(-4) string("Dual lp bound: ",
    #                                     cur_node.node_inc_lp_dual_bound)

    #         # the output of the treated node are the generated child nodes and
    #         # possibly the updated bounds and the
    #         # updated solution, we should update primal bound before dual one
    #         # as the dual bound will be limited by the primal one
    #         update_search_trees(cur_node, search_tree, reformulation)
    #         update_model_incumbents(reformulation, cur_node, search_tree)

    #         @logmsg LogLevel(-4) string("number of nodes: ", nb_open_nodes(search_tree))

    #     end

    #     if isempty(cur_node.children)
    #         # calculate_subtree_size(cur_node, 1)
    #         # calculate_subtree_size(cur_node, sub_tree_size_by_depth)
    #     end
    # end

    # @logmsg LogLevel(-4) "Search is finished."
    # @logmsg LogLevel(-4) "Primal bound: $(reformulation.primal_inc_bound)"
    # @logmsg LogLevel(-4) "Dual bound: $(reformulation.dual_inc_bound)"
    # # println("Best solution found:")
    # # for kv in reformulation.solution.var_val_map
    # #     println("var: ", kv[1].name, ": ", kv[2])
    # # end
    # generate_and_write_bap_tree(treated_nodes)
    # return "dummy_status"

mutable struct Model <: AbstractModel
    name::String
    mid2cid_map::MOIU.IndexMap
    original_formulation::Union{Nothing, Formulation}
    re_formulation::Union{Nothing, Reformulation}
    var_counter::VarCounter
    constr_counter::ConstrCounter
    form_counter::FormCounter
    var_annotations:: Dict{VarId, BD.Annotation}
    constr_annotations:: Dict{ConstrId, BD.Annotation}
    timer_output::TimerOutputs.TimerOutput
    params::Params
    master_factory::Union{Nothing, JuMP.OptimizerFactory}
    pricing_factory::Union{Nothing, JuMP.OptimizerFactory}
    #problemidx_optimizer_map::Dict{Int, MOI.AbstractOptimizer}
end

Model(params::Params, master_factory, pricing_factory) = Model("model", MOIU.IndexMap(), nothing, nothing, 
    VarCounter(), ConstrCounter(), FormCounter(), Dict{VarId, BD.Annotation}(), 
    Dict{ConstrId, BD.Annotation}(), TimerOutputs.TimerOutput(), params, master_factory, pricing_factory)

function set_original_formulation!(m::Model, of::Formulation)
    m.original_formulation = of
    return
end

function set_re_formulation!(m::Model, r::Reformulation)
    m.re_formulation = r
    return
end

get_original_formulation(m::Model) = m.original_formulation
get_re_formulation(m::Model) = m.re_formulation

moi2cid(m::Model, mid) = m.mid2cid_map[mid] 

# @hl mutable struct Callback end

# mutable struct Model # user model
#     extended_problem::Union{Nothing, Reformulation}
#     callback::Callback
#     params::Params
#     prob_counter::ProblemCounter
#     problemidx_optimizer_map::Dict{Int,MOI.AbstractOptimizer}
# end

# function ModelConstructor(params = Params();
#                           with_extended_prob = true)

#     callback = Callback()
#     prob_counter = ProblemCounter(-1) # like cplex convention of prob_ref
#     vc_counter = VarConstrCounter(0)
#     if with_extended_prob
#         extended_problem = Reformulation(prob_counter, vc_counter, params,
#                                            params.cut_up, params.cut_lo)
#     else
#         extended_problem = nothing
#     end
#     return Model(extended_problem, callback, params, prob_counter,
#                  Dict{Int,MOI.AbstractOptimizer}())
# end

function create_root_node(extended_problem::Reformulation, params::Params)::Node
    return Node(extended_problem, -Inf, ProblemSetupInfo(), params)
end

function set_model_optimizers(model::Model)
    initialize_problem_optimizer(model.re_formulation,
                                 model.problemidx_optimizer_map)
end

function select_eval_alg(extended_problem::Reformulation, node_eval_mode::NODEEVALMODE)
    if node_eval_mode == SimplexCg
        return AlgToEvalNodeBySimplexColGen(extended_problem)
    elseif node_eval_mode == Lp
        return AlgToEvalNodeByLp(extended_problem)
    else
        error("Invalid eval mode: ", node_eval_mode)
    end
end


# function update_search_trees(cur_node::Node, search_tree::DS.PriorityQueue{Node, Float64},
#         extended_problem::Reformulation)
#     params = extended_problem.params
#     for child_node in cur_node.children
#         # push!(bap_tree_nodes, child_node)
#         # if child_node.dual_bound_is_updated
#         #     update_cur_valid_dual_bound(model, child_node)
#         # end
#         if length(search_tree) < params.open_nodes_limit
#             DS.enqueue!(search_tree, child_node, get_priority(child_node))
#         else
#             println("Limit on the number of open nodes is reached and",
#                     "no secondary tree is implemented.")
#             # enqueue(secondary_search_tree, child_node)
#         end
#     end
# end

# function update_cur_valid_dual_bound(problem::Reformulation,
#         node::NodeWithParent, search_tree::DS.PriorityQueue{Node, Float64})
#     if isempty(search_tree)
#         problem.dual_inc_bound = problem.primal_inc_bound
#     end
#     worst_dual_bound = Inf
#     for (node,priority) in search_tree
#         if node.node_inc_ip_dual_bound < worst_dual_bound
#             worst_dual_bound = node.node_inc_ip_dual_bound
#         end
#     end
#     if worst_dual_bound != Inf
#         problem.dual_inc_bound = min(worst_dual_bound, problem.primal_inc_bound)
#     end
# end

# function update_cur_valid_dual_bound(problem::Reformulation,
#         node::Node, search_tree::DS.PriorityQueue{Node, Float64})
#     if node.node_inc_ip_dual_bound > problem.dual_inc_bound
#         problem.dual_inc_bound = node.node_inc_ip_dual_bound
#     end
# end

# function update_primal_inc_solution(problem::Reformulation, sol::PrimalSolution)
#     if sol.cost < problem.primal_inc_bound
#         problem.solution = PrimalSolution(sol.cost, sol.var_val_map)
#         problem.primal_inc_bound = sol.cost
#         @logmsg LogLevel(-1) string("New incumbent IP solution with cost: ",
#                                     problem.solution.cost)
#     end
# end

# function update_model_incumbents(problem::Reformulation, node::Node,
#         search_tree::DS.PriorityQueue{Node, Float64})
#     if node.ip_primal_bound_is_updated
#         update_primal_inc_solution(problem, node.node_inc_ip_primal_sol)
#     end
#     if (node.dual_bound_is_updated &&
#                 length(search_tree)
#                 <= problem.params.limit_on_tree_size_to_update_best_dual_bound)
#         update_cur_valid_dual_bound(problem, node, search_tree)
#     end
# end

# function generate_and_write_bap_tree(nodes::Vector{Node})
#     @logmsg LogLevel(-4) "Generation of bap_tree is not yet implemented."
# end

# # Add Manager to take care of parallelism.
# # Maybe inside optimize!(extended_problem::Reformulation) (?)

# function initialize_convexity_constraints(extended_problem::Reformulation)
#     for pricing_prob in extended_problem.pricing_vect
#         add_convexity_constraints(extended_problem, pricing_prob)
#     end
# end

# function initialize_artificial_variables(extended_problem::Reformulation)
#     master = extended_problem.master_problem
#     init_manager(extended_problem.art_var_manager, master)
#     for constr in master.constr_manager.active_static_list
#         attach_art_var(extended_problem.art_var_manager, master, constr)
#     end
# end

function coluna_initialization(model::Model)
    #params = model.params
    #extended_problem = model.extended_problem

    reformulate!(model, DantzigWolfeDecomposition)

    #set_prob_ref_to_problem_dict(extended_problem)
    #set_model_optimizers(model)
    #initialize_convexity_constraints(extended_problem)
    #initialize_artificial_variables(extended_problem)
    #load_problem_in_optimizer(extended_problem)
end


function initialize_search_tree(params::Params)
    if params.search_strategy == DepthFirst
        search_tree = DS.PriorityQueue{Node, Float64}(Base.Order.Reverse)
    elseif params.search_strategy == BestDualBound
        search_tree = DS.PriorityQueue{Node, Float64}(Base.Order.Forward)
    end
    return search_tree
end

# # Behaves like optimize!(problem::Problem), but sets parameters before
# # function optimize!(problem::Reformulation)

function optimize!(m::Model)
    coluna_initialization(m)
    global __initial_solve_time = time()
    @show m.params
    @timeit m.timer_output "Solve model" begin
        status = optimize!(m.re_formulation, m.params)
    end
    println(m.timer_output)
end

function optimize!(extended_problem::Reformulation, params::Params)
    println("\e[1;32m Here starts optimization \e[00m")
    search_tree = initialize_search_tree(params)
    DS.enqueue!(search_tree, create_root_node(extended_problem, params), 0.0)
    global_treat_order = TreatOrder(1)
    nb_treated_nodes = 0
    bap_treat_order = 1 # Only usefull for printing
    is_primary_tree_node = true
    treated_nodes = Node[]

    #global ep_ = extended_problem

    while (!isempty(search_tree) && nb_treated_nodes < params.max_num_nodes)


        # if empty(secondary_search_tree)
        #     cur_node = pop!(search_tree)
        # else
            cur_node = DS.dequeue!(search_tree)
        # end
        cur_node_evaluated_before = cur_node.evaluated
        treat_algs = TreatAlgs()

        if prepare_node_for_treatment(extended_problem, cur_node,
                treat_algs, global_treat_order)

            print_info_before_solving_node(extended_problem,
                length(search_tree) + ((is_primary_tree_node) ? 1 : 0),
                0 + ((is_primary_tree_node) ? 0 : 1), global_treat_order)

            # if !cur_node_evaluated_before
            #     set_branch_and_price_order(cur_node, bap_treat_order)
            #     bap_treat_order += 1
            #     # nice_print(cur_node, true)
            # end

            if !treat(cur_node, treat_algs, global_treat_order,
                extended_problem.primal_inc_bound)
                error("ERROR: branch-and-price is interrupted")
                break
            end
            push!(treated_nodes, cur_node)
            global_treat_order.value += 1
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

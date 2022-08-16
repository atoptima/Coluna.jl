mutable struct BaBSearchSpace <: AbstractColunaSearchSpace
    reformulation::Reformulation
    conquer::AbstractConquerAlgorithm
    divide::AbstractDivideAlgorithm
    max_num_nodes::Int64
    open_nodes_limit::Int64
    opt_atol::Float64
    opt_rtol::Float64
    previous::Union{Nothing,Node}
    optstate::OptimizationState # from TreeSearchRuntimeData
    exploitsprimalsolutions::Bool # from TreeSearchRuntimeData
    conquer_units_to_restore::UnitsUsage # from TreeSearchRuntimeData
    nb_nodes_treated::Int
    current_ip_dual_bound_from_conquer
end

get_reformulation(sp::BaBSearchSpace) = sp.reformulation
get_conquer(sp::BaBSearchSpace) = sp.conquer
get_divide(sp::BaBSearchSpace) = sp.divide
get_previous(sp::BaBSearchSpace) = sp.previous
set_previous!(sp::BaBSearchSpace, previous::Node) = sp.previous = previous

function stop(space::BaBSearchSpace)
    return space.nb_nodes_treated > space.max_num_nodes
end

search_space_type(::TreeSearchAlgorithm) = PrinterSearchSpace{BaBSearchSpace}

function new_space(
    ::Type{BaBSearchSpace}, algo::TreeSearchAlgorithm, reform::Reformulation, input
)
    exploitsprimalsols = exploits_primal_solutions(algo.conqueralg) || exploits_primal_solutions(algo.dividealg)
    optstate = OptimizationState(
        getmaster(reform), getoptstate(input), exploitsprimalsols, false
    )
    conquer_units_to_restore = collect_units_to_restore!(algo.conqueralg, reform) 
    return BaBSearchSpace(
        reform,
        algo.conqueralg,
        algo.dividealg,
        algo.maxnumnodes,
        algo.opennodeslimit,
        algo.opt_atol,
        algo.opt_rtol,
        nothing,
        optstate,
        exploitsprimalsols,
        conquer_units_to_restore,
        0,
        nothing
    )
end

function new_root(sp::BaBSearchSpace, input)
    skipconquer = false # TODO: used for the diving that should be a separate algorithm.
    nodestate = OptimizationState(getmaster(sp.reformulation), getoptstate(input), false, false)
    tree_order = skipconquer ? 0 : -1
    return Node(
        tree_order, 0, nothing, nodestate, "", store_records!(sp.reformulation), false
    )
end

function after_conquer!(space::BaBSearchSpace, current, output)
    nodestate = current.optstate
    treestate = space.optstate

    current.recordids = store_records!(space.reformulation)
    current.conquerwasrun = true
    space.nb_nodes_treated += 1

    add_ip_primal_sols!(treestate, get_ip_primal_sols(nodestate)...)

    # TreeSearchAlgorithm returns the primal LP & the dual solution found at the root node.
    best_lp_primal_sol = get_best_lp_primal_sol(nodestate)
    if isrootnode(current) && !isnothing(best_lp_primal_sol)
        set_lp_primal_sol!(treestate, best_lp_primal_sol) 
    end

    best_lp_dual_sol = get_best_lp_dual_sol(nodestate)
    if isrootnode(current) && !isnothing(best_lp_dual_sol)
        set_lp_dual_sol!(treestate, best_lp_dual_sol)
    end
    return
end

# Conquer
function get_input(::AbstractConquerAlgorithm, space::BaBSearchSpace, current::Node)
    space_state = space.optstate
    node_state = current.optstate
    update_ip_primal_bound!(node_state, get_ip_primal_bound(space_state))

    # TODO: improve ?
    # Condition 1: IP Gap is closed. Abort treatment.
    # Condition 2: in the case the conquer was already run (in strong branching),
    # we still need to update the node IP primal bound before exiting 
    # (to possibly avoid branching)
    run_conquer = !ip_gap_closed(node_state, rtol = space.opt_rtol, atol = space.opt_atol) || !current.conquerwasrun

    # TODO: At the moment, we consider that there is no algorithm that exploits
    # the ip primal solution.
    # best_ip_primal_sol = get_best_ip_primal_sol(nodestate)
    # if tsdata.exploitsprimalsolutions && best_ip_primal_sol !== nothing
    #     set_ip_primal_sol!(treestate, best_ip_primal_sol)
    # end

    return ConquerInput(current, space.conquer_units_to_restore, run_conquer)
end

function get_input(::AbstractDivideAlgorithm, space::BaBSearchSpace, node::Node)
    return DivideInput(node, space.optstate)
end

function new_children(space::AbstractColunaSearchSpace, candidates, node::Node)
    add_ip_primal_sols!(space.optstate, get_ip_primal_sols(getoptstate(candidates))...)
    set_ip_dual_bound!(space.optstate, get_ip_dual_bound(node.optstate))

    children = map(candidates.children) do child
        # TODO: tree_order
        return Node(child, -1)
    end
    return children
end

function _updatedualbound!(space, reform::Reformulation, untreated_nodes)
    treestate = space.optstate

    worst_bound = mapreduce(
        node -> get_ip_dual_bound(getoptstate(node)),
        worst,
        untreated_nodes;
        init = DualBound(reform, getvalue(get_ip_primal_bound(treestate)))
    )

    set_ip_dual_bound!(treestate, worst_bound)
    return
end

function node_change!(previous::Node, current::Node, space::BaBSearchSpace, untreated_nodes)
    _updatedualbound!(space, space.reformulation, untreated_nodes) # this method needs to be reimplemented.

    # we delete solutions from the node optimization state, as they are not needed anymore
    nodestate = getoptstate(previous)
    empty_ip_primal_sols!(nodestate)
    empty_lp_primal_sols!(nodestate)
    empty_lp_dual_sols!(nodestate)
end

function tree_search_output(space::BaBSearchSpace, untreated_nodes)
    _updatedualbound!(space, space.reformulation, untreated_nodes)

    if isempty(untreated_nodes) # it means that the BB tree has been fully explored
        if length(get_ip_primal_sols(space.optstate)) >= 1
            if ip_gap_closed(space.optstate, rtol = space.opt_rtol, atol = space.opt_atol)
                setterminationstatus!(space.optstate, OPTIMAL)
            else
                setterminationstatus!(space.optstate, OTHER_LIMIT)
            end
        else
            setterminationstatus!(space.optstate, INFEASIBLE)
        end
    else
        setterminationstatus!(space.optstate, OTHER_LIMIT)
    end

    #env.kpis.node_count = 0 #get_tree_order(tsdata) - 1 # TODO : check why we need to remove 1

    return OptimizationOutput(space.optstate)
end
############################################################################################
# Node
############################################################################################
"Branch-and-bound node."
mutable struct Node <: APITMP.AbstractNode
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    branchdescription::String
    records::Records
    conquerwasrun::Bool
end

getdepth(n::Node) = n.depth

TreeSearch.get_parent(n::Node) = n.parent # divide
TreeSearch.get_opt_state(n::Node) = n.optstate # conquer, divide

TreeSearch.isroot(n::Node) = n.depth == 0
Branching.isroot(n::Node) = TreeSearch.isroot(n)
TreeSearch.get_records(n::Node) = n.records # conquer
TreeSearch.set_records!(n::Node, records) = n.records = records

TreeSearch.get_branch_description(n::Node) = n.branchdescription # printer

# Priority of nodes depends on the explore strategy.
TreeSearch.get_priority(::TreeSearch.AbstractExploreStrategy, ::Node) = error("todo")
TreeSearch.get_priority(::TreeSearch.DepthFirstStrategy, n::Node) = -n.depth
TreeSearch.get_priority(::TreeSearch.BestDualBoundStrategy, n::Node) = get_ip_dual_bound(n.optstate)

# TODO move
function Node(node::SbNode)
    return Node(
        node.depth, node.parent, node.optstate, node.branchdescription,
        node.records, node.conquerwasrun
    )
end

############################################################################################
# AbstractConquerInput implementation for the branch & bound.
############################################################################################
"Conquer input object created by the branch-and-bound tree search algorithm."
struct ConquerInputFromBaB <: AbstractConquerInput
    node::Node
    units_to_restore::UnitsUsage
    run_conquer::Bool
end

get_node(i::ConquerInputFromBaB) = i.node
get_units_to_restore(i::ConquerInputFromBaB) = i.units_to_restore
run_conquer(i::ConquerInputFromBaB) = i.run_conquer

############################################################################################
# AbstractDivideInput implementation for the branch & bound.
############################################################################################
"Divide input object created by the branch-and-bound tree search algorithm."
struct DivideInputFromBaB <: APITMP.AbstractDivideInput
    parent::Node
    opt_state::OptimizationState
end

APITMP.get_parent(i::DivideInputFromBaB) = i.parent
APITMP.get_opt_state(i::DivideInputFromBaB) = i.opt_state

############################################################################################
# SearchSpace
############################################################################################

"Branch-and-bound search space."
mutable struct BaBSearchSpace <: AbstractColunaSearchSpace
    reformulation::Reformulation
    conquer::AbstractConquerAlgorithm
    divide::APITMP.AbstractDivideAlgorithm
    max_num_nodes::Int64
    open_nodes_limit::Int64
    time_limit::Int64
    opt_atol::Float64
    opt_rtol::Float64
    previous::Union{Nothing,Node}
    optstate::OptimizationState # from TreeSearchRuntimeData
    conquer_units_to_restore::UnitsUsage # from TreeSearchRuntimeData
    nb_nodes_treated::Int
    current_ip_dual_bound_from_conquer
end

get_reformulation(sp::BaBSearchSpace) = sp.reformulation
get_conquer(sp::BaBSearchSpace) = sp.conquer
get_divide(sp::BaBSearchSpace) = sp.divide
get_previous(sp::BaBSearchSpace) = sp.previous
set_previous!(sp::BaBSearchSpace, previous::Node) = sp.previous = previous

############################################################################################
# Tree search implementation
############################################################################################
function TreeSearch.stop(space::BaBSearchSpace, untreated_nodes)
    return space.nb_nodes_treated > space.max_num_nodes || length(untreated_nodes) > space.open_nodes_limit
end

function TreeSearch.search_space_type(alg::TreeSearchAlgorithm)
    return if !iszero(length(alg.branchingtreefile)) && alg.print_node_info
        PrinterSearchSpace{BaBSearchSpace,DefaultLogPrinter,DotFilePrinter}
    elseif !iszero(length(alg.branchingtreefile))
        PrinterSearchSpace{BaBSearchSpace,DevNullLogPrinter,DotFilePrinter}
    elseif alg.print_node_info
        PrinterSearchSpace{BaBSearchSpace,DefaultLogPrinter,DevNullFilePrinter}
    else
        BaBSearchSpace
    end
end

function TreeSearch.new_space(
    ::Type{BaBSearchSpace}, algo::TreeSearchAlgorithm, reform::Reformulation, input
)
    optstate = OptimizationState(getmaster(reform), input, false, false)
    conquer_units_to_restore = collect_units_to_restore!(algo.conqueralg, reform) 
    return BaBSearchSpace(
        reform,
        algo.conqueralg,
        algo.dividealg,
        algo.maxnumnodes,
        algo.opennodeslimit,
        algo.timelimit,
        algo.opt_atol,
        algo.opt_rtol,
        nothing,
        optstate,
        conquer_units_to_restore,
        0,
        nothing
    )
end

function TreeSearch.new_root(sp::BaBSearchSpace, input)
    nodestate = OptimizationState(getmaster(sp.reformulation), input, false, false)
    return Node(
        0, nothing, nodestate, "", create_records(sp.reformulation), false
    )
end

function after_conquer!(space::BaBSearchSpace, current, output)
    nodestate = current.optstate
    treestate = space.optstate

    current.records = create_records(space.reformulation)
    current.conquerwasrun = true
    space.nb_nodes_treated += 1

    add_ip_primal_sols!(treestate, get_ip_primal_sols(nodestate)...)

    # TreeSearchAlgorithm returns the primal LP & the dual solution found at the root node.
    best_lp_primal_sol = get_best_lp_primal_sol(nodestate)
    if TreeSearch.isroot(current) && !isnothing(best_lp_primal_sol)
        set_lp_primal_sol!(treestate, best_lp_primal_sol) 
    end

    best_lp_dual_sol = get_best_lp_dual_sol(nodestate)
    if TreeSearch.isroot(current) && !isnothing(best_lp_dual_sol)
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
    # Condition 3: make sure the node has not been proven infeasible.
    # we still need to update the node IP primal bound before exiting 
    # (to possibly avoid branching)
    run_conquer = !ip_gap_closed(node_state, rtol = space.opt_rtol, atol = space.opt_atol)
    run_conquer = run_conquer || !current.conquerwasrun
    run_conquer = run_conquer && getterminationstatus(node_state) != INFEASIBLE

    # TODO: At the moment, we consider that there is no algorithm that exploits
    # the ip primal solution.
    # best_ip_primal_sol = get_best_ip_primal_sol(nodestate)
    # if tsdata.exploitsprimalsolutions && best_ip_primal_sol !== nothing
    #     set_ip_primal_sol!(treestate, best_ip_primal_sol)
    # end
    return ConquerInputFromBaB(current, space.conquer_units_to_restore, run_conquer)
end

function get_input(::APITMP.AbstractDivideAlgorithm, space::BaBSearchSpace, node::Node)
    return DivideInputFromBaB(node, space.optstate)
end

function new_children(space::AbstractColunaSearchSpace, candidates, node::Node)
    @show typeof(candidates)
    add_ip_primal_sols!(space.optstate, get_ip_primal_sols(APITMP.get_opt_state(candidates))...)
    set_ip_dual_bound!(space.optstate, get_ip_dual_bound(node.optstate))

    children = map(APITMP.get_children(candidates)) do child
        return Node(child)
    end
    return children
end

function _updatedualbound!(space, reform::Reformulation, untreated_nodes)
    treestate = space.optstate

    worst_bound = mapreduce(
        node -> get_ip_dual_bound(TreeSearch.get_opt_state(node)),
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
    nodestate = TreeSearch.get_opt_state(previous)
    empty_ip_primal_sols!(nodestate)
    empty_lp_primal_sols!(nodestate)
    empty_lp_dual_sols!(nodestate)
end

function TreeSearch.tree_search_output(space::BaBSearchSpace, untreated_nodes)
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

    return space.optstate
end
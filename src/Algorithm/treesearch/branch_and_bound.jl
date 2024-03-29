############################################################################################
# Node.
############################################################################################
"""
Branch-and-bound node. It stores only local information about the node.
Global information about the branch-and-bound belong to the search space object.
"""
mutable struct Node <: TreeSearch.AbstractNode
    depth::Int
    branchdescription::String

    # The Node instance may have been created after its partial evaluation
    # (e.g. strong branching). In this case, we store an OptimizationState in the node
    # with the result of its partial evaluation.
    # We then retrieve from this OptimizationState a possible new incumbent primal
    # solution and communicate the latter to the branch-and-bound algorithm. 
    # We also store the final result of the conquer algorithm here so we can print these 
    # informations.
    conquer_output::Union{Nothing, OptimizationState}

    # Current local dual bound at the node:
    # - dual bound of the parent node if the node has not been evaluated yet.
    # - dual bound of the conquer if the node has been evaluated.
    ip_dual_bound::Bound
    
    # Information to restore the reformulation after the creation of the node (e.g. creation
    # of the branching constraint) or its partial evaluation (e.g. strong branching).
    records::Records
end

getdepth(n::Node) = n.depth

TreeSearch.isroot(n::Node) = n.depth == 0
Branching.isroot(n::Node) = TreeSearch.isroot(n)
TreeSearch.set_records!(n::Node, records) = n.records = records
TreeSearch.get_conquer_output(n::Node) = n.conquer_output

TreeSearch.get_branch_description(n::Node) = n.branchdescription # printer

# Priority of nodes depends on the explore strategy.
TreeSearch.get_priority(::TreeSearch.AbstractExploreStrategy, ::Node) = error("todo")
TreeSearch.get_priority(::TreeSearch.DepthFirstStrategy, n::Node) = -n.depth
TreeSearch.get_priority(::TreeSearch.BestDualBoundStrategy, n::Node) = n.ip_dual_bound

# TODO move
function Node(node::SbNode)
    return Node(
        node.depth, node.branchdescription, node.conquer_output, node.ip_dual_bound,
        node.records
    )
end

############################################################################################
# AbstractConquerInput implementation for the branch & bound.
############################################################################################
"Conquer input object created by the branch-and-bound tree search algorithm."
struct ConquerInputFromBaB <: AbstractConquerInput
    units_to_restore::UnitsUsage
    node_state::OptimizationState # Node state after its creation or its partial evaluation.
    node_depth::Int

    # Broadcast a new IP primal bound if found during evaluation of the node.
    global_primal_handler::GlobalPrimalBoundHandler
end

get_global_primal_handler(i::ConquerInputFromBaB) = i.global_primal_handler
get_conquer_input_ip_dual_bound(i::ConquerInputFromBaB) = get_ip_dual_bound(i.node_state)
get_node_depth(i::ConquerInputFromBaB) = i.node_depth
get_units_to_restore(i::ConquerInputFromBaB) = i.units_to_restore
############################################################################################
# AbstractDivideInput implementation for the branch & bound.
############################################################################################
"Divide input object created by the branch-and-bound tree search algorithm."
struct DivideInputFromBaB <: Branching.AbstractDivideInput
    parent_depth::Int

    # The conquer output of the parent is very useful to compute scores when trying several
    # branching candidates. Usually scores measure a progression between the parent full_evaluation
    # and the children full evaluations. To allow developers to implement several kind of 
    # scores, we give the full output of the conquer algorithm.
    parent_conquer_output::OptimizationState

    # Records allow to restore the reformulation in the state it was at the end of the evaluation
    # of the parent node. This operation happens in strong branching when evaluating several
    # branching candidates.
    parent_records::Records

    # Broadcast a new IP primal bound if found during evaluation of the candidates in the
    # strong branching.
    global_primal_handler::GlobalPrimalBoundHandler
end

Branching.get_parent_depth(i::DivideInputFromBaB) = i.parent_depth
Branching.get_conquer_opt_state(i::DivideInputFromBaB) = i.parent_conquer_output
Branching.get_global_primal_handler(i::DivideInputFromBaB) = i.global_primal_handler
Branching.parent_is_root(i::DivideInputFromBaB) = i.parent_depth == 0
Branching.parent_records(i::DivideInputFromBaB) = i.parent_records

############################################################################################
# Leaves status
############################################################################################

"Leaves status"
mutable struct LeavesStatus
    infeasible::Bool # true if all leaves are infeasible
    worst_dual_bound::Union{Nothing,Bound} # worst dual bound of the leaves
end

LeavesStatus(reform) = LeavesStatus(true, nothing)

############################################################################################
# SearchSpace
############################################################################################

"Branch-and-bound search space."
mutable struct BaBSearchSpace <: AbstractColunaSearchSpace
    # Reformulation that the branch-and-bound algorithm will optimize.
    reformulation::Reformulation
    # Algorithm that evaluates a node of the branch-and-bound tree.
    conquer::AbstractConquerAlgorithm
    # Algorithm that generated the children of a branch-and-bound node.
    divide::AlgoAPI.AbstractDivideAlgorithm
    
    # Limits
    max_num_nodes::Int64
    open_nodes_limit::Int64
    time_limit::Int64

    # Tolerances
    opt_atol::Float64
    opt_rtol::Float64

    # Units to restore when B&B bound explores another node.
    conquer_units_to_restore::UnitsUsage

    # Global information about the branch-and-bound execution.
    previous::Union{Nothing,TreeSearch.AbstractNode}
    optstate::OptimizationState # from TreeSearchRuntimeData
  
    nb_nodes_treated::Int
    nb_untreated_nodes::Int
    leaves_status::LeavesStatus
    inc_primal_manager::GlobalPrimalBoundHandler # stores the global primal bound (shared with all child algorithms).
end

get_reformulation(sp::BaBSearchSpace) = sp.reformulation
get_conquer(sp::BaBSearchSpace) = sp.conquer
get_divide(sp::BaBSearchSpace) = sp.divide
get_previous(sp::BaBSearchSpace) = sp.previous
set_previous!(sp::BaBSearchSpace, previous::TreeSearch.AbstractNode) = sp.previous = previous

############################################################################################
# Tree search implementation
############################################################################################
function TreeSearch.stop(space::BaBSearchSpace, untreated_nodes)
    _update_global_dual_bound!(space, space.reformulation, untreated_nodes) # this method needs to be reimplemented.
    space.nb_untreated_nodes = length(untreated_nodes)
    return space.nb_nodes_treated >= space.max_num_nodes || space.nb_untreated_nodes > space.open_nodes_limit
end

function TreeSearch.search_space_type(alg::TreeSearchAlgorithm)
    # Only one file printer at the time. JSON file printer has priority.
    active_file_printer = !iszero(length(alg.branchingtreefile)) || !iszero(length(alg.jsonfile))
    file_printer_type = if !iszero(length(alg.jsonfile))
        JSONFilePrinter
    elseif !iszero(length(alg.branchingtreefile))
        DotFilePrinter
    else
        DevNullFilePrinter
    end

    return if alg.print_node_info
        PrinterSearchSpace{BaBSearchSpace,DefaultLogPrinter,file_printer_type}
    elseif active_file_printer
        PrinterSearchSpace{BaBSearchSpace,DevNullLogPrinter,file_printer_type}
    else
        BaBSearchSpace
    end
end

function TreeSearch.new_space(
    ::Type{BaBSearchSpace}, algo::TreeSearchAlgorithm, reform::Reformulation, input
)
    optstate = OptimizationState(getmaster(reform))
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
        conquer_units_to_restore,
        nothing,
        optstate,
        0,
        0,
        LeavesStatus(reform),
        GlobalPrimalBoundHandler(reform; ip_primal_bound = get_ip_primal_bound(input))
    )
end

function TreeSearch.new_root(sp::BaBSearchSpace, input)
    nodestate = OptimizationState(getmaster(sp.reformulation), input, false, false)
    return Node(
        0, "", nothing, get_ip_dual_bound(nodestate), create_records(sp.reformulation)
    )
end

# Send output information of the conquer algorithm to the branch-and-bound.
function after_conquer!(space::BaBSearchSpace, current, conquer_output)
    @assert !isnothing(conquer_output)
    treestate = space.optstate
    for sol in get_ip_primal_sols(conquer_output)
        store_ip_primal_sol!(space.inc_primal_manager, sol)
    end
    current.records = create_records(space.reformulation)
    space.nb_nodes_treated += 1

    # Branch & Bound returns the primal LP & the dual solution found at the root node.
    best_lp_primal_sol = get_best_lp_primal_sol(conquer_output)
    if TreeSearch.isroot(current) && !isnothing(best_lp_primal_sol)
        set_lp_primal_sol!(treestate, best_lp_primal_sol) 
    end
    best_lp_dual_sol = get_best_lp_dual_sol(conquer_output)
    if TreeSearch.isroot(current) && !isnothing(best_lp_dual_sol)
        set_lp_dual_sol!(treestate, best_lp_dual_sol)
    end

    # TODO: remove later but we currently need it to print information in the json file.
    current.conquer_output = conquer_output
    current.ip_dual_bound = get_lp_dual_bound(conquer_output)
    return
end

# Conquer
function is_pruned(space::BaBSearchSpace, current::Node)
    return MathProg.gap_closed(
        get_global_primal_bound(space.inc_primal_manager),
        current.ip_dual_bound,
        atol = space.opt_atol,
        rtol = space.opt_rtol
    )
end

function node_is_pruned(space::BaBSearchSpace, current::Node)
    leaves_status = space.leaves_status
    leaves_status.infeasible = false # We have a primal bound, so a primal solution, and we closed the gap, so the original problem is feasible. 
    if isnothing(leaves_status.worst_dual_bound)
        leaves_status.worst_dual_bound = current.ip_dual_bound
    else
        leaves_status.worst_dual_bound = worst(leaves_status.worst_dual_bound, current.ip_dual_bound)
    end
    return
end

function get_input(::AbstractConquerAlgorithm, space::BaBSearchSpace, current::Node)
    space_state = space.optstate
    
    node_state = OptimizationState(
        getmaster(space.reformulation);
        ip_dual_bound = current.ip_dual_bound
    )

    best_ip_primal_sol = get_best_ip_primal_sol(space_state)
    if !isnothing(best_ip_primal_sol)
        update_ip_primal_sol!(node_state, best_ip_primal_sol)
    end
    space_primal_bound = get_ip_primal_bound(space.optstate)
    if !isnothing(space_primal_bound)
        update_ip_primal_bound!(node_state, space_primal_bound)
    end

    return ConquerInputFromBaB(
        space.conquer_units_to_restore, 
        node_state,
        current.depth,
        space.inc_primal_manager
    )
end

# routine to check if divide should be call or not after a node conquer
# If the gap is closed between the prima bound and the LOCAL dual bound, then the exploration of the current branch should stop
function run_divide(sp::BaBSearchSpace, divide_input)
    conquer_opt_state = Branching.get_conquer_opt_state(divide_input)
    nodestatus = getterminationstatus(conquer_opt_state)
    return !(
        nodestatus == INFEASIBLE || 
        MathProg.gap_closed(
            get_global_primal_bound(sp.inc_primal_manager),
            get_lp_dual_bound(conquer_opt_state)
        )
    )             
end

function get_input(::AlgoAPI.AbstractDivideAlgorithm, space::BaBSearchSpace, node::Node, conquer_output)
    return DivideInputFromBaB(node.depth, conquer_output, node.records, space.inc_primal_manager)
end

number_of_children(divide_output::DivideOutput) = length(divide_output.children)

function node_is_leaf(space::BaBSearchSpace, current::Node, conquer_output::OptimizationState)
    leaves_status = space.leaves_status
    if getterminationstatus(conquer_output) != INFEASIBLE
        leaves_status.infeasible = false
    
        # We only store the dual bound of the leaves that are not infeasible.
        # Dual bound of an infeasible node means nothing.
        if isnothing(leaves_status.worst_dual_bound)
            leaves_status.worst_dual_bound = get_lp_dual_bound(conquer_output)
        else
            leaves_status.worst_dual_bound = worst(leaves_status.worst_dual_bound, get_lp_dual_bound(conquer_output))
        end
    end
    return
end

function new_children(space::AbstractColunaSearchSpace, branches, node::Node)
    children = map(Branching.get_children(branches)) do child
        return Node(child)
    end
    return children
end

# Retrieves the current dual bound of unevaluated or partially evaluated nodes
# and keeps the worst one.
function _update_global_dual_bound!(space, reform::Reformulation, untreated_nodes)
    treestate = space.optstate
    leaves_worst_dual_bound = space.leaves_status.worst_dual_bound

    init_db = if isnothing(leaves_worst_dual_bound)
        # if we didn't reach any leaf in the branch-and-bound tree, it may exist
        # some untreated nodes. We use the current ip dual bound of one untreated nodes to
        # initialize the calculation of the global dual bound.
        if length(untreated_nodes) > 0
            first(untreated_nodes).ip_dual_bound
        else # or all the leaves are infeasible and there is no untreated node => no dual bound.
            @assert space.leaves_status.infeasible
            DualBound(getmaster(reform))
        end
    else
        # Otherwise, we use the worst dual bound at the leaves.
        leaves_worst_dual_bound
    end

    worst_bound = mapreduce(
        node -> node.ip_dual_bound,
        worst,
        untreated_nodes;
        init = init_db
    )

    # The global dual bound of the branch-and-bound is a dual bound of the original problem (MIP).
    set_ip_dual_bound!(treestate, worst_bound)
    return
end

function node_change!(previous::Node, current::Node, space::BaBSearchSpace)
    # We restore the reformulation in the state it was after the creation of the current node (e.g. creation
    # of the branching constraint) or its partial evaluation (e.g. strong branching).
    # TODO: We don't need to restore if the formulation has been fully evaluated.
    restore_from_records!(space.conquer_units_to_restore, current.records)
end

function TreeSearch.tree_search_output(space::BaBSearchSpace)
    all_leaves_infeasible = space.leaves_status.infeasible

    if !isnothing(get_global_primal_sol(space.inc_primal_manager))
        add_ip_primal_sol!(space.optstate, get_global_primal_sol(space.inc_primal_manager))
    end

    if all_leaves_infeasible && space.nb_untreated_nodes == 0
        setterminationstatus!(space.optstate, INFEASIBLE)
    elseif ip_gap_closed(space.optstate, rtol = space.opt_rtol, atol = space.opt_atol)
        setterminationstatus!(space.optstate, OPTIMAL)
    else
        setterminationstatus!(space.optstate, OTHER_LIMIT)
    end
    
    #env.kpis.node_count = 0 #get_tree_order(tsdata) - 1 # TODO : check why we need to remove 1

    return space.optstate
end
mutable struct PrinterSearchSpace{ColunaSearchSpace<:AbstractColunaSearchSpace} <: AbstractSearchSpace
    current_tree_order_id::Int
    inner::ColunaSearchSpace
end
struct PrinterNode <: AbstractNode
    tree_order_id::Int
    parent::Union{Nothing,PrinterNode}
    inner::Node
end

tree_search_output(sp::PrinterSearchSpace, untreated_nodes) = 
    tree_search_output(sp.inner, Iterators.map(n -> n.inner, untreated_nodes))

new_space(
    ::Type{PrinterSearchSpace{ColunaSearchSpace}}, alg, model, input
) where {ColunaSearchSpace<:AbstractColunaSearchSpace} =
    PrinterSearchSpace{ColunaSearchSpace}(0, new_space(ColunaSearchSpace, alg, model, input))

new_root(sp::PrinterSearchSpace, input) = 
    PrinterNode(sp.current_tree_order_id+=1, nothing, new_root(sp.inner, input))

function children(sp::PrinterSearchSpace, current, env, untreated_nodes)
    print_node_info(sp, current, env, length(untreated_nodes))
    return map(
        children(sp.inner, current.inner, env, Iterators.map(n -> n.inner, untreated_nodes))
    ) do child
        return PrinterNode(sp.current_tree_order_id += 1, current, child)
    end
end

stop(sp::PrinterSearchSpace) = stop(sp.inner)

function print_node_info(sp::PrinterSearchSpace, node::PrinterNode, env, nb_untreated_nodes)
    is_root_node = iszero(getdepth(node.inner))
    current_node_id = node.tree_order_id
    current_node_depth = getdepth(node.inner)
    current_parent_id = isnothing(node.parent) ? nothing : node.parent.tree_order_id
    local_db = getvalue(get_ip_dual_bound(getoptstate(node.inner)))
    global_db = getvalue(get_ip_dual_bound(sp.inner.optstate))
    global_pb = getvalue(get_ip_primal_bound(sp.inner.optstate))
    time = elapsed_optim_time(env)
    br_constr_description = node.inner.branchdescription

    bold = Crayon(bold = true)
    unbold = Crayon(bold = false)
    yellow_bg = Crayon(background = :light_yellow)
    cyan_bg = Crayon(background = :light_cyan)
    normal_bg = Crayon(background = :default)

    println("***************************************************************************************")
    if is_root_node
        println("**** ", yellow_bg,"B&B tree root node", normal_bg)
    else
        println(
            "**** ", yellow_bg, "B&B tree node N°", bold, current_node_id, unbold, normal_bg,
            ", parent N°", bold, current_parent_id, unbold,
            ", depth ", bold, current_node_depth, unbold,
            ", ", bold, nb_untreated_nodes, unbold, " untreated node", nb_untreated_nodes > 1 ? "s" : ""
        )
    end

    @printf "**** Local DB = %.4f," local_db
    @printf " global bounds: [ %.4f , %.4f ]," global_db global_pb
    @printf " time = %.2f sec.\n" time

    if !isempty(br_constr_description)
        println("**** Branching constraint: ", cyan_bg, br_constr_description, normal_bg)
    end
    println("***************************************************************************************")
    return
end
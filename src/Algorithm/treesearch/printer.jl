############################################################################################
# File printer API
############################################################################################
"Super type to dispatch on file printer methods."
abstract type AbstractFilePrinter end

function filename(f::AbstractFilePrinter)
    @warn "filename(::$(typeof(f))) not implemented."
    return nothing
end

function init_tree_search_file!(f::AbstractFilePrinter)
    @warn "init_tree_search_file!(::$(typeof(f))) not implemented."
    return nothing
end

function print_node_in_tree_search_file!(f::AbstractFilePrinter, node, env)
    @warn "print_node_in_tree_search_file!(::$(typeof(f)), ::$(typeof(node)), ::$(typeof(env))) not implemented."
    return nothing
end

function close_tree_search_file!(f::AbstractFilePrinter)
    @warn "close_tree_search_file!(::$(typeof(f))) not implemented."
    return nothing
end

############################################################################################
# File & log printer search space.
# This is just a composite pattern on the tree search API.
############################################################################################

"""
Search space that contains the search space of the Coluna's tree search algorithm for which
we want to print execution logs.
"""
mutable struct PrinterSearchSpace{ColunaSearchSpace<:AbstractColunaSearchSpace,FilePrinter<:AbstractFilePrinter} <: AbstractSearchSpace
    current_tree_order_id::Int
    file_printer::FilePrinter
    inner::ColunaSearchSpace
end

"""
Node that contains the node of the Coluna's tree search algorithm for which we want to
print execution logs.
"""
struct PrinterNode <: AbstractNode
    tree_order_id::Int
    parent::Union{Nothing,PrinterNode}
    inner::Node
end

function tree_search_output(sp::PrinterSearchSpace, untreated_nodes)
    close_tree_search_file!(sp.file_printer)
    return tree_search_output(sp.inner, Iterators.map(n -> n.inner, untreated_nodes))
end

function new_space(
    ::Type{PrinterSearchSpace{ColunaSearchSpace}}, alg, model, input
) where {ColunaSearchSpace<:AbstractColunaSearchSpace} =
    inner_space = new_space(ColunaSearchSpace, alg, model, input)
    return PrinterSearchSpace{ColunaSearchSpace}(0, inner_space)
end

function new_root(sp::PrinterSearchSpace, input)
    inner_root = new_root(sp.inner, input)
    init_tree_search_file!(sp.file_printer)
    return PrinterNode(sp.current_tree_order_id+=1, nothing, inner_root)
end

function children(sp::PrinterSearchSpace, current, env, untreated_nodes)
    print_node_info(sp, current, env, length(untreated_nodes))
    print_node_in_tree_search_file!(sp.file_printer, current, env)
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

############################################################################################
# Default file printers.
############################################################################################

"""
Does not print the branch and bound tree.
"""
struct DevNullPrinter <: AbstractFilePrinter end
filename(::DevNullPrinter) = nothing
init_tree_search_file!(::DevNullPrinter) = nothing
print_node_in_tree_search_file!(::DevNullPrinter, _, _) = nothing
close_tree_search_file!(::DevNullPrinter) = nothing

############################################################################################

"""
File printer to create a dot file of the branch and bound tree.
"""
struct DotFilePrinter <: AbstractFilePrinter 
    filename::String
end

filename(f::DotFilePrinter) = f.filename

function init_tree_search_file!(f::DotFilePrinter)
    open(filename(f), "w") do file
        println(file, "## dot -Tpdf thisfile > thisfile.pdf \n")
        println(file, "digraph Branching_Tree {")
        print(file, "\tedge[fontname = \"Courier\", fontsize = 10];}")
    end
    return
end

function print_node_in_tree_search_file!(f::DotFilePrinter, node::PrinterNode, env)
    pb = Inf #getvalue(get_ip_primal_bound(getoptstate(data))) (TODO)
    db = getvalue(get_ip_dual_bound(getoptstate(node.inner)))
    open(filename(f), "r+") do file
        # rewind the closing brace character
        seekend(file)
        pos = position(file)
        seek(file, pos - 1)

        # start writing over this character
        ncur = node.tree_order_id
        time = elapsed_optim_time(env)
        if ip_gap_closed(getoptstate(node))
            @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[PRUNED , %.4f]\"];" ncur ncur time pb
        else
            @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[%.4f , %.4f]\"];" ncur ncur time db pb
        end
        if !isnothing(node.parent) # not root node
            npar = node.parent.tree_order_id
            @printf file "\n\tn%i -> n%i [label= \"%s\"];}" npar ncur node.branchdescription
        else
            print(file, "}")
        end
    end
    return
end

function close_tree_search_file!(f::DotFilePrinter)
    open(filename(f), "r+") do file
        # rewind the closing brace character
        seekend(file)
        pos = position(file)
        seek(file, pos - 1)
        # just move the closing brace to the next line
        println(file, "\n}")
    end
    return
end
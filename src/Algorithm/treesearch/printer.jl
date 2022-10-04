############################################################################################
# File printer API
############################################################################################

"Super type to dispatch on file printer methods."
abstract type AbstractFilePrinter end

@mustimplement "FilePrinter" new_file_printer(::Type{<:AbstractFilePrinter}, alg)
@mustimplement "FilePrinter" filename(::AbstractFilePrinter)
@mustimplement "FilePrinter" init_tree_search_file!(::AbstractFilePrinter)
@mustimplement "FilePrinter" print_node_in_tree_search_file!(::AbstractFilePrinter, node, space, env)
@mustimplement "FilePrinter" close_tree_search_file!(::AbstractFilePrinter)

############################################################################################
# Log printer API (on stdin)
############################################################################################

"Super type to dispatch on log printer method."
abstract type AbstractLogPrinter end

@mustimplement "LogPrinter" new_log_printer(::Type{<:AbstractLogPrinter})
@mustimplement "LogPrinter" print_log(::AbstractLogPrinter, space, node, env, nb_untreated_nodes)

############################################################################################
# File & log printer search space.
# This is just a composite pattern on the tree search API.
############################################################################################

"""
Search space that contains the search space of the Coluna's tree search algorithm for which
we want to print execution logs.
"""
mutable struct PrinterSearchSpace{
    ColunaSearchSpace<:AbstractColunaSearchSpace,
    LogPrinter<:AbstractLogPrinter,
    FilePrinter<:AbstractFilePrinter
} <: AbstractSearchSpace
    current_tree_order_id::Int
    log_printer::LogPrinter
    file_printer::FilePrinter
    inner::ColunaSearchSpace
end

"""
Node that contains the node of the Coluna's tree search algorithm for which we want to
print execution logs.
"""
struct PrintedNode{Node<:AbstractNode} <: AbstractNode
    tree_order_id::Int
    parent::Union{Nothing,PrintedNode}
    inner::Node
end

get_parent(n::PrintedNode) = n.parent
get_priority(explore::AbstractExploreStrategy, n::PrintedNode) = get_priority(explore, n.inner)

function tree_search_output(sp::PrinterSearchSpace, untreated_nodes)
    close_tree_search_file!(sp.file_printer)
    return tree_search_output(sp.inner, Iterators.map(n -> n.inner, untreated_nodes))
end

function new_space(
    ::Type{PrinterSearchSpace{ColunaSearchSpace,LogPrinter,FilePrinter}}, alg, model, input
) where {
    ColunaSearchSpace<:AbstractColunaSearchSpace,
    LogPrinter<:AbstractLogPrinter,
    FilePrinter<:AbstractFilePrinter
}
    inner_space = new_space(ColunaSearchSpace, alg, model, input)
    return PrinterSearchSpace(
        0, 
        new_log_printer(LogPrinter),
        new_file_printer(FilePrinter, alg),
        inner_space
    )
end

function new_root(sp::PrinterSearchSpace, input)
    inner_root = new_root(sp.inner, input)
    init_tree_search_file!(sp.file_printer)
    return PrintedNode(sp.current_tree_order_id+=1, nothing, inner_root)
end

function children(sp::PrinterSearchSpace, current, env, untreated_nodes)
    print_log(sp.log_printer, sp, current, env, length(untreated_nodes))
    print_node_in_tree_search_file!(sp.file_printer, current, sp, env)
    return map(
        children(sp.inner, current.inner, env, Iterators.map(n -> n.inner, untreated_nodes))
    ) do child
        return PrintedNode(sp.current_tree_order_id += 1, current, child)
    end
end

stop(sp::PrinterSearchSpace) = stop(sp.inner)

############################################################################################
# Default file printers.
############################################################################################

"""
Does not print the branch and bound tree.
"""
struct DevNullFilePrinter <: AbstractFilePrinter end

new_file_printer(::Type{DevNullFilePrinter}, _) = DevNullFilePrinter()
filename(::DevNullFilePrinter) = nothing
init_tree_search_file!(::DevNullFilePrinter) = nothing
print_node_in_tree_search_file!(::DevNullFilePrinter, _, _, _) = nothing
close_tree_search_file!(::DevNullFilePrinter) = nothing

############################################################################################

"""
File printer to create a dot file of the branch and bound tree.
"""
struct DotFilePrinter <: AbstractFilePrinter 
    filename::String
end

new_file_printer(::Type{DotFilePrinter}, alg::TreeSearchAlgorithm) = DotFilePrinter(alg.branchingtreefile)
filename(f::DotFilePrinter) = f.filename

function init_tree_search_file!(f::DotFilePrinter)
    open(filename(f), "w") do file
        println(file, "## dot -Tpdf thisfile > thisfile.pdf \n")
        println(file, "digraph Branching_Tree {")
        print(file, "\tedge[fontname = \"Courier\", fontsize = 10];}")
    end
    return
end

function print_node_in_tree_search_file!(f::DotFilePrinter, node::PrintedNode, sp::PrinterSearchSpace, env)
    pb = getvalue(get_ip_primal_bound(sp.inner.optstate))
    db = getvalue(get_ip_dual_bound(get_opt_state(node.inner)))
    open(filename(f), "r+") do file
        # rewind the closing brace character
        seekend(file)
        pos = position(file)
        seek(file, pos - 1)

        # start writing over this character
        ncur = node.tree_order_id
        time = elapsed_optim_time(env)
        if ip_gap_closed(get_opt_state(node.inner))
            @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[PRUNED , %.4f]\"];" ncur ncur time pb
        else
            @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[%.4f , %.4f]\"];" ncur ncur time db pb
        end
        if !isnothing(get_parent(node)) # not root node
            npar = get_parent(node).tree_order_id
            @printf file "\n\tn%i -> n%i [label= \"%s\"];}" npar ncur node.inner.branchdescription
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

############################################################################################
# Default node printers.
############################################################################################

"""
Does not log anything.
"""
struct DevNullLogPrinter <: AbstractLogPrinter end

new_log_printer(::Type{DevNullLogPrinter}) = DevNullLogPrinter()
print_log(::DevNullLogPrinter, _, _, _, _) = nothing

############################################################################################

"Default log printer."
struct DefaultLogPrinter <: AbstractLogPrinter end

new_log_printer(::Type{DefaultLogPrinter}) = DefaultLogPrinter()

function print_log(
    ::DefaultLogPrinter, sp::PrinterSearchSpace, node::PrintedNode, env, nb_untreated_nodes
)
    is_root_node = iszero(getdepth(node.inner))
    current_node_id = node.tree_order_id
    current_node_depth = getdepth(node.inner)
    current_parent_id = isnothing(get_parent(node)) ? nothing : get_parent(node).tree_order_id
    local_db = getvalue(get_ip_dual_bound(get_opt_state(node.inner)))
    global_db = getvalue(get_ip_dual_bound(sp.inner.optstate))
    global_pb = getvalue(get_ip_primal_bound(sp.inner.optstate))
    time = elapsed_optim_time(env)
    br_constr_description = get_branch_description(node.inner)

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

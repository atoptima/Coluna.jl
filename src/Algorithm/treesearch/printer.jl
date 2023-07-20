############################################################################################
# File printer API
############################################################################################

"Super type to dispatch on file printer methods."
abstract type AbstractFilePrinter end

@mustimplement "FilePrinter" new_file_printer(::Type{<:AbstractFilePrinter}, alg) = nothing
@mustimplement "FilePrinter" filename(::AbstractFilePrinter) = nothing
@mustimplement "FilePrinter" init_tree_search_file!(::AbstractFilePrinter) = nothing
@mustimplement "FilePrinter" print_node_in_tree_search_file!(::AbstractFilePrinter, node, space, env) = nothing
@mustimplement "FilePrinter" close_tree_search_file!(::AbstractFilePrinter) = nothing

############################################################################################
# Log printer API (on stdin)
############################################################################################

"Super type to dispatch on log printer method."
abstract type AbstractLogPrinter end

@mustimplement "LogPrinter" new_log_printer(::Type{<:AbstractLogPrinter}) = nothing
@mustimplement "LogPrinter" print_log(::AbstractLogPrinter, space, node, env, nb_untreated_nodes) = nothing

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
} <: TreeSearch.AbstractSearchSpace
    current_tree_order_id::Int
    log_printer::LogPrinter
    file_printer::FilePrinter
    inner::ColunaSearchSpace
end

"""
Node that contains the node of the Coluna's tree search algorithm for which we want to
print execution logs.
"""
struct PrintedNode{Node<:TreeSearch.AbstractNode} <: TreeSearch.AbstractNode
    tree_order_id::Int
    parent_tree_order_id::Union{Int, Nothing}
    inner::Node
end

TreeSearch.get_priority(explore::TreeSearch.AbstractExploreStrategy, n::PrintedNode) = TreeSearch.get_priority(explore, n.inner)

function TreeSearch.tree_search_output(sp::PrinterSearchSpace, untreated_nodes)
    close_tree_search_file!(sp.file_printer)
    return TreeSearch.tree_search_output(sp.inner, Iterators.map(n -> n.inner, untreated_nodes))
end

function TreeSearch.new_space(
    ::Type{PrinterSearchSpace{ColunaSearchSpace,LogPrinter,FilePrinter}}, alg, model, input
) where {
    ColunaSearchSpace<:AbstractColunaSearchSpace,
    LogPrinter<:AbstractLogPrinter,
    FilePrinter<:AbstractFilePrinter
}
    inner_space = TreeSearch.new_space(ColunaSearchSpace, alg, model, input)
    return PrinterSearchSpace(
        0, 
        new_log_printer(LogPrinter),
        new_file_printer(FilePrinter, alg),
        inner_space
    )
end

function TreeSearch.new_root(sp::PrinterSearchSpace, input)
    inner_root = TreeSearch.new_root(sp.inner, input)
    init_tree_search_file!(sp.file_printer)
    return PrintedNode(sp.current_tree_order_id+=1, nothing, inner_root)
end

_inner_node(n::PrintedNode) = n.inner # `untreated_node` is a stack.
_inner_node(n::Pair{<:PrintedNode, Float64}) = first(n).inner # `untreated_node` is a priority queue.

function TreeSearch.children(sp::PrinterSearchSpace, current, env, untreated_nodes)
    print_log(sp.log_printer, sp, current, env, length(untreated_nodes))
    children =  TreeSearch.children(sp.inner, current.inner, env, Iterators.map(_inner_node, untreated_nodes))
    # We print node information in the file after the node has been evaluated.
    print_node_in_tree_search_file!(sp.file_printer, current, sp, env)
    return map(children) do child
        return PrintedNode(sp.current_tree_order_id += 1, current.tree_order_id, child)
    end
end

TreeSearch.stop(sp::PrinterSearchSpace, untreated_nodes) = TreeSearch.stop(sp.inner, untreated_nodes)

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
# JSON file printer
############################################################################################
"""
File printer to create a JSON file of the branch and bound tree.
"""
struct JSONFilePrinter <: AbstractFilePrinter 
    filename::String
end

new_file_printer(::Type{JSONFilePrinter}, alg::TreeSearchAlgorithm) = JSONFilePrinter(alg.jsonfile)
filename(f::JSONFilePrinter) = f.filename

function init_tree_search_file!(f::JSONFilePrinter)
    open(filename(f), "w") do file
        println(file, "{")
        println(file, "\t\"nodes\": [")
    end
    return
end

function print_node_in_tree_search_file!(f::JSONFilePrinter, node::PrintedNode, sp::PrinterSearchSpace, env)
    is_root_node = iszero(getdepth(node.inner))
    current_node_id = node.tree_order_id
    current_node_depth = getdepth(node.inner)
    current_parent_id = node.parent_tree_order_id
    local_db = getvalue(node.inner.ip_dual_bound)
    global_db = getvalue(get_ip_dual_bound(sp.inner.optstate))
    global_pb = getvalue(get_ip_primal_bound(sp.inner.optstate))
    time = elapsed_optim_time(env)
    br_constr_description = TreeSearch.get_branch_description(node.inner)
    gap_closed = ip_gap_closed(node.inner.conquer_output)
    infeasible = getterminationstatus(node.inner.conquer_output) == INFEASIBLE

    open(filename(f), "r+") do file
        # rewind the closing brace character
        seekend(file)
        pos = position(file)
        seek(file, pos - 1)

        # start writing over this character
        @printf file "\n\t\t{\"node_id\": %i, " current_node_id
        @printf file "\"depth\": %i, " current_node_depth
        @printf file "\"parent_id\": %s, " is_root_node ? "null" : string(current_parent_id)
        @printf file "\"time\": %.0f, " time
        @printf file "\"primal_bound\": %.4f, " global_pb
        @printf file "\"local_dual_bound\": %.4f, " local_db
        @printf file "\"global_dual_bound\": %.4f, " global_db
        @printf file "\"pruned\": %s, " gap_closed ? "true" : "false"
        @printf file "\"infeasible\": %s, " infeasible ? "true" : "false"
        @printf file "\"branch\": \"%s\"}," is_root_node ? "null" : br_constr_description
    end
    return
end

function close_tree_search_file!(f::JSONFilePrinter)
    open(filename(f), "r+") do file
        # rewind the closing brace character
        seekend(file)
        pos = position(file)
        seek(file, pos - 1)
        # just move the closing brace to the next line
        println(file, "\n\t]")
        println(file, "}")
    end
    return
end

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

# TODO: fix
function print_node_in_tree_search_file!(f::DotFilePrinter, node::PrintedNode, sp::PrinterSearchSpace, env)
    ncur = node.tree_order_id
    depth = getdepth(node.inner)
    npar = node.parent_tree_order_id
    db = getvalue(node.inner.ip_dual_bound)
    pb = getvalue(get_ip_primal_bound(sp.inner.optstate))
    time = elapsed_optim_time(env)
    br_constr_description = TreeSearch.get_branch_description(node.inner)
    gap_closed = ip_gap_closed(node.inner.conquer_output)

    open(filename(f), "r+") do file
        # rewind the closing brace character
        seekend(file)
        pos = position(file)
        seek(file, pos - 1)

        # start writing over this character
        if gap_closed
            @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[PRUNED , %.4f]\"];" ncur ncur time pb
        else
            @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[%.4f , %.4f]\"];" ncur ncur time db pb
        end
        if depth > 0 # not root node
            @printf file "\n\tn%i -> n%i [label= \"%s\"];}" npar ncur br_constr_description
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
    current_parent_id = node.parent_tree_order_id
    local_db = getvalue(node.inner.ip_dual_bound)
    global_db = getvalue(get_ip_dual_bound(sp.inner.optstate))
    global_pb = getvalue(get_ip_primal_bound(sp.inner.optstate))
    time = elapsed_optim_time(env)
    br_constr_description = TreeSearch.get_branch_description(node.inner)

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

####################################################################
#                      Branch
####################################################################

struct Branch
    var_coeffs::Dict{VarId, Float64}
    rhs::Float64
    sense::ConstrSense
    depth::Int
end

function Branch(var::Variable, rhs::Float64, sense::ConstrSense, depth::Int)
    var_coeffs = Dict{VarId,Float64}()
    var_coeffs[getid(var)] = 1.0
    return Branch(var_coeffs, rhs, sense, depth)
end

get_var_coeffs(b::Branch) = b.var_coeffs
getrhs(b::Branch) = b.rhs
getsense(b::Branch) = b.sense
getdepth(b::Branch) = b.depth

function show(io::IO, branch::Branch, form::Formulation)
    for (id, coeff) in branch.var_coeffs
        print(io, " + ", coeff, " ", getname(form, id))
    end
    if branch.sense == Greater
        print(io, " >= ")
    else
        print(io, " <= ")
    end
    print(io, branch.rhs)
    return
end

apply_branch!(f::Reformulation, ::Nothing) = nothing

function apply_branch!(f::Reformulation, b::Branch)
    if b == Nothing
        return
    end
    @logmsg LogLevel(-1) "Adding branching constraint."
    @logmsg LogLevel(-2) "Apply Branch : " b
    sense = (getsense(b) == Greater ? "geq_" : "leq_")
    name = string("branch_", sense,  getdepth(b))
    # In master we define a branching constraint
    branch_constraint = setconstr!(
        f.master, name, MasterBranchOnOrigVarConstr; sense = getsense(b), rhs = getrhs(b),
        members = get_var_coeffs(b)
    )
    # # In subproblems we only change the bounds
    # # Problem: Only works if val == 1.0 !!! TODO: Fix this problem ?
    # for (id, val) in get_var_coeffs(b)
    #     # The following lines should be changed when we store the pointer to the vc represented by the representative
    #     owner_form = find_owner_formulation(f, getvar(f.master, id))
    #     if getuid(owner_form) != getuid(f.master)
    #         sp_var = getvar(owner_form, id)
    #         getsense(b) == Less && setub!(owner_form, sp_var, getrhs(b))
    #         getsense(b) == Greater && setlb!(owner_form, sp_var, getrhs(b))
    #     end
    #     @logmsg LogLevel(-2) "Branching constraint added : " branch_constraint
    # end
    return
end

####################################################################
#                      Node
####################################################################

# TO DO : LP primal solution (relaxation solution) should be moved
# from incumbents directly to Node
mutable struct Node #<: AbstractNode
    tree_order::Int
    istreated::Bool
    depth::Int
    parent::Union{Nothing, Node}
    #children::Vector{Node}
    incumbent_result::OptimizationResult
    branch::Union{Nothing, Branch} # branch::Id{Constraint}
    branchdescription::String
    #algorithm_results::Dict{AbstractAlgorithm,AbstractAlgorithmResult}
    conquerrecord::Union{Nothing, ConquerRecord}
    dividerecord::Union{Nothing, AbstractRecord}
    conquerwasrun::Bool
    infeasible::Bool
    #status::FormulationStatus
end

function RootNode(incumbresult::OptimizationResult, skipconquer::Bool)
    return Node(
        -1, false, 0, nothing, incumbresult, nothing,
        "", nothing, nothing, skipconquer, false
    )
end

function Node(parent::Node, branch::Branch, branchdescription::String)
    depth = getdepth(parent) + 1
    inc_res = deepcopy(getincumbentresult(parent))
    # Resetting lp primals because the lp can get worse during the algorithms,
    # thus not being updated in the node and breaking the branching
    inc_res.lp_primal_sols = nothing
    
    return Node(
        -1, false, depth, parent, inc_res, branch, branchdescription, 
        parent.conquerrecord, parent.dividerecord, false, false
    )
end

# this function creates a child node by copying info from another child
# used in strong branching
function Node(parent::Node, child::Node)
    depth = getdepth(parent) + 1
    inc_res = deepcopy(getincumbentresult(child))
    return Node(
        -1, false, depth, parent, inc_res, nothing, child.branchdescription,
        child.conquerrecord, child.dividerecord, false, false
    )
end

get_tree_order(n::Node) = n.tree_order
set_tree_order!(n::Node, tree_order::Int) = n.tree_order = tree_order
getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getincumbents(n::Node) = n.incumbent_result.incumbents
getincumbentresult(n::Node) = n.incumbent_result
getbranch(n::Node) = n.branch
addchild!(n::Node, child::Node) = push!(n.children, child)
settreated!(n::Node) = n.istreated = true
istreated(n::Node) = n.istreated
isrootnode(n::Node) = n.tree_order == 1
getinfeasible(n::Node) = n.infesible
setinfeasible(n::Node, status::Bool) = n.infeasible = status

function to_be_pruned(node::Node)
    node.infeasible && return true
    incres = getincumbentresult(node)
    bounds_ratio = get_ip_primal_bound(incres) / get_ip_dual_bound(incres)
    return isapprox(bounds_ratio, 1) || ip_gap(incres) < 0
end

function to_be_pruned(node::Node, ip_primal_bound::PrimalBound)
    node.infeasible && return true
    incres = getincumbentresult(node)
    bounds_ratio = ip_primal_bound / get_ip_dual_bound(incres)
    return isapprox(bounds_ratio, 1) || ip_gap(incres) < 0
end

# returns the optimization part of the output of the conquer algorithm 
function apply_conquer_alg_to_node!(
    node::Node, algo::AbstractConquerAlgorithm, 
    reform::Reformulation, result::OptimizationResult
)::OptimizationOutput

    node_inc_res = getincumbentresult(node)

    # should reset lp bound here ? Maybe in the Node constructor ?
    update_ip_primal_bound!(node_inc_res, get_ip_primal_bound(result))
    set_lp_primal_bound!(node_inc_res, PrimalBound(getmaster(reform)))
    
    if isverbose(algo)
        @logmsg LogLevel(-1) string("Node IP DB: ", get_ip_dual_bound(getincumbents(node)))
        @logmsg LogLevel(-1) string("Tree IP PB: ", get_ip_primal_bound(getincumbents(node)))
    end
    if (ip_gap(getincumbents(node)) <= 0.0 + 0.00000001)
        isverbose(algo) && @logmsg LogLevel(-1) string(
            "IP Gap is non-positive: ", ip_gap(getincumbents(node)), ". Abort treatment."
        )
        node.conquerrecord = nothing
        return OptimizationOutput(getincumbentresult(node))
    end
    isverbose(algo) && @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")

    prepare!(reform, node.conquerrecord)    
    node.conquerrecord = nothing

    # TO DO : get rid of Branch 
    apply_branch!(reform, getbranch(node))

    conqueroutput = run!(
        algo, reform, ConquerInput(getincumbentresult(node), isrootnode(node))
    )

    node.conquerwasrun = true

    # update of node incumbents
    optoutput = getoptoutput(conqueroutput)

    # update of tree search algorithm primal solutions 
    optoutputres = getresult(optoutput)
    if nb_ip_primal_sols(optoutputres) > 0
        for ip_primal_sol in get_ip_primal_sols(optoutputres)
            add_ip_primal_sol!(result, deepcopy(ip_primal_sol))
        end    
    end    
    !isfeasible(optoutputres) && setinfeasible(node, true)
    if !to_be_pruned(node) 
        node.conquerrecord = getrecord(conqueroutput)
    end

    update_ip_primal_bound!(node_inc_res, get_ip_primal_bound(optoutputres))
    update_ip_dual_bound!(node_inc_res, get_ip_dual_bound(optoutputres))
    update_lp_primal_bound!(node_inc_res, get_lp_primal_bound(optoutputres))
    update_lp_dual_bound!(node_inc_res, get_lp_dual_bound(optoutputres))

    if nb_lp_primal_sols(optoutputres) > 0
        add_lp_primal_sol!(node_inc_res, get_best_lp_primal_sol(optoutputres))
        #set_lp_primal_bound!(node_inc_res, get_lp_primal_bound(optoutputres))
    end
    return optoutput
end

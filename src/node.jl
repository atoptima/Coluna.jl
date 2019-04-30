struct Branch
    var_coeffs::Dict{VarId, Float64}
    rhs::Float64
    sense::ConstrSense
    depth::Int
end
Branch(varid::VarId, rhs, sense, depth) = Branch(Dict(varid => 1.0), rhs, sense, depth)
get_var_coeffs(b::Branch) = b.var_coeffs
getrhs(b::Branch) = b.rhs
getsense(b::Branch) = b.sense
getdepth(b::Branch) = b.depth

function show(io::IO, branch::Branch, form::Formulation)
    for (id, coeff) in branch.var_coeffs
        print(io, " + ", coeff, " ", getname(getelem(form, id)))
    end
    if branch.sense == Greater
        print(io, " >= ")
    else
        print(io, " <= ")
    end
    print(io, branch.rhs)
    return
end

struct NodeRecord
    active_vars::Dict{VarId, VarData}
    active_constrs::Dict{ConstrId, ConstrData}
end
NodeRecord() = NodeRecord(Dict{VarId, VarData}(), Dict{ConstrId, ConstrData}())

mutable struct Node <: AbstractNode
    treat_order::Int
    depth::Int
    parent::Union{Nothing, Node}
    children::Vector{Node}
    incumbents::Incumbents
    branch::Union{Nothing, Branch} # branch::Id{Constraint}
    solver_records::Dict{Type{<:AbstractSolver},AbstractSolverRecord}
    record::NodeRecord
end

function RootNode(ObjSense::Type{<:AbstractObjSense})
    return Node(
        -1, 0, nothing, Node[], Incumbents(ObjSense), nothing,
        Dict{Type{<:AbstractSolver},AbstractSolverRecord}(),
        NodeRecord()
    )
end

function Node(parent::Node, branch::Branch)
    depth = getdepth(parent) + 1
    incumbents = deepcopy(getincumbents(parent))
    return Node(
        -1, depth, parent, Node[], incumbents, branch,
        Dict{Type{<:AbstractSolver},AbstractSolverRecord}(),
        NodeRecord()
    )
end

get_treat_order(n::Node) = n.treat_order
getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getincumbents(n::Node) = n.incumbents
getbranch(n::Node) = n.branch
addchild!(n::Node, child::Node) = push!(n.children, child)
set_treat_order!(n::Node, treat_order::Int) = n.treat_order = treat_order

function set_solver_record!(n::Node, S::Type{<:AbstractSolver}, 
                            r::AbstractSolverRecord)
    n.solver_records[S] = r
end
get_solver_record!(n::Node, S::Type{<:AbstractSolver}) = n.solver_records[S]

function to_be_pruned(n::Node)
    # How to determine if a node should be pruned?? By the lp_gap?
    lp_gap(n.incumbents) <= 0.0000001 && return true
    return false
end

function record!(reform::Reformulation, node::Node)
    # TODO : nested decomposition
    return record!(getmaster(reform), node)
end

function record!(form::Formulation, node::Node)
    active_vars = Dict{VarId, VarData}()
    for (id, var) in getvars(form)
        if get_cur_is_active(var)
            active_vars[id] = deepcopy(getcurdata(var))
        end
    end
    active_constrs = Dict{ConstrId, ConstrData}()
    for (id, constr) in getconstrs(form)
        if get_cur_is_active(constr)
            active_constrs[id] = deepcopy(getcurdata(constr))
        end
    end
    node.record = NodeRecord(active_vars, active_constrs)
    return
end

function setup!(f::Reformulation, n::Node)
    println("Setup for reformulation is under construction.")
    # For now, we do setup only in master
    setup!(f.master, n)
    return
end

function setup!(f::Formulation, n::Node)
    reset_to_record_state!(f, getparent(n))
    apply_branch!(f, getbranch(n))
end

function apply_branch!(f::Formulation, b::Branch)
    sense = (b.sense == Greater ? "geq_" : "leq_")
    name = string("branch_", sense,  getdepth(b))
    branch_constraint = setconstr!(
        f, name, MasterBranchConstr; rhs = getrhs(b), members = get_var_coeffs(b)
    )
    return
end

function reset_to_record_state!(f::Formulation, n::Node)
    active_vars = n.record.active_vars
    active_constrs = n.record.active_constrs
    # Checking vars that are in formulation but should not be
    for (id, var) in filter(_active_, getvars(f))
        !haskey(active_vars, id) && deactivatevar!(f, var)
    end
    # Checking constrs that are in formulation but should not be
    for (id, constr) in filter(_active_, getconstrs(f))
        !haskey(active_constrs, id) && deactivatevar!(f, constr)
    end
    # Checking vars that should be in formulation but are not
    for (id, data) in active_vars
        var = getvar(f, id)
        !get_cur_is_active(var) && continue
        activatevar!(f, var)
    end
    # Checking constrs that should be in formulation but are not
    for (id, data) in active_constrs
        constr = getconstr(f, id)
        !get_cur_is_active(constr) && continue
        activateconstr!(f, constr)
    end
    return
end

# Nothing happens if this function is called for a node with not branch
apply_branch!(f::Formulation, ::Nothing) = nothing

# Nothing happens if this function is called for the "father" of the root node
reset_to_record_state!(f::Formulation, ::Nothing) = nothing

struct Branch
    var_coeffs::MembersVector{Id{Variable}, Variable, Float64}
    rhs::Float64
    sense::ConstrSense
    depth::Int
end
function Branch(var::Variable, rhs::Float64, sense::ConstrSense, depth::Int)
    var_coeffs = MembersVector{Float64}(Dict(getid(var) => var))
    var_coeffs[getid(var)] = 1.0
    return Branch(var_coeffs, rhs, sense, depth)
end

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

mutable struct FormulationStatus
    need_to_prepare::Bool
end
FormulationStatus() = FormulationStatus(true)

mutable struct Node <: AbstractNode
    treat_order::Int
    depth::Int
    parent::Union{Nothing, Node}
    children::Vector{Node}
    incumbents::Incumbents
    branch::Union{Nothing, Branch} # branch::Id{Constraint}
    algorithm_records::Dict{Type{<:AbstractAlgorithm},AbstractAlgorithmRecord}
    record::NodeRecord
    statuses::FormulationStatus
end

function RootNode(ObjSense::Type{<:AbstractObjSense})
    return Node(
        -1, 0, nothing, Node[], Incumbents(ObjSense), nothing,
        Dict{Type{<:AbstractAlgorithm},AbstractAlgorithmRecord}(),
        NodeRecord(), FormulationStatus()
    )
end

function Node(parent::Node, branch::Branch)
    depth = getdepth(parent) + 1
    incumbents = deepcopy(getincumbents(parent))
    # Resetting lp primals because the lp can get worse during the algorithms,
    # thus not being updated in the node and breaking the branching
    incumbents.lp_primal_sol = typeof(incumbents.lp_primal_sol)()
    return Node(
        -1, depth, parent, Node[], incumbents, branch,
        Dict{Type{<:AbstractAlgorithm},AbstractAlgorithmRecord}(),
        NodeRecord(), FormulationStatus()
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

function set_algorithm_record!(n::Node, S::Type{<:AbstractAlgorithm}, 
                            r::AbstractAlgorithmRecord)
    n.algorithm_records[S] = r
end
get_algorithm_record!(n::Node, S::Type{<:AbstractAlgorithm}) = n.algorithm_records[S]

function to_be_pruned(n::Node)
    # How to determine if a node should be pruned?? By the lp_gap?
    lp_gap(n.incumbents) <= 0.0000001 && return true
    ip_gap(n.incumbents) <= 0.0000001 && return true
    return false
end

function record!(reform::Reformulation, node::Node)
    # TODO : nested decomposition
    node.statuses.need_to_prepare = true
    return record!(getmaster(reform), node)
end

function record!(form::Formulation, node::Node)
    @logmsg LogLevel(0) "Recording reformulation state after solving node."
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

function prepare!(f::Reformulation, n::Node)
    @logmsg LogLevel(0) "Setting up Reformulation before appling strategy on node."
    !n.statuses.need_to_prepare && return
    # For now, we do setup only in master
    @logmsg LogLevel(-1) "Setup on master."
    reset_to_record_state_of_father!(f, getparent(n))
    apply_branch!(f, getbranch(n))
    n.statuses.need_to_prepare = false
    return
end

function apply_branch!(f::Reformulation, b::Branch)
    @logmsg LogLevel(-1) "Adding branching constraint."
    @logmsg LogLevel(-2) "Apply Branch : " b
    sense = (getsense(b) == Greater ? "geq_" : "leq_")
    name = string("branch_", sense,  getdepth(b))
    # In master we define a branching constraint
    branch_constraint = setconstr!(
        f.master, name, MasterBranchConstr; sense = getsense(b), rhs = getrhs(b),
        members = get_var_coeffs(b)
    )
    # In subproblems we only change the bounds
    # Problem: Only works if val == 1.0 !!! TODO: Fix this problem ?
    for (id, val) in get_var_coeffs(b)
        # The following lines should be changed when we store the pointer to the vc represented by the representative
        owner_form = find_owner_formulation(f, getvar(f.master, id))
        if getuid(owner_form) != getuid(f.master)
            sp_var = getvar(owner_form, id)
            getsense(b) == Less && setub!(owner_form, sp_var, getrhs(b))
            getsense(b) == Greater && setlb!(owner_form, sp_var, getrhs(b))
        end
        @logmsg LogLevel(-2) "Branching constraint added : " branch_constraint
    end
    return
end

function reset_to_record_state_of_father!(reform::Reformulation, n::Node)
    @logmsg LogLevel(-1) "Reset the formulation to the state left by the parent node."
    active_vars = n.record.active_vars
    active_constrs = n.record.active_constrs
    master = getmaster(reform)
    # Checking vars that are in formulation but should not be
    for (id, var) in filter(_active_, getvars(master))
        if !haskey(active_vars, id)
            @logmsg LogLevel(0) "Deactivating variable " getname(var)
            deactivate!(reform, id)
        end
    end
    # Checking constrs that are in formulation but should not be
    for (id, constr) in filter(_active_, getconstrs(master))
        if !haskey(active_constrs, id)
            @logmsg LogLevel(-2) "Deactivating constraint " getname(constr)
            deactivate!(reform, id)
        end
    end
    # Checking vars that should be active in formulation but are not
    for (id, data) in active_vars
        var = getvar(master, id)
        owner_form = find_owner_formulation(reform, var)
        # Reset bounds # TODO: Reset costs
        if (getcurlb(getvar(owner_form, id)) != getlb(data)
            || getcurub(getvar(owner_form, id)) != getub(data))
            @logmsg LogLevel(-2) string("Reseting bounds of variable ", getname(var))
            setlb!(owner_form, getvar(owner_form, id), getlb(data))
            setub!(owner_form, getvar(owner_form, id), getub(data))
            @logmsg LogLevel(-3) string("New lower bound is ", getcurlb(var))
            @logmsg LogLevel(-3) string("New upper bound is ", getcurub(var))
        end
        if !get_cur_is_active(var) # Nothing to do if var is already active
            @logmsg LogLevel(-2) "Activating variable " getname(var)
            activate!(reform, var)
        end
    end
    # Checking constrs that should be active in formulation but are not
    for (id, data) in active_constrs
        constr = getconstr(master, id)
        # TODO: reset rhs
        get_cur_is_active(constr) && continue # Nothing to do if constr is already acitve
        @logmsg LogLevel(-2) "Activating constraint " getname(constr)
        activate!(reform, constr)
    end
    return
end

# Nothing happens if this function is called for a node with not branch
apply_branch!(f::Reformulation, ::Nothing) = nothing

# Nothing happens if this function is called for the "father" of the root node
reset_to_record_state_of_father!(f::Reformulation, ::Nothing) = nothing

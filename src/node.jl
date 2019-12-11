struct Branch
    var_coeffs::PrimalSolVector
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
    proven_infeasible::Bool
end
FormulationStatus() = FormulationStatus(true, false)

mutable struct Node <: AbstractNode
    treat_order::Int
    istreated::Bool
    depth::Int
    parent::Union{Nothing, Node}
    children::Vector{Node}
    incumbents::Incumbents
    branch::Union{Nothing, Branch} # branch::Id{Constraint}
    branchdescription::String
    algorithm_results::Dict{AbstractAlgorithm,AbstractAlgorithmResult}
    record::NodeRecord
    status::FormulationStatus
end

function RootNode(ObjSense::Type{<:AbstractObjSense})
    return Node(
        -1, false, 0, nothing, Node[], Incumbents(ObjSense), nothing,
        "", Dict{Type{<:AbstractAlgorithm},AbstractAlgorithmResult}(),
        NodeRecord(), FormulationStatus()
    )
end

function Node(parent::Node, branch::Branch, branchdescription::String)
    depth = getdepth(parent) + 1
    incumbents = deepcopy(getincumbents(parent))
    # Resetting lp primals because the lp can get worse during the algorithms,
    # thus not being updated in the node and breaking the branching
    incumbents.lp_primal_sol = typeof(incumbents.lp_primal_sol)()
    return Node(
        -1, false, depth, parent, Node[], incumbents, branch, branchdescription, 
        Dict{Type{<:AbstractAlgorithm},AbstractAlgorithmResult}(),
        parent.record, FormulationStatus()
    )
end

# this function creates a child node by copying info from another child
# used in strong branching
function Node(parent::Node, child::Node)
    depth = getdepth(parent) + 1
    incumbents = deepcopy(getincumbents(child))
    return Node(
        -1, false, depth, parent, Node[], incumbents, nothing, child.branchdescription,
        Dict{Type{<:AbstractAlgorithm},AbstractAlgorithmResult}(),
        child.record, FormulationStatus()
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
settreated!(n::Node) = n.istreated = true
istreated(n::Node) = n.istreated

function set_algorithm_result!(n::Node, algo::AbstractAlgorithm, 
                            r::AbstractAlgorithmResult)
    n.algorithm_results[algo] = r
end
get_algorithm_result!(n::Node, algo::AbstractAlgorithm) = n.algorithm_results[algo]

function to_be_pruned(n::Node)
    # How to determine if a node should be pruned?? By the lp_gap?
    n.status.proven_infeasible && return true
    ip_gap(n.incumbents) <= 0.0000001 && return true
    return false
end

function isfertile(n::Node)
    ip_gap(getincumbents(n)) <= 0.0 && return false
    isinteger(get_lp_primal_sol(getincumbents(n))) && return false
    return true
end

function record!(reform::Reformulation, node::Node)
    @logmsg LogLevel(0) "Recording reformulation state after solving node."
    node.status.need_to_prepare = true
    recorded_info = NodeRecord()
    add_to_recorded!(reform, recorded_info)
    node.record = recorded_info
    settreated!(node)
    return
end

function add_to_recorded!(reform::Reformulation, recorded_info::NodeRecord)
    @logmsg LogLevel(0) "Recording master info."
    add_to_recorded!(getmaster(reform), recorded_info)
    for sp in reform.dw_pricing_subprs
        @logmsg LogLevel(0) string("Recording sp ", getuid(sp), " info.")
        add_to_recorded!(sp, recorded_info)
    end
    return
end

function add_to_recorded!(form::Formulation, recorded_info::NodeRecord)
    for (id, var) in getvars(form)
        if get_cur_is_active(var) && get_cur_is_explicit(var)
            recorded_info.active_vars[id] = deepcopy(getcurdata(var))
        end
    end
    active_constrs = Dict{ConstrId, ConstrData}()
    for (id, constr) in getconstrs(form)
        if get_cur_is_active(constr) && get_cur_is_explicit(constr)
            recorded_info.active_constrs[id] = deepcopy(getcurdata(constr))
        end
    end
    return
end

function prepare!(f::Reformulation, n::Node)
    @logmsg LogLevel(0) "Setting up Reformulation before applying or algorithm."
    if !n.status.need_to_prepare
        @logmsg LogLevel(0) "Formulation is up-to-date, aborting preparation."
        return
    end
    @logmsg LogLevel(-1) "Setup on master."
    if getdepth(n) > 0
        reset_to_record_state!(f, n.record)
    end
    apply_branch!(f, getbranch(n))
    n.status.need_to_prepare = false
    return
end

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

function reset_to_record_state!(reform::Reformulation, record::NodeRecord)
    @logmsg LogLevel(0) "Resetting reformulation state to node record"
    @logmsg LogLevel(0) "Resetting reformulation master state"
    reset_to_record_state!(getmaster(reform), record)
    for sp in reform.dw_pricing_subprs
        @logmsg LogLevel(0) string("Resetting sp ", getuid(sp), " state.")
        reset_to_record_state!(sp, record)
    end
    return
end

function apply_data!(form::Formulation, var::Variable, var_data::VarData)
    # Bounds
    if getcurlb(var) != getlb(var_data) || getcurub(var) != getub(var_data)
        @logmsg LogLevel(-2) string("Reseting bounds of variable ", getname(var))
        setlb!(form, var, getlb(var_data))
        setub!(form, var, getub(var_data))
        @logmsg LogLevel(-3) string("New lower bound is ", getcurlb(var))
        @logmsg LogLevel(-3) string("New upper bound is ", getcurub(var))
    end
    # Cost
    if getcurcost(var) != getcost(var_data)
        @logmsg LogLevel(-2) string("Reseting cost of variable ", getname(var))
        setcost!(form, var, getcost(var_data))
        @logmsg LogLevel(-3) string("New cost is ", getcurcost(var))
    end
    return
end

function apply_data!(form::Formulation, constr::Constraint, constr_data::ConstrData)
    # Rhs
    if getcurrhs(constr) != getrhs(constr_data)
        @logmsg LogLevel(-2) string("Reseting rhs of constraint ", getname(constr))
        setrhs!(form, constr, getrhs(constr_data))
        @logmsg LogLevel(-3) string("New rhs is ", getcurrhs(constr))
    end
    return
end

function reset_to_record_state!(form::Formulation, record::NodeRecord)
    @logmsg LogLevel(-2) "Checking variables"
    reset_var_constr!(form, record.active_vars, getvars(form))
    @logmsg LogLevel(-2) "Checking constraints"
    reset_var_constr!(form, record.active_constrs, getconstrs(form))
    return
end

function reset_var_constr!(form::Formulation, active_var_constrs, var_constrs_in_formulation)
    for (id, vc) in var_constrs_in_formulation
        @logmsg LogLevel(-4) "Checking " getname(vc)
        # vc should NOT be active but is active in formulation
        if !haskey(active_var_constrs, id) && get_cur_is_active(vc)
            @logmsg LogLevel(-4) "Deactivating"
            deactivate!(form, id)
            continue
        end
        # vc should be active in formulation
        if haskey(active_var_constrs, id)
            # But var_constr is currently NOT active in formulation
            if !get_cur_is_active(vc)
                @logmsg LogLevel(-4) "Activating"
                activate!(form, vc)
            end
            # After making sure that var activity is up-to-date
            @logmsg LogLevel(-4) "Updating data"
            apply_data!(form, vc, active_var_constrs[id])
        end
    end
    return
end

# Nothing happens if this function is called for a node with not branch
apply_branch!(f::Reformulation, ::Nothing) = nothing

# Nothing happens if this function is called for the "father" of the root node
reset_to_record_state!(f::Reformulation, ::Nothing) = nothing

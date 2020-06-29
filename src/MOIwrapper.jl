const CleverDicts = MOI.Utilities.CleverDicts

const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64},
    MOI.SingleVariable}

const SupportedVarSets = Union{MOI.ZeroOne, MOI.Integer, MOI.LessThan{Float64},
    MOI.EqualTo{Float64}, MOI.GreaterThan{Float64}}

const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedConstrSets = Union{MOI.EqualTo{Float64}, MOI.GreaterThan{Float64},
    MOI.LessThan{Float64}}

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Problem
    moi_index_to_coluna_uid::MOIU.IndexMap
    params::Params
    annotations::Annotations
    #varmap::Dict{MOI.VariableIndex,VarId} # For the user to get VariablePrimal
    vars::CleverDicts.CleverDict{MOI.VariableIndex, Variable}
    constrs::Dict{MOI.ConstraintIndex, Constraint}
    result::Union{Nothing,OptimizationState}
end

function Optimizer()
    prob = Problem()
    return Optimizer(
        prob, MOIU.IndexMap(), Params(), Annotations(),
        CleverDicts.CleverDict{MOI.VariableIndex, Variable}(),
        Dict{MOI.ConstraintIndex, Constraint}(), nothing
    )
end

MOI.Utilities.supports_default_copy_to(::Coluna.Optimizer, ::Bool) = true
MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{<:MOI.ConstraintIndex}) = true
MOI.supports_constraint(::Optimizer, ::Type{<:SupportedConstrFunc}, ::Type{<:SupportedConstrSets}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{<: SupportedVarSets}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{<:SupportedObjFunc}) = true

# Parameters
function MOI.set(model::Optimizer, param::MOI.RawParameter, val)
    if param.name == "params"
        model.params = val
    elseif param.name == "default_optimizer"
        optimizer_builder = () -> MoiOptimizer(val())
        model.inner.default_optimizer_builder = optimizer_builder
    else
        @warn("Unknown parameter $(param.name).")
    end
    return
end

function _get_orig_varid(optimizer::Optimizer, x::MOI.VariableIndex)
    origid = get(optimizer.varmap, x, nothing)
    if origid === nothing
        msg = """
        Cannot find JuMP variable with MOI index $x in original formulation of Coluna.
        Are you sure this variable is attached to the JuMP model ?
        """
        error(msg)
    end
    return origid
end

function _get_orig_varid_in_form(
    optimizer::Optimizer, form::Formulation, x::MOI.VariableIndex
)
    origid = _get_orig_varid(optimizer, x)
    return getid(getvar(form, origid))
end

function MOI.optimize!(optimizer::Optimizer)
    optimizer.result = optimize!(
        optimizer.inner, optimizer.annotations, optimizer.params
    )
    return
end

function register_original_formulation!(
    dest::Optimizer, src::MOI.ModelLike, copy_names::Bool
)
    #register_callback!(orig_form, src, MOI.UserCutCallback())
    return
end

function MOI.copy_to(dest::Coluna.Optimizer, src::MOI.ModelLike; kwargs...)
    @show kwargs
    error("Stack")
    return MOI.Utilities.automatic_copy_to(dest, src; kwargs...)
end

# Add variables
function MOI.add_variable(model::Coluna.Optimizer)
    orig_form = get_original_formulation(model.inner)
    var = setvar!(orig_form, "v", OriginalVar)
    index = CleverDicts.add_item(model.vars, var)
    return index
end

# Add constraint
function MOI.add_constraint(
    model::Coluna.Optimizer, func::MOI.SingleVariable, ::MOI.ZeroOne
)
    orig_form = get_original_formulation(model.inner)
    var = model.vars[func.variable]
    # set perene data
    var.perendata.kind = Binary
    var.curdata.kind = Binary
    var.perendata.lb = 0.0
    var.curdata.lb = 0.0
    var.perendata.ub = 1.0
    var.curdata.ub = 1.0
    return MOI.ConstraintIndex{MOI.SingleVariable, MOI.ZeroOne}(func.variable.value)
end

function MOI.add_constraint(
    model::Coluna.Optimizer, func::MOI.SingleVariable, ::MOI.Integer
)
    orig_form = get_original_formulation(model.inner)
    var = model.vars[func.variable]
    # set perene data
    var.perendata.kind = Integ
    var.curdata.kind = Integ
    return MOI.ConstraintIndex{MOI.SingleVariable, MOI.Integer}(func.variable.value)
end

function MOI.add_constraint(
    model::Coluna.Optimizer, func::MOI.ScalarAffineFunction{Float64}, set::S
) where {S<:SupportedConstrSets}
    orig_form = get_original_formulation(model.inner)
    members = Dict{VarId, Float64}()
    for term in func.terms
        var = model.vars[term.variable_index]
        members[getid(var)] = term.coefficient
    end
    constr = setconstr!(
        orig_form, "c", OriginalConstr;
        rhs = convert_moi_rhs_to_coluna(set),
        kind = Essential,
        sense = convert_moi_sense_to_coluna(set),
        inc_val = 10.0,
        members = members
    )
    constrid =  MOI.ConstraintIndex{typeof(func), typeof(set)}(length(model.constrs))
    model.constrs[constrid] = constr
    return constrid
end

# Attributes of variables
function MOI.set(
    model::Coluna.Optimizer, ::BD.VariableDecomposition, varid::MOI.VariableIndex,
    annotation::BD.Annotation
)
    store!(model.annotations, annotation, model.vars[varid])
    return
end

function MOI.set(
    model::Coluna.Optimizer, ::MOI.VariableName, varid::MOI.VariableIndex, name::String
)
    var = model.vars[varid]
    # set perene name
    var.name = name
    return
end

# Attributes of constraints
function MOI.set(
    model::Coluna.Optimizer, ::BD.ConstraintDecomposition, constrid::MOI.ConstraintIndex,
    annotation::BD.Annotation
)
    constr = get(model.constrs, constrid, nothing)
    if constr !== nothing
        store!(model.annotations, annotation, model.constrs[constrid])
    end
    return
end

function MOI.set(
    model::Coluna.Optimizer, ::MOI.ConstraintName, constrid::MOI.ConstraintIndex, name::String
)
    constr = model.constrs[constrid]
    # set perene name
    constr.name = name
    return
end

# Objective
function MOI.set(model::Coluna.Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    orig_form = get_original_formulation(model.inner)
    min_sense = (sense == MOI.MIN_SENSE)
    set_objective_sense!(orig_form, min_sense)
    return
end

function MOI.set(
    model::Coluna.Optimizer, ::MOI.ObjectiveFunction{F}, func::F
) where {F<:MOI.ScalarAffineFunction{Float64}}
    for term in func.terms
        var = model.vars[term.variable_index]
        cost = term.coefficient
        # set peren cost 
        var.perendata.cost = cost
        var.curdata.cost = cost
    end
    return
end

# Attributes of model
function MOI.set(model::Coluna.Optimizer, ::BD.DecompositionTree, tree::BD.Tree)
    model.annotations.tree = tree
    return
end

function MOI.set(model::Coluna.Optimizer, ::BD.ObjectiveDualBound, db)
    set_initial_dual_bound!(model.inner, db)
    return
end

function MOI.set(model::Coluna.Optimizer, ::BD.ObjectivePrimalBound, pb)
    set_initial_primal_bound!(model.inner, pb)
    return
end

function MOI.empty!(optimizer::Optimizer)
    optimizer.inner.re_formulation = nothing
end

# ######################
# ### Get functions ####
# ######################

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.inner === nothing || optimizer.inner.re_formulation === nothing
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveBound)
    return getvalue(get_ip_dual_bound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    return getvalue(get_ip_primal_bound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, ref::MOI.VariableIndex)
    id = getid(optimizer.vars[ref]) # This gets a coluna Id{Variable}
    best_primal_sol = get_best_ip_primal_sol(optimizer.result)
    if best_primal_sol === nothing
        @warn "Coluna did not find a primal feasible solution."
        return NaN
    end
    return get(best_primal_sol, id, 0.0)
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, refs::Vector{MOI.VariableIndex})
    best_primal_sol = get_best_ip_primal_sol(optimizer.result)
    if best_primal_sol === nothing
        @warn "Coluna did not find a primal feasible solution."
        return [NaN for ref in refs]
    end
    return [get(best_primal_sol, getid(optimizer.vars[ref]), 0.0) for ref in refs]
end

function MOI.get(optimizer::Optimizer, object::MOI.TerminationStatus)
    result = optimizer.result
    isfeasible(result) && return convert_status(getterminationstatus(result))
    getfeasibilitystatus(result) == INFEASIBLE && return MOI.INFEASIBLE
    getfeasibilitystatus(result) == UNKNOWN_FEASIBILITY && return MOI.OTHER_LIMIT
    error(string(
        "Could not determine MOI status. Coluna termination : ",
        getterminationstatus(result), ". Coluna feasibility : ",
        getfeasibilitystatus(result)
    ))
    return
end

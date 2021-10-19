const CleverDicts = MOI.Utilities.CleverDicts

const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64}, MOI.SingleVariable}

const SupportedVarSets = Union{
    MOI.ZeroOne, MOI.Integer, MOI.LessThan{Float64}, MOI.EqualTo{Float64}, 
    MOI.GreaterThan{Float64}
}

const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}

const SupportedConstrSets = Union{
    MOI.EqualTo{Float64}, MOI.GreaterThan{Float64}, MOI.LessThan{Float64}
}

@enum(ObjectiveType, SINGLE_VARIABLE, SCALAR_AFFINE)

# Helper for SingleVariable constraints
struct BoundConstraints
    varid::VarId
    lower::Union{Nothing,SingleVarConstraint}
    upper::Union{Nothing,SingleVarConstraint}
    eq::Union{Nothing,SingleVarConstraint}
end

setname!(bc, set_type, name) = nothing # Fallback
setname!(bc, ::Type{<:MOI.ZeroOne}, name) = bc.lower.name = bc.upper.name = name
setname!(bc, ::Type{<:MOI.GreaterThan}, name) = bc.lower.name = name
setname!(bc, ::Type{<:MOI.LessThan}, name) = bc.upper.name = name
setname!(bc, ::Type{<:MOI.EqualTo}, name) = bc.eq.name = name
setname!(bc, ::Type{<:MOI.Interval}, name) = bc.lower.name = bc.upper.name = name

setrhs!(bc, s::MOI.GreaterThan) = bc.lower.perendata.rhs = bc.lower.curdata.rhs = s.lower
setrhs!(bc, s::MOI.LessThan) = bc.upper.perendata.rhs = bc.upper.curdata.rhs = s.upper
setrhs!(bc, s::MOI.EqualTo) = bc.eq.perendata.rhs = bc.eq.curdata.rhs = s.value

function setrhs!(bc, s::MOI.Interval)
    bc.lower.perendata.rhs = bc.lower.curdata.rhs = s.lower
    bc.upper.perendata.rhs = bc.upper.curdata.rhs = s.upper
    return
end

mutable struct Optimizer <: MOI.AbstractOptimizer
    env::Env
    inner::Problem
    objective_type::ObjectiveType
    annotations::Annotations
    vars::CleverDicts.CleverDict{MOI.VariableIndex, Variable}
    moi_varids::Dict{VarId, MOI.VariableIndex}
    names_to_vars::Dict{String, MOI.VariableIndex}
    constrs::Dict{MOI.ConstraintIndex, Constraint}
    constrs_on_single_var::Dict{MOI.ConstraintIndex, BoundConstraints}
    names_to_constrs::Dict{String, MOI.ConstraintIndex}
    result::OptimizationState
    disagg_result::Union{Nothing, OptimizationState}
    default_optimizer_builder::Union{Nothing, Function}

    feasibility_sense::Bool # Coluna supports only Max or Min.

    function Optimizer()
        model = new()
        model.env = Env(Params())
        model.inner = Problem(model.env)
        model.annotations = Annotations()
        model.vars = CleverDicts.CleverDict{MOI.VariableIndex, Variable}()
        model.moi_varids = Dict{VarId, MOI.VariableIndex}()
        model.names_to_vars = Dict{String, MOI.VariableIndex}()
        model.constrs = Dict{MOI.ConstraintIndex, Constraint}()
        model.constrs_on_single_var = Dict{MOI.ConstraintIndex, BoundConstraints}()
        model.names_to_constrs = Dict{String, MOI.ConstraintIndex}()
        model.result = OptimizationState(get_optimization_target(model.inner))
        model.disagg_result = nothing
        model.default_optimizer_builder = nothing
        model.feasibility_sense = false
        return model
    end
end

MOI.Utilities.supports_default_copy_to(::Optimizer, ::Bool) = true
MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{<:MOI.ConstraintIndex}) = true
MOI.supports_constraint(::Optimizer, ::Type{<:SupportedConstrFunc}, ::Type{<:SupportedConstrSets}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{<: SupportedVarSets}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{<:SupportedObjFunc}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ConstraintPrimalStart) = false
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart) = false
MOI.supports(::Optimizer, ::BlockDecomposition.ConstraintDecomposition) = true
MOI.supports(::Optimizer, ::BlockDecomposition.VariableDecomposition) = true

# Parameters
function MOI.set(model::Optimizer, param::MOI.RawParameter, val)
    if param.name == "params"
        model.env.params = val
    elseif param.name == "default_optimizer"
        optimizer_builder = () -> MoiOptimizer(MOI._instantiate_and_check(val))
        model.default_optimizer_builder = optimizer_builder
        set_default_optimizer_builder!(model.inner, optimizer_builder)
    else
        @warn("Unknown parameter $(param.name).")
    end
    return
end

function _get_orig_varid(optimizer::Optimizer, x::MOI.VariableIndex)
    if haskey(optimizer.vars, x)
        return optimizer.env.varids[x]
    end
    throw(MOI.InvalidIndex(x))
    return origid
end

function _get_orig_varid_in_form(
    optimizer::Optimizer, form::Formulation, x::MOI.VariableIndex
)
    origid = _get_orig_varid(optimizer, x)
    return getid(getvar(form, origid))
end

MOI.get(optimizer::Optimizer, ::MOI.SolverName) = "Coluna"

function MOI.optimize!(optimizer::Optimizer)
    optimizer.result, optimizer.disagg_result = optimize!(
        optimizer.env, optimizer.inner, optimizer.annotations
    )
    return
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; kwargs...)
    return MOI.Utilities.automatic_copy_to(dest, src; kwargs...)
end

############################################################################################
# Add variables
############################################################################################
function MOI.add_variable(model::Optimizer)
    orig_form = get_original_formulation(model.inner)
    var = setvar!(orig_form, "v", OriginalVar)
    index = CleverDicts.add_item(model.vars, var)
    model.moi_varids[getid(var)] = index
    index2 = CleverDicts.add_item(model.env.varids, getid(var))
    @assert index == index2
    return index
end

############################################################################################
# Add constraint
############################################################################################
function _constraint_on_variable!(
    optimizer, form::Formulation, constrid, var::Variable, ::MOI.Integer
)
    setperenkind!(form, var, Integ)
    optimizer.constrs_on_single_var[constrid] = BoundConstraints(getid(var), nothing, nothing, nothing)
    return
end

function _constraint_on_variable!(
    optimizer, form::Formulation, constrid, var::Variable, ::MOI.ZeroOne
)
    setperenkind!(form, var, Binary)
    constr1 = setsinglevarconstr!(
        form, "lb", getid(var), OriginalConstr; sense = Greater, rhs = 0.0
    )
    constr2 = setsinglevarconstr!(
        form, "ub", getid(var), OriginalConstr; sense = Less, rhs = 1.0
    )
    optimizer.constrs_on_single_var[constrid] = BoundConstraints(getid(var), constr1, constr2, nothing)
    return
end

function _constraint_on_variable!(
    optimizer, form::Formulation, constrid, var::Variable, set::MOI.GreaterThan{Float64}
)
    constr = setsinglevarconstr!(
        form, "lb", getid(var), OriginalConstr; sense = Greater, rhs = set.lower
    )
    optimizer.constrs_on_single_var[constrid] = BoundConstraints(getid(var), constr, nothing, nothing)
    return
end

function _constraint_on_variable!(
    optimizer, form::Formulation, constrid, var::Variable, set::MOI.LessThan{Float64}
)
    constr = setsinglevarconstr!(
        form, "ub", getid(var), OriginalConstr; sense = Less, rhs = set.upper
    )
    optimizer.constrs_on_single_var[constrid] = BoundConstraints(getid(var), nothing, constr, nothing)
    return
end

function _constraint_on_variable!(
    optimizer, form::Formulation, constrid, var::Variable, set::MOI.EqualTo{Float64}
)
    constr = setsinglevarconstr!(
        form, "eq", getid(var), OriginalConstr; sense = Equal, rhs = set.value
    )
    optimizer.constrs_on_single_var[constrid] = BoundConstraint(getid(var), nothing, nothing, constr)
    return
end

function _constraint_on_variable!(
    optimizer, form::Formulation, constrid, var::Variable, set::MOI.Interval{Float64}
)
    constr1 = setsinglevarconstr!(
        form, "lb", getid(var), OriginalConstr; sense = Greater, rhs = set.lower
    )
    constr2 = setsinglevarconstr!(
        form, "ub", getid(var), OriginalConstr; sense = Less, rhs = set.upper
    )
    optimizer.constrs_on_single_var[constrid] = BoundConstraints(geid(var), constr1, constr2, nothing)
    return
end

function MOI.add_constraint(
    model::Optimizer, func::MOI.SingleVariable, set::S
) where {S<:SupportedVarSets}
    origform = get_original_formulation(model.inner)
    var = model.vars[func.variable]
    constrid = MOI.ConstraintIndex{MOI.SingleVariable, S}(func.variable.value)
    _constraint_on_variable!(model, origform, constrid, var, set)
    return constrid
end

function MOI.add_constraint(
    model::Optimizer, func::MOI.ScalarAffineFunction{Float64}, set::S
) where {S<:SupportedConstrSets}
    orig_form = get_original_formulation(model.inner)
    members = Dict{VarId, Float64}()
    for term in func.terms
        var = model.vars[term.variable_index]
        members[getid(var)] = get(members, getid(var), 0.0) + term.coefficient
    end
    constr = setconstr!(
        orig_form, "c", OriginalConstr;
        rhs = MathProg.convert_moi_rhs_to_coluna(set),
        kind = Essential,
        sense = MathProg.convert_moi_sense_to_coluna(set),
        inc_val = 10.0,
        members = members
    )
    constrid =  MOI.ConstraintIndex{typeof(func), typeof(set)}(length(model.constrs))
    model.constrs[constrid] = constr
    return constrid
end

############################################################################################
# Delete and modify variable
############################################################################################
function MOI.delete(model::Optimizer, vi::MOI.VariableIndex)
    MOI.throw_if_not_valid(model, vi)
    MOI.modify(model, MoiObjective(), MOI.ScalarCoefficientChange(vi, 0.0))
    for (ci, _) in model.constrs
        MOI.modify(model, ci, MOI.ScalarCoefficientChange(vi, 0.0))
    end
    varid = getid(model.vars[vi])
    for (ci, constrs) in model.constrs_on_single_var
        for constr in [constrs.lower, constrs.upper, constrs.eq]
            if constr !== nothing && constr.varid == varid
                MOI.delete(model, ci)
                break
            end
        end
    end
    delete!(get_original_formulation(model.inner), varid)
    delete!(model.moi_varids, varid)
    delete!(model.vars, vi)
    delete!(model.env.varids, vi)
    return
end

function MOI.modify(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}},
    change::MathOptInterface.ScalarCoefficientChange{Float64}
)
    setperencost!(
        get_original_formulation(model.inner), model.vars[change.variable], change.new_coefficient
    )
    return
end

############################################################################################
# Delete and modify constraint
############################################################################################
function MOI.delete(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S}
) where {F<:MOI.SingleVariable,S}
    MOI.throw_if_not_valid(model, ci)
    origform = get_original_formulation(model.inner)
    constrs = model.constrs_on_single_var[ci]
    if constrs.lower !== nothing
        delete!(origform, getid(constrs.lower))
    end
    if constrs.upper !== nothing
        delete!(origform, getid(constrs.upper))
    end
    if constrs.eq !== nothing
        delete!(origform, getid(constrs.eq))
    end
    delete!(model.constrs_on_single_var, ci)
    return
end

function MOI.delete(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, ci)
    constrid = getid(model.constrs[ci])
    orig_form = get_original_formulation(model.inner)
    coefmatrix = getcoefmatrix(orig_form)
    varids = VarId[]
    for (varid, _) in @view coefmatrix[constrid, :]
        push!(varids, varid)
    end
    for varid in varids
        coefmatrix[constrid, varid] = 0.0
    end
    delete!(orig_form, constrid)
    delete!(model.constrs, ci)
    return
end

function MOI.modify(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S},
    change::MOI.ScalarConstantChange{Float64}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, ci)
    setperenrhs!(get_original_formulation(model.inner), model.constrs[ci], change.new_constant)
    return
end

function MOI.modify(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S},
    change::MOI.ScalarCoefficientChange{Float64}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, ci)
    varid = getid(model.vars[change.variable])
    constrid = getid(model.constrs[ci])
    getcoefmatrix(get_original_formulation(model.inner))[constrid, varid] = change.new_coefficient
    return
end

############################################################################################
# Get variables
############################################################################################
function MOI.get(model::Optimizer, ::Type{MOI.VariableIndex}, name::String)
    return get(model.names_to_vars, name, nothing)
end

function MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices)
    indices = Vector{MathOptInterface.VariableIndex}()
    for (_, value) in model.moi_varids
        push!(indices, value)
    end
    return sort!(indices, by = x -> x.value)
end

############################################################################################
# Get constraints
############################################################################################
function _moi_bounds_type(lb, ub)
    lb == ub && return MOI.EqualTo{Float64}
    lb == -Inf && ub < Inf && return MOI.LessThan{Float64}
    lb > -Inf && ub == Inf && return MOI.GreaterThan{Float64}
    lb > -Inf && ub < -Inf && return MOI.Interval{Float64}
    return nothing
end

function MOI.get(
    model::Optimizer, C::Type{MOI.ConstraintIndex{F,S}}, name::String
) where {F,S}
    index = get(model.names_to_constrs, name, nothing)
    typeof(index) == C && return index
    return nothing
end

function MOI.get(model::Optimizer, ::MOI.ListOfConstraints)
    orig_form = get_original_formulation(model.inner)
    constraints = Set{Tuple{DataType, DataType}}()
    for (id, var) in model.vars
        # Bounds
        lb = getperenlb(orig_form, var)
        ub = getperenub(orig_form, var)
        bound_type = _moi_bounds_type(lb, ub)
        if bound_type !== nothing
            push!(constraints, (MOI.SingleVariable, bound_type))
        end
        # Kind
        var_kind = MathProg.convert_coluna_kind_to_moi(getperenkind(orig_form, var))
        if var_kind !== nothing
            push!(constraints, (MOI.SingleVariable, var_kind))
        end
    end
    for (id, constr) in model.constrs
        constr_sense = MathProg.convert_coluna_sense_to_moi(getperensense(orig_form, constr))
        push!(constraints, (MOI.ScalarAffineFunction{Float64}, constr_sense))
    end
    return collect(constraints)
end

_add_constraint!(indices::Vector, index) = nothing
function _add_constraint!(
    indices::Vector{MOI.ConstraintIndex{F,S}}, index::MOI.ConstraintIndex{F,S}
) where {F,S}
    push!(indices, index)
    return
end

function MOI.get(
    model::Optimizer, ::MOI.ListOfConstraintIndices{F, S}
) where {F<:MOI.ScalarAffineFunction{Float64}, S}
    indices = MOI.ConstraintIndex{F,S}[]
    for (id, constr) in model.constrs
        _add_constraint!(indices, id)
    end
    return sort!(indices, by = x -> x.value)
end

function MOI.get(
    model::Optimizer, ::MOI.ListOfConstraintIndices{F, S}
) where {F<:MOI.SingleVariable, S}
    indices = MOI.ConstraintIndex{F,S}[]
    for (id, _) in model.constrs_on_single_var
        if S == typeof(MOI.get(model, MOI.ConstraintSet(), id))
            push!(indices, id)
        end
    end
    return sort!(indices, by = x -> x.value)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintFunction, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction{Float64}, S}
    orig_form = get_original_formulation(model.inner)
    constrid = getid(model.constrs[index])
    terms = MOI.ScalarAffineTerm{Float64}[]
    for (varid, coef) in @view getcoefmatrix(orig_form)[constrid, :]
        push!(terms, MOI.ScalarAffineTerm(coef, model.moi_varids[varid]))
    end
    return MOI.ScalarAffineFunction(terms, 0.0)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintFunction, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.SingleVariable, S}
    return MOI.SingleVariable(MOI.VariableIndex(index.value))
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    orig_form = get_original_formulation(model.inner)
    rhs = getperenrhs(orig_form, model.constrs[index])
    return S(rhs)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}
)
    orig_form = get_original_formulation(model.inner)
    lb = getperenlb(orig_form, model.vars[MOI.VariableIndex(index.value)])
    return MOI.GreaterThan(lb)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    ub = getperenub(orig_form, model.vars[MOI.VariableIndex(index.value)])
    return MOI.LessThan(ub)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    lb = getperenlb(orig_form, model.vars[MOI.VariableIndex(index.value)])
    ub = getperenub(orig_form, model.vars[MOI.VariableIndex(index.value)])
    @assert lb == ub
    return MOI.EqualTo(lb)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.SingleVariable, MOI.Interval{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    lb = getperenlb(orig_form, model.vars[MOI.VariableIndex(index.value)])
    ub = getperenub(orig_form, model.vars[MOI.VariableIndex(index.value)])
    return MOI.Interval(lb, ub)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.SingleVariable, MOI.ZeroOne}
)
    return MOI.ZeroOne()
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.SingleVariable, MOI.Integer}
)
    return MOI.Integer()
end

function MOI.get(model::Optimizer, ::Type{MOI.ConstraintIndex}, name::String)
    return get(model.names_to_constrs, name, nothing)
end

############################################################################################
# Attributes of variables
############################################################################################
function MOI.set(
    model::Optimizer, ::BD.VariableDecomposition, varid::MOI.VariableIndex,
    annotation::BD.Annotation
)
    store!(model.annotations, annotation, model.vars[varid])
    return
end

function MOI.set(
    model::Optimizer, ::MOI.VariableName, varid::MOI.VariableIndex, name::String
)
    MOI.throw_if_not_valid(model, varid)
    var = model.vars[varid]
    # TODO : rm set perene name
    var.name = name
    model.names_to_vars[name] = varid
    return
end

function MOI.set(
    model::Optimizer, ::BD.VarBranchingPriority, varid::MOI.VariableIndex, branching_priority::Int
)
    var = model.vars[varid]
    var.branching_priority = Float64(branching_priority)
    return
end

function MOI.get(model::Optimizer, ::MOI.VariableName, index::MOI.VariableIndex)
    orig_form = get_original_formulation(model.inner)
    return getname(orig_form, model.vars[index])
end

function MOI.get(model::Optimizer, ::BD.VarBranchingPriority, varid::MOI.VariableIndex)
    var = model.vars[varid]
    return var.branching_priority
end

function MOI.get(model::Optimizer, ::MOI.ListOfVariableAttributesSet)
    return MOI.AbstractVariableAttribute[MOI.VariableName()]
end

############################################################################################
# Attributes of constraints
############################################################################################
# TODO move into BlockDecomposition.
function MOI.set(
    model::MOI.ModelLike, attr::BlockDecomposition.ConstraintDecomposition,
    bridge::MOI.Bridges.Constraint.SplitIntervalBridge, value
)
    MOI.set(model.model, attr, bridge.lower, value)
    MOI.set(model.model, attr, bridge.upper, value)
    return
end

function MOI.set(
    model::Optimizer, ::BD.ConstraintDecomposition, constrid::MOI.ConstraintIndex,
    annotation::BD.Annotation
)
    constr = get(model.constrs, constrid, nothing)
    if constr !== nothing
        store!(model.annotations, annotation, model.constrs[constrid])
    end
    return
end

function MOI.set(
    model::Optimizer, ::MOI.ConstraintName, constrid::MOI.ConstraintIndex{F,S}, name::String
) where {F<:MOI.ScalarAffineFunction,S}
    MOI.throw_if_not_valid(model, constrid)
    constr = model.constrs[constrid]
    # TODO : rm set perene name
    constr.name = name
    model.names_to_constrs[name] = constrid
    return
end

function MOI.set(
    model::Optimizer, ::MOI.ConstraintName, constrid::MOI.ConstraintIndex{F,S}, name::String
) where {F<:MOI.SingleVariable,S}
    MOI.throw_if_not_valid(model, constrid)
    setname!(model.constrs_on_single_var[constrid], S, name)
    model.names_to_constrs[name] = constrid
    return
end

function MOI.set(
    model::Coluna.Optimizer, ::MOI.ConstraintSet, constrid::MOI.ConstraintIndex{F,S}, set::S
) where {F<:SupportedConstrFunc,S<:SupportedConstrSets}
    MOI.throw_if_not_valid(model, constrid)
    origform = get_original_formulation(model.inner)
    constr = model.constrs[constrid]
    setperenrhs!(origform, constr, MathProg.convert_moi_rhs_to_coluna(set))
    setperensense!(origform, constr, MathProg.convert_moi_sense_to_coluna(set))
    return
end

function MOI.set(
    model::Coluna.Optimizer, ::MOI.ConstraintSet, constrid::MOI.ConstraintIndex{F,S}, set::S
) where {F<:MOI.SingleVariable,S<:SupportedConstrSets}
    MOI.throw_if_not_valid(model, constrid)
    constrs = model.constrs_on_single_var[constrid]
    setrhs!(constrs, set)
    return
end

function MOI.get(model::Optimizer, ::MOI.ConstraintName, constrid::MOI.ConstraintIndex)
    MOI.throw_if_not_valid(model, constrid)
    orig_form = get_original_formulation(model.inner)
    constr = get(model.constrs, constrid, nothing)
    if constr !== nothing
        return getname(orig_form, constr)
    end
    return ""
end

function MOI.get(model::Optimizer, ::MOI.ListOfConstraintAttributesSet)
    return MOI.AbstractConstraintAttribute[MOI.ConstraintName()]
end

############################################################################################
# Objective
############################################################################################
function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    orig_form = get_original_formulation(model.inner)
    if sense == MOI.MIN_SENSE
        model.feasibility_sense = false
        set_objective_sense!(orig_form, true) # Min
    elseif sense == MOI.MAX_SENSE
        model.feasibility_sense = false
        set_objective_sense!(orig_form, false) # Max
    else
        model.feasibility_sense = true
        set_objective_sense!(orig_form, true) # Min
    end
    return
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveSense)
    sense = getobjsense(get_original_formulation(model.inner))
    model.feasibility_sense && return MOI.FEASIBILITY_SENSE
    sense == MaxSense && return MOI.MAX_SENSE
    return MOI.MIN_SENSE
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveFunctionType)
    if model.objective_type == SINGLE_VARIABLE
        return MOI.SingleVariable
    end
    @assert model.objective_type == SCALAR_AFFINE
    return MOI.ScalarAffineFunction{Float64}
end

function MOI.set(
    model::Optimizer, ::MOI.ObjectiveFunction{F}, func::F
) where {F<:MOI.ScalarAffineFunction{Float64}}
    model.objective_type = SCALAR_AFFINE
    origform = get_original_formulation(model.inner)

    for (_, var) in model.vars
        setperencost!(origform, var, 0.0)
    end

    for term in func.terms
        var = model.vars[term.variable_index]
        cost = term.coefficient + getperencost(origform, var)
        setperencost!(origform, var, cost)
    end

    if func.constant != 0
        setobjconst!(origform, func.constant)
    end
    return
end

function MOI.set(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.SingleVariable},
    func::MOI.SingleVariable
)
    model.objective_type = SINGLE_VARIABLE
    setperencost!(get_original_formulation(model.inner), model.vars[func.variable], 1.0)
    return
end

function MOI.get(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}
)
    @assert model.objective_type == SCALAR_AFFINE
    orig_form = get_original_formulation(model.inner)
    terms = MOI.ScalarAffineTerm{Float64}[]
    for (id, var) in model.vars
        cost = getperencost(orig_form, var)
        if !iszero(cost)
            push!(terms, MOI.ScalarAffineTerm(cost, id))
        end
    end
    return MOI.ScalarAffineFunction(terms, getobjconst(orig_form))
end

function MOI.get(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.SingleVariable}
)
    @assert model.objective_type == SINGLE_VARIABLE
    orig_form = get_original_formulation(model.inner)
    for (id, var) in model.vars
        cost = getperencost(orig_form, var)
        if cost != 0
            return MOI.SingleVariable(id)
        end
    end
    error("Could not find the variable with cost != 0.")
end

############################################################################################
# Attributes of model
############################################################################################
function MOI.set(model::Optimizer, ::BD.DecompositionTree, tree::BD.Tree)
    model.annotations.tree = tree
    return
end

function MOI.set(model::Optimizer, ::BD.ObjectiveDualBound, db)
    set_initial_dual_bound!(model.inner, db)
    return
end

function MOI.set(model::Optimizer, ::BD.ObjectivePrimalBound, pb)
    set_initial_primal_bound!(model.inner, pb)
    return
end

function _customdata!(model::Optimizer, type::DataType)
    haskey(model.env.custom_families_id, type) && return
    model.env.custom_families_id[type] = length(model.env.custom_families_id)
    return
end

function MOI.set(
    model::Optimizer, ::BD.CustomVars, customvars::Vector{DataType}
)
    for customvar in customvars
        _customdata!(model, customvar)
    end
    return
end

function MOI.set(
    model::Optimizer, ::BD.CustomConstrs, customconstrs::Vector{DataType}
)
    for customconstr in customconstrs
        _customdata!(model, customconstr)
    end
    return
end

function MOI.empty!(model::Optimizer)
    model.inner = Problem(model.env)
    model.annotations = Annotations()
    model.vars = CleverDicts.CleverDict{MOI.VariableIndex, Variable}()
    model.env.varids = CleverDicts.CleverDict{MOI.VariableIndex, VarId}()
    model.moi_varids = Dict{VarId, MOI.VariableIndex}()
    model.constrs = Dict{MOI.ConstraintIndex, Constraint}()
    model.constrs_on_single_var = Dict{MOI.ConstraintIndex, BoundConstraints}()
    #model.constrs_on_single_var_to_vars = Dict{MOI.ConstraintIndex, VarId}()
    #model.constrs_on_single_var_to_names = Dict{MOI.ConstraintIndex, String}()
    if model.default_optimizer_builder !== nothing
        set_default_optimizer_builder!(model.inner, model.default_optimizer_builder)
    end
    model.result = OptimizationState(get_optimization_target(model.inner))
    model.disagg_result = nothing
    return
end

mutable struct ColumnInfo <: BD.AbstractColumnInfo
    optimizer::Optimizer
    column_var_id::VarId
    column_val::Float64
end

function BD.getsolutions(model::Optimizer, k)
    ip_primal_sol = get_best_ip_primal_sol(model.disagg_result)
    sp_columns_info = Vector{ColumnInfo}()
    for (varid, val) in ip_primal_sol
        if getduty(varid) <= MasterCol
            if  model.annotations.ann_per_form[getoriginformuid(varid)].axis_index_value == k
                push!(sp_columns_info, ColumnInfo(model, varid, val))
            end
        end
    end
    return sp_columns_info
end

BD.value(info::ColumnInfo) = info.column_val

function BD.value(info::ColumnInfo, index::MOI.VariableIndex)
    varid = info.optimizer.env.varids[index]
    origin_form_uid = getoriginformuid(info.column_var_id)
    spform = get_dw_pricing_sps(info.optimizer.inner.re_formulation)[origin_form_uid]
    return getprimalsolpool(spform)[info.column_var_id,varid]
end

function MOI.get(model::Optimizer, ::MOI.NumberOfVariables)
    orig_form = get_original_formulation(model.inner)
    return length(getvars(orig_form))
end

function MOI.get(model::Optimizer, ::MOI.NumberOfConstraints{F, S}) where {F, S}
    return length(MOI.get(model, MOI.ListOfConstraintIndices{F, S}()))
end

function MOI.get(model::Optimizer, ::MOI.ListOfModelAttributesSet)
    attributes = Any[MOI.ObjectiveSense()]
    typ = MOI.get(model, MOI.ObjectiveFunctionType())
    if typ !== nothing
        push!(attributes, MOI.ObjectiveFunction{typ}())
    end
    return attributes
end

# ######################
# ### Get functions ####
# ######################

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.inner === nothing || optimizer.inner.re_formulation === nothing
end

function MOI.is_valid(
    optimizer::Optimizer, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.SingleVariable,S}
    return haskey(optimizer.constrs_on_single_var, index)
end

function MOI.is_valid(
    optimizer::Optimizer, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction,S}
    return haskey(optimizer.constrs, index)
end

function MOI.is_valid(optimizer::Optimizer, index::MOI.VariableIndex)
    return haskey(optimizer.vars, index)
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveBound)
    return getvalue(get_ip_dual_bound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    return getvalue(get_ip_primal_bound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.DualObjectiveValue)
    return getvalue(get_lp_dual_bound(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.RelativeGap)
    return ip_gap(optimizer.result)
end

function MOI.get(optimizer::Optimizer, attr::MOI.VariablePrimal, ref::MOI.VariableIndex)
    id = getid(optimizer.vars[ref]) # This gets a coluna VarId
    primalsols = get_ip_primal_sols(optimizer.result)
    if 1 <= attr.N <= length(primalsols)
        return get(primalsols[attr.N], id, 0.0)
    end
    return error("Invalid result index.")
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, refs::Vector{MOI.VariableIndex})
    best_primal_sol = get_best_ip_primal_sol(optimizer.result)
    if best_primal_sol === nothing
        @warn "Coluna did not find a primal feasible solution."
        return [NaN for ref in refs]
    end
    return [get(best_primal_sol, getid(optimizer.vars[ref]), 0.0) for ref in refs]
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return convert_status(getterminationstatus(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.PrimalStatus)
    primal_sol = get_best_ip_primal_sol(optimizer.result)
    primal_sol === nothing && return MOI.NO_SOLUTION
    return convert_status(getstatus(primal_sol))
end

function MOI.get(optimizer::Optimizer, ::MOI.DualStatus)    
    dual_sol = get_best_lp_dual_sol(optimizer.result)
    dual_sol === nothing && return MOI.NO_SOLUTION
    return convert_status(getstatus(dual_sol))
end

function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    return string(getterminationstatus(optimizer.result))
end

function MOI.get(optimizer::Optimizer, ::MOI.ResultCount)
    return length(get_ip_primal_sols(optimizer.result))
end

function MOI.get(
    optimizer::Optimizer, ::MOI.ConstraintPrimal, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.SingleVariable,S}
    MOI.throw_if_not_valid(optimizer, index)
    bounds = get(optimizer.constrs_on_single_var, index, nothing)
    if bounds === nothing
        @warn "Could not find constraint with id $(index)."
        return NaN
    end
    best_primal_sol = get_best_ip_primal_sol(optimizer.result)
    return get(best_primal_sol, bounds.varid, 0.0)
end

function MOI.get(optimizer::Optimizer, ::MOI.ConstraintPrimal, index::MOI.ConstraintIndex)
    MOI.throw_if_not_valid(optimizer, index)
    constrid = get(optimizer.constrs, index, nothing)
    if constrid === nothing
        @warn "Could not find constraint with id $(index)."
        return NaN
    end
    best_primal_sol = get_best_ip_primal_sol(optimizer.result)
    return constraint_primal(best_primal_sol, getid(constrid))
end

MOI.get(optimizer::Optimizer, ::MOI.NodeCount) = optimizer.env.kpis.node_count
MOI.get(optimizer::Optimizer, ::MOI.SolveTime) = optimizer.env.kpis.elapsed_optimization_time

function MOI.get(
    optimizer::Optimizer, attr::MOI.ConstraintDual, 
    index::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}}
)
    MOI.throw_if_not_valid(optimizer, index)
    dualsols = get_lp_dual_sols(optimizer.result)
    if 1 <= attr.N <= length(dualsols)
        return get(dualsols[attr.N], getid(optimizer.constrs[index]), 0.0)
    end
    return error("Invalid result index.")
end

function _singlevarconstrdualval(bc, dualsol, ::Type{<:MOI.GreaterThan})
    value, activebound = get(get_var_redcosts(dualsol), bc.varid, (0.0, MathProg.LOWER))
    if value != 0.0 && activebound != MathProg.LOWER
        return 0.0
    end
    return value
end

function _singlevarconstrdualval(bc, dualsol, ::Type{<:MOI.LessThan})
    value, activebound = get(get_var_redcosts(dualsol), bc.varid, (0.0, MathProg.UPPER))
    if value != 0.0 && activebound != MathProg.UPPER
        return 0.0
    end
    return value
end

function _singlevarconstrdualval(bc, dualsol, ::Type{<:MOI.EqualTo})
    value, _ = get(get_var_redcosts(dualsol), bc.varid, (0.0, MathProg.LOWER))
    return value
end

function MOI.get(
    optimizer::Optimizer, attr::MOI.ConstraintDual, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.SingleVariable,S}
    MOI.throw_if_not_valid(optimizer, index)
    dualsols = get_lp_dual_sols(optimizer.result)
    if 1 <= attr.N <= length(dualsols)
        single_var_constrs = optimizer.constrs_on_single_var[index]
        return _singlevarconstrdualval(single_var_constrs, dualsols[attr.N], S)
    end
    return error("Invalid result index.")
end

# Useful method to retrieve dual values of generated cuts because they don't 
# have MOI.ConstraintIndex
function MOI.get(
    optimizer::Optimizer, attr::MOI.ConstraintDual, constrid::ConstrId
)
    dualsols = get_lp_dual_sols(optimizer.result)
    if 1 <= attr.N <= length(dualsols)
        return get(dualsols[attr.N], constrid, 0.0)
    end
    return error("Invalid result index.")
end
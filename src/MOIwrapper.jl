const CleverDicts = MOI.Utilities.CleverDicts
CleverDicts.index_to_key(::Type{Int}, index) = index
CleverDicts.key_to_index(key::Int) = key

@enum(ObjectiveType, SINGLE_VARIABLE, SCALAR_AFFINE, ZERO)

@enum(_VarKind, _CONT, _INT, _BINARY)
@enum(_VarBound, _LESS, _GREATER, _EQUAL, _INTERVAL, _NONE)

mutable struct _VarInfo
    lb_type::_VarBound
    ub_type::_VarBound
    kind::_VarKind
    index::MOI.VariableIndex
    name::String
    var::Variable
    data::Union{Nothing, BlockDecomposition.AbstractCustomData}
end
_VarInfo(var::Variable) = _VarInfo(_NONE, _NONE, _CONT, MOI.VariableIndex(0), "", var, nothing)

mutable struct _ConstrInfo
    name::String
    index::Union{Nothing, MOI.ConstraintIndex}
    constr::Constraint
    data::Union{Nothing, BlockDecomposition.AbstractCustomData}
end
_ConstrInfo(constr::Constraint) = _ConstrInfo("", nothing, constr, nothing)

mutable struct Optimizer <: MOI.AbstractOptimizer
    env::Env
    inner::Problem
    is_objective_set::Bool
    objective_type::ObjectiveType
    objective_sense::Union{Nothing, MOI.OptimizationSense}
    annotations::Annotations
    varinfos::CleverDicts.CleverDict{MOI.VariableIndex, _VarInfo}
    moi_varids::Dict{VarId, MOI.VariableIndex}
    constrinfos::CleverDicts.CleverDict{Int, _ConstrInfo} # ScalarAffineFunction{Float64}-in-Set storage.
    result::OptimizationState
    disagg_result::Union{Nothing, OptimizationState}
    default_optimizer_builder::Union{Nothing, Function}

    # Names management
    # name -> (index of the first variable that has the name, nb of vars with this name)
    names_to_vars::Dict{String, Tuple{MOI.VariableIndex, Int}}
    # Same for constraints (the first int is the id).
    names_to_constrs::Dict{String, Tuple{Int, Int}}

    # Callbacks
    has_pricing_cb::Bool
    has_usercut_cb::Bool
    has_lazyconstraint_cb::Bool
    has_initialcol_cb::Bool

    function Optimizer()
        model = new()
        model.env = Env{VarId}(Params())
        model.inner = Problem(model.env)
        model.is_objective_set = false
        model.objective_type = ZERO
        model.objective_sense = nothing
        model.annotations = Annotations()
        model.varinfos = CleverDicts.CleverDict{MOI.VariableIndex, _VarInfo}()
        model.moi_varids = Dict{VarId, MOI.VariableIndex}()
        model.constrinfos = CleverDicts.CleverDict{Int, _ConstrInfo}()
        model.result = OptimizationState(get_optimization_target(model.inner))
        model.disagg_result = nothing
        model.default_optimizer_builder = nothing

        model.names_to_vars = Dict{String, Tuple{MOI.VariableIndex,Int}}()
        model.names_to_constrs = Dict{String, Tuple{Int,Int}}()

        model.has_pricing_cb = false
        model.has_usercut_cb = false
        model.has_lazyconstraint_cb = false
        model.has_initialcol_cb = false
        return model
    end
end

MOI.get(::Optimizer, ::MOI.SolverName) = "Coluna"
MOI.get(::Optimizer, ::MOI.SolverVersion) = string(Coluna.version())

############################################################################################
# Empty.
############################################################################################
function MOI.empty!(model::Optimizer)
    model.env.varids = CleverDicts.CleverDict{MOI.VariableIndex, VarId}()

    model.inner = Problem(model.env)
    model.is_objective_set = false
    model.objective_type = ZERO
    model.objective_sense = nothing
    model.annotations = Annotations()
    model.varinfos = CleverDicts.CleverDict{MOI.VariableIndex, _VarInfo}()
    model.moi_varids = Dict{VarId, MOI.VariableIndex}()
    model.constrinfos = CleverDicts.CleverDict{Int, _ConstrInfo}()
    model.result = OptimizationState(get_optimization_target(model.inner))
    model.disagg_result = nothing
    if model.default_optimizer_builder !== nothing
        set_default_optimizer_builder!(model.inner, model.default_optimizer_builder)
    end
    model.names_to_vars = Dict{String, Tuple{MOI.VariableIndex, Int}}()
    model.names_to_constrs = Dict{String, Tuple{Int, Int}}()
    model.has_pricing_cb = false
    model.has_usercut_cb = false
    model.has_lazyconstraint_cb = false
    model.has_initialcol_cb = false
    return
end

function MOI.is_empty(model::Optimizer)
    reform = model.inner.re_formulation
    origform = model.inner.original_formulation
    return reform === nothing && length(getvars(origform)) == 0 && 
        length(getconstrs(origform)) == 0 && !model.is_objective_set
end

############################################################################################
# Methods to get variable and constraint info.
############################################################################################
function _info(model::Optimizer, key::MOI.VariableIndex)
    if haskey(model.varinfos, key)
        return model.varinfos[key]
    end
    return throw(MOI.InvalidIndex(key))
end

function _info(model::Optimizer, key::MOI.ConstraintIndex{MOI.VariableIndex, S}) where {S}
    varindex = MOI.VariableIndex(key.value)
    return _info(model, varindex)
end

function _info(model::Optimizer, key::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}})
    if haskey(model.constrinfos, key.value)
        return model.constrinfos[key.value]
    end
    return throw(MOI.InvalidIndex(key))
end

function _info(model::Optimizer, key::Int)
    if haskey(model.constrinfos, key)
        return model.constrinfos[key]
    end
    return throw(MOI.InvalidIndex(key))
end

############################################################################################
# Supported variables, constraints, and objectives.
############################################################################################
const SupportedObjFunc = Union{MOI.ScalarAffineFunction{Float64}, MOI.VariableIndex}
const SupportedVarSets = Union{
    MOI.ZeroOne, MOI.Integer, MOI.LessThan{Float64}, MOI.EqualTo{Float64}, 
    MOI.GreaterThan{Float64}, MOI.Interval{Float64}
}
const SupportedConstrFunc = Union{MOI.ScalarAffineFunction{Float64}}
const SupportedConstrSets = Union{
    MOI.EqualTo{Float64}, MOI.GreaterThan{Float64}, MOI.LessThan{Float64}
}

MOI.supports_incremental_interface(::Optimizer) = true
MOI.supports_constraint(::Optimizer, ::Type{<:SupportedConstrFunc}, ::Type{<:SupportedConstrSets}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{<:SupportedVarSets}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{<:SupportedObjFunc}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ConstraintPrimalStart) = false
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart) = false
MOI.supports(::Optimizer, ::BlockDecomposition.ConstraintDecomposition) = true
MOI.supports(::Optimizer, ::BlockDecomposition.VariableDecomposition) = true
MOI.supports(::Optimizer, ::BlockDecomposition.RepresentativeVar) = true
MOI.supports(::Optimizer, ::BlockDecomposition.CustomVarValue) = true   
MOI.supports(::Optimizer, ::BlockDecomposition.CustomConstrValue) = true

# Parameters
function MOI.set(model::Optimizer, param::MOI.RawOptimizerAttribute, val)
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

function _get_orig_varid(env::Env, x::MOI.VariableIndex)
    if haskey(env.varids, x)
        return env.varids[x]
    end
    throw(MOI.InvalidIndex(x))
end

function _get_varid_of_origvar_in_form(
    env::Env, form::Formulation, x::MOI.VariableIndex
)
    origid = _get_orig_varid(env, x)
    return getid(getvar(form, origid))
end

function MOI.optimize!(model::Optimizer)
    model.result, model.disagg_result = optimize!(
        model.env, model.inner, model.annotations
    )
    return
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike)
    return MOI.Utilities.default_copy_to(dest, src)
end

############################################################################################
# Add variables
############################################################################################
# See https://jump.dev/JuMP.jl/stable/moi/tutorials/implementing/#Dealing-with-multiple-variable-bounds
# to understand the purpose of _throw_if_existing_* methods.
function _throw_if_existing_lower(
    bound::_VarBound,
    ::Type{S},
    variable::MOI.VariableIndex,
) where {S<:MOI.AbstractSet}
    if bound == _GREATER
        throw(MOI.LowerBoundAlreadySet{MOI.GreaterThan{Float64},S}(variable))
    elseif bound == _INTERVAL
        throw(MOI.LowerBoundAlreadySet{MOI.Interval{Float64},S}(variable))
    elseif bound == _EQUAL
        throw(MOI.LowerBoundAlreadySet{MOI.EqualTo{Float64},S}(variable))
    end
    return
end

function _throw_if_existing_upper(
    bound::_VarBound,
    ::Type{S},
    variable::MOI.VariableIndex,
) where {S<:MOI.AbstractSet}
    if bound == _LESS
        throw(MOI.UpperBoundAlreadySet{MOI.LessThan{Float64},S}(variable))
    elseif bound == _INTERVAL
        throw(MOI.UpperBoundAlreadySet{MOI.Interval{Float64},S}(variable))
    elseif bound == _EQUAL
        throw(MOI.UpperBoundAlreadySet{MOI.EqualTo{Float64},S}(variable))
    end
    return
end

function MOI.add_variable(model::Optimizer)
    orig_form = get_original_formulation(model.inner)
    var = setvar!(orig_form, "", OriginalVar)
    varinfo = _VarInfo(var)
    index = CleverDicts.add_item(model.varinfos, varinfo)
    varinfo.index = index
    model.moi_varids[getid(var)] = index
    index2 = CleverDicts.add_item(model.env.varids, getid(var))
    @assert index == index2
    return index
end

############################################################################################
# Add constraint
############################################################################################
function _add_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::MOI.Integer
)
    setperenkind!(form, varinfo.var, Integ)
    varinfo.kind = _INT
    return
end

function _add_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::MOI.ZeroOne
)
    setperenkind!(form, varinfo.var, Binary)
    varinfo.kind = _BINARY
    return
end

function _add_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, set::MOI.GreaterThan{Float64}
)
    _throw_if_existing_lower(varinfo.lb_type, MOI.GreaterThan{Float64}, varinfo.index) 
    MathProg.setperenlb!(form, varinfo.var, set.lower)
    varinfo.lb_type = _GREATER
    return
end

function _add_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, set::MOI.LessThan{Float64}
)
    _throw_if_existing_upper(varinfo.ub_type, MOI.LessThan{Float64}, varinfo.index)
    MathProg.setperenub!(form, varinfo.var, set.upper)
    varinfo.ub_type = _LESS
    return
end

function _add_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, set::MOI.EqualTo{Float64}
)
    _throw_if_existing_lower(varinfo.lb_type, MOI.EqualTo{Float64}, varinfo.index) 
    _throw_if_existing_upper(varinfo.ub_type, MOI.EqualTo{Float64}, varinfo.index)
    MathProg.setperenlb!(form, varinfo.var, set.value)
    MathProg.setperenub!(form, varinfo.var, set.value)
    varinfo.lb_type = _EQUAL
    varinfo.ub_type = _EQUAL
    return
end

function _add_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, set::MOI.Interval{Float64}
)
    _throw_if_existing_lower(varinfo.lb_type, MOI.Interval{Float64}, varinfo.index) 
    _throw_if_existing_upper(varinfo.ub_type, MOI.Interval{Float64}, varinfo.index)
    MathProg.setperenlb!(form, varinfo.var, set.lower)
    MathProg.setperenub!(form, varinfo.var, set.upper)
    varinfo.lb_type = _INTERVAL
    varinfo.ub_type = _INTERVAL
    return
end

function MOI.add_constraint(
    model::Optimizer, func::MOI.VariableIndex, set::S
) where {S<:SupportedVarSets}
    origform = get_original_formulation(model.inner)
    varinfo = _info(model, func)
    _add_constraint_on_variable!(origform, varinfo, set)
    index = MOI.ConstraintIndex{MOI.VariableIndex, S}(func.value)
    return index
end

function MOI.add_constraint(
    model::Optimizer, func::F, set::S
) where {F<:MOI.ScalarAffineFunction{Float64}, S<:SupportedConstrSets}
    if !iszero(func.constant)
        throw(MOI.ScalarFunctionConstantNotZero{Float64,F,S}(func.constant))
    end
    orig_form = get_original_formulation(model.inner)
    members = Dict{VarId, Float64}()
    for term in func.terms
        var = _info(model, term.variable).var
        members[getid(var)] = get(members, getid(var), 0.0) + term.coefficient
    end
    constr = setconstr!(
        orig_form, "", OriginalConstr;
        rhs = MathProg.convert_moi_rhs_to_coluna(set),
        kind = Essential,
        sense = MathProg.convert_moi_sense_to_coluna(set),
        inc_val = 10.0,
        members = members
    )
    constrinfo = _ConstrInfo(constr)
    constr_index = CleverDicts.add_item(model.constrinfos, constrinfo)
    model.constrinfos[constr_index] = constrinfo
    index = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, S}(constr_index)
    constrinfo.index = index
    return index
end

############################################################################################
# Delete and modify variable
############################################################################################
function _delete_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::Type{<:MOI.Integer}
)
    varinfo.kind = _CONT
    setperenkind!(form, varinfo.var, Continuous)
    return
end

function _delete_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::Type{<:MOI.ZeroOne}
)
    varinfo.kind = _CONT
    setperenkind!(form, varinfo.var, Continuous)
    return
end

function _delete_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::Type{<:MOI.GreaterThan{Float64}}
)
    varinfo.lb_type = _NONE
    MathProg.setperenlb!(form, varinfo.var, -Inf)
    return
end

function _delete_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::Type{<:MOI.LessThan{Float64}}
)
    varinfo.ub_type = _NONE
    MathProg.setperenub!(form, varinfo.var, Inf)
    return
end

function _delete_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::Type{<:MOI.EqualTo{Float64}}
)
    varinfo.lb_type = _NONE
    varinfo.ub_type = _NONE
    MathProg.setperenlb!(form, varinfo.var, -Inf)
    MathProg.setperenub!(form, varinfo.var, Inf)
    return
end

function _delete_constraint_on_variable!(
    form::Formulation, varinfo::_VarInfo, ::Type{<:MOI.Interval{Float64}}
)
    varinfo.lb_type = _NONE
    varinfo.ub_type = _NONE
    MathProg.setperenlb!(form, varinfo.var, -Inf)
    MathProg.setperenub!(form, varinfo.var, Inf)
    return
end

function MOI.delete(model::Optimizer, vi::MOI.VariableIndex)
    MOI.throw_if_not_valid(model, vi)
    MOI.modify(model, MoiObjective(), MOI.ScalarCoefficientChange(vi, 0.0))
    for (_, constrinfo) in model.constrinfos
        MOI.modify(model, constrinfo.index, MOI.ScalarCoefficientChange(vi, 0.0))
    end
    varid = getid(_info(model, vi).var)
    delete!(get_original_formulation(model.inner), varid)
    delete!(model.moi_varids, varid)
    delete!(model.varinfos, vi)
    delete!(model.env.varids, vi)
    return
end

function MOI.modify(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}},
    change::MathOptInterface.ScalarCoefficientChange{Float64}
)
    setperencost!(
        get_original_formulation(model.inner), _info(model, change.variable).var, change.new_coefficient
    )
    model.is_objective_set = true
    return
end

############################################################################################
# Delete and modify constraint
############################################################################################
function MOI.delete(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S}
) where {F<:MOI.VariableIndex,S}
    MOI.throw_if_not_valid(model, ci)
    origform = get_original_formulation(model.inner)
    varinfo = _info(model, ci)
    _delete_constraint_on_variable!(origform, varinfo, S)
    return
end

function MOI.delete(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, ci)
    constrid = getid(_info(model, ci).constr)
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
    delete!(model.constrinfos, ci.value)
    return
end

function MOI.modify(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S},
    change::MOI.ScalarConstantChange{Float64}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, ci)
    setperenrhs!(get_original_formulation(model.inner), _info(model, ci).constr, change.new_constant)
    return
end

function MOI.modify(
    model::Optimizer, ci::MOI.ConstraintIndex{F,S},
    change::MOI.ScalarCoefficientChange{Float64}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, ci)
    varid = getid(_info(model, change.variable).var)
    constrid = getid(_info(model, ci).constr)
    getcoefmatrix(get_original_formulation(model.inner))[constrid, varid] = change.new_coefficient
    return
end

############################################################################################
# Get variables
############################################################################################
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
function MOI.get(model::Optimizer, ::MOI.ListOfConstraintTypesPresent)
    orig_form = get_original_formulation(model.inner)
    constraints = Set{Tuple{DataType, DataType}}()
    for (_, varinfo) in model.varinfos
        # Bounds
        lb_type = varinfo.lb_type
        ub_type = varinfo.ub_type
        if lb_type == _GREATER
            push!(constraints, (MOI.VariableIndex, MOI.GreaterThan{Float64}))
        end
        if ub_type == _LESS
            push!(constraints, (MOI.VariableIndex, MOI.LessThan{Float64}))
        end
        if ub_type == _INTERVAL && lb_type == _INTERVAL
            push!(constraints, (MOI.VariableIndex, MOI.Interval{Float64}))
        end
        if ub_type == _EQUAL && lb_type == _EQUAL
            push!(constraints, (MOI.VariableIndex, MOI.EqualTo{Float64}))
        end
        # Kind
        kind = varinfo.kind
        if kind == _INT
            push!(constraints, (MOI.VariableIndex, MOI.Integer))
        end
        if kind == _BINARY
            push!(constraints, (MOI.VariableIndex, MOI.ZeroOne))
        end
    end
    for (_, constrinfo) in model.constrinfos
        constr = constrinfo.constr
        constr_sense = MathProg.convert_coluna_sense_to_moi(getperensense(orig_form, constr))
        push!(constraints, (MOI.ScalarAffineFunction{Float64}, constr_sense))
    end
    return collect(constraints)
end

function _add_constraint!(
    indices::Vector{MOI.ConstraintIndex{F,S}}, index::MOI.ConstraintIndex{F,S}
) where {F,S}
    push!(indices, index)
    return
end

function _add_constraint!(
    ::Vector{MOI.ConstraintIndex{F,S}}, index::MOI.ConstraintIndex
) where {F,S}
    return
end

function MOI.get(
    model::Optimizer, ::MOI.ListOfConstraintIndices{F, S}
) where {F<:MOI.ScalarAffineFunction{Float64}, S}
    indices = MOI.ConstraintIndex{F,S}[]
    for (_, constrinfo) in model.constrinfos
        _add_constraint!(indices, constrinfo.index)
    end
    return sort!(indices, by = x -> x.value)
end

_bound_enum(::Type{<:MOI.LessThan}) = _LESS
_bound_enum(::Type{<:MOI.GreaterThan}) = _GREATER
_bound_enum(::Type{<:MOI.Interval}) = _INTERVAL
_bound_enum(::Type{<:MOI.EqualTo}) = _EQUAL
_bound_enum(::Any) = nothing

_kind_enum(::Type{<:MOI.ZeroOne}) = _BINARY
_kind_enum(::Type{<:MOI.Integer}) = _INT
_kind_enum(::Any) = nothing

function MOI.get(
    model::Optimizer, ::MOI.ListOfConstraintIndices{F, S}
) where {F<:MOI.VariableIndex, S}
    indices = MOI.ConstraintIndex{F,S}[]
    for (_, varinfo) in model.varinfos
        if varinfo.lb_type == _bound_enum(S) || varinfo.ub_type == _bound_enum(S) || varinfo.kind == _kind_enum(S)
            push!(indices, MOI.ConstraintIndex{MOI.VariableIndex, S}(varinfo.index.value))
        end
    end
    return sort!(indices, by = x -> x.value)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintFunction, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction{Float64}, S}
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    constrid = getid(_info(model, index).constr)
    terms = MOI.ScalarAffineTerm{Float64}[]
    # Cannot get a view of the coefficient matrix when it is in fill mode.
    matrix = getcoefmatrix(orig_form)
    if matrix.matrix.fillmode
        for (varid, coef) in view(matrix.matrix.buffer, constrid, :)
            push!(terms, MOI.ScalarAffineTerm(coef, model.moi_varids[varid]))
        end
    else
        for (varid, coef) in @view matrix[constrid, :]
            push!(terms, MOI.ScalarAffineTerm(coef, model.moi_varids[varid]))
        end
    end
    return MOI.ScalarAffineFunction(terms, 0.0)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintFunction, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.VariableIndex, S}
    MOI.throw_if_not_valid(model, index)
    return MOI.VariableIndex(index.value)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction{Float64},S}
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    rhs = getperenrhs(orig_form, _info(model, index).constr)
    return S(rhs)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    lb = getperenlb(orig_form, _info(model, MOI.VariableIndex(index.value)).var)
    return MOI.GreaterThan(lb)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    ub = getperenub(orig_form,  _info(model, MOI.VariableIndex(index.value)).var)
    return MOI.LessThan(ub)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    lb = getperenlb(orig_form, _info(model, MOI.VariableIndex(index.value)).var)
    ub = getperenub(orig_form, _info(model, MOI.VariableIndex(index.value)).var)
    @assert lb == ub
    return MOI.EqualTo(lb)
end

function MOI.get(
    model::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.VariableIndex, MOI.Interval{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    orig_form = get_original_formulation(model.inner)
    lb = getperenlb(orig_form, _info(model, MOI.VariableIndex(index.value)).var)
    ub = getperenub(orig_form, _info(model, MOI.VariableIndex(index.value)).var)
    return MOI.Interval(lb, ub)
end

function MOI.get(
    ::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.VariableIndex, MOI.ZeroOne}
)
    return MOI.ZeroOne()
end

function MOI.get(
    ::Optimizer, ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{MOI.VariableIndex, MOI.Integer}
)
    return MOI.Integer()
end

############################################################################################
# Set constraints
############################################################################################
function MOI.set(
    model::Optimizer, ::MOI.ConstraintFunction, constrid::MOI.ConstraintIndex{F,S}, func::F
) where {F<:SupportedConstrFunc, S<:SupportedConstrSets}
    MOI.throw_if_not_valid(model, constrid)
    if !iszero(func.constant)
        throw(MOI.ScalarFunctionConstantNotZero(func.constant))
    end
    constrinfo = _info(model, constrid)
    id = getid(constrinfo.constr)
    origform = get_original_formulation(model.inner)
    coefmatrix = getcoefmatrix(origform)
    varids = VarId[]
    for (varid, _) in @view coefmatrix[id, :]
        push!(varids, varid)
    end
    for varid in varids
        coefmatrix[id, varid] = 0.0
    end
    for term in func.terms
        var = _info(model, term.variable).var
        coefmatrix[id, getid(var)] += term.coefficient
    end
    return
end

function MOI.set(
    model::Optimizer, ::MOI.ConstraintSet, constrid::MOI.ConstraintIndex{F,S}, set::S
) where {F<:SupportedConstrFunc,S<:SupportedConstrSets}
    MOI.throw_if_not_valid(model, constrid)
    origform = get_original_formulation(model.inner)
    constr = _info(model, constrid).constr
    setperenrhs!(origform, constr, MathProg.convert_moi_rhs_to_coluna(set))
    setperensense!(origform, constr, MathProg.convert_moi_sense_to_coluna(set))
    return
end

function MOI.set(
    ::Optimizer, ::MOI.ConstraintFunction, ::MOI.ConstraintIndex{F,S}, ::S
) where {F<:MOI.VariableIndex,S}
    return throw(MOI.SettingVariableIndexNotAllowed())
end

function MOI.set(
    model::Optimizer, ::MOI.ConstraintSet, constrid::MOI.ConstraintIndex{F,S}, set::S
) where {F<:MOI.VariableIndex, S<:SupportedVarSets}
    MOI.throw_if_not_valid(model, constrid)
    (lb, ub) = MathProg.convert_moi_bounds_to_coluna(set)
    varinfo = _info(model, constrid)
    origform = get_original_formulation(model.inner)
    MathProg.setperenlb!(origform, varinfo.var, lb)
    MathProg.setperenub!(origform, varinfo.var, ub)
    return
end

############################################################################################
# Names
############################################################################################
MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true

function MOI.get(model::Optimizer, ::MOI.VariableName, varid::MOI.VariableIndex)
    MOI.throw_if_not_valid(model, varid)
    return _info(model, varid).name
end

function MOI.set(
    model::Optimizer, ::MOI.VariableName, varid::MOI.VariableIndex, name::String
)
    MOI.throw_if_not_valid(model, varid)
    varinfo = _info(model, varid)
    oldname = varinfo.name
    varinfo.name = name
    varinfo.var.name = name

    if !isempty(oldname)
        i, n = model.names_to_vars[oldname]
        if n <= 1
            delete!(model.names_to_vars, oldname)
        else
            model.names_to_vars[oldname] = (i, n-1)
        end
    end

    if !isempty(name)
        if !haskey(model.names_to_vars, name)
            model.names_to_vars[name] = (varid, 1)
        else
            i, n = model.names_to_vars[name]
            model.names_to_vars[name] = (i, n+1)
        end
    end
    return
end

function MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{<:MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}}})
    return true
end

function MOI.get(model::Optimizer, ::MOI.ConstraintName, constrid::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, <:Any})
    MOI.throw_if_not_valid(model, constrid)
    return _info(model, constrid).name
end

function MOI.set(
    model::Optimizer, ::MOI.ConstraintName, constrid::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, <:Any}, name::String
)
    MOI.throw_if_not_valid(model, constrid)
    constrinfo = _info(model, constrid)
    oldname = constrinfo.name
    constrinfo.name = name
    constrinfo.constr.name = name

    if !isempty(oldname)
        i, n = model.names_to_constrs[oldname]
        if n <= 1
            delete!(model.names_to_constrs, oldname)
        else
            model.names_to_constrs[oldname] = (i, n-1)
        end
    end

    if !isempty(name)
        if !haskey(model.names_to_constrs, name)
            model.names_to_constrs[name] = (constrid.value, 1)
        else
            i, n = model.names_to_constrs[name]
            model.names_to_constrs[name] = (i, n+1)
        end
    end
    return
end

function MOI.get(model::Optimizer, ::Type{MOI.VariableIndex}, name::String)
    index, nb_vars_with_same_name = get(model.names_to_vars, name, (nothing, 0))
    if nb_vars_with_same_name > 1
        error("Duplicate variable name detected: $(name).")
    end
    return index
end

function MOI.get(
    model::Optimizer, ::Type{MOI.ConstraintIndex}, name::String
)
    index, nb_constrs_with_same_name = get(model.names_to_constrs, name, (nothing, 0))
    if nb_constrs_with_same_name > 1
        error("Duplicate constraint name detected: $(name).")
    end
    if index === nothing
        return nothing
    end
    return _info(model, index).index
end

function MOI.get(model::Optimizer, ::Type{MOI.ConstraintIndex{F,S}}, name::String) where {F,S}
    index = MOI.get(model, MOI.ConstraintIndex, name)
    if typeof(index) == MOI.ConstraintIndex{F,S}
        return index::MOI.ConstraintIndex{F,S}
    end
    return
end

############################################################################################
# Attributes of variables
############################################################################################
function MOI.set(
    model::Optimizer, ::BD.VariableDecomposition, varid::MOI.VariableIndex,
    annotation::BD.Annotation
)
    store!(model.annotations, annotation, _info(model, varid).var)
    return
end

# In the case of a representative variable.
function MOI.set(
    model::Optimizer, ::BD.VariableDecomposition, varid::MOI.VariableIndex,
    annotations::Vector{<:BD.Annotation}
)
    store_repr!(model.annotations, annotations, _info(model, varid).var)
    return
end

function MOI.set(
    model::Optimizer, ::BD.VarBranchingPriority, varid::MOI.VariableIndex, branching_priority::Int
)
    var = _info(model, varid).var
    var.branching_priority = Float64(branching_priority)
    return
end

function MOI.set(
    model::Optimizer, ::BD.CustomVarValue, varid::MOI.VariableIndex, custom_data
)
    MOI.throw_if_not_valid(model, varid)
    var = _info(model, varid).var
    var.custom_data = custom_data
    return
end

function MOI.get(model::Optimizer, ::BD.VarBranchingPriority, varid::MOI.VariableIndex)
    var = _info(model, varid).var
    return var.branching_priority
end

function MOI.get(model::Optimizer, ::MOI.ListOfVariableAttributesSet)
    return MOI.AbstractVariableAttribute[MOI.VariableName()]
end

# TODO: we'll have to check if this implementation fits good pratices.
function MOI.set(model::Optimizer, ::BD.RepresentativeVar, varid::MOI.VariableIndex, annotations)
    # nothing to do.
    # see MOI.set(model, ::BD.VariableDecomposition, varid, ::Vector{<:BD.Annotation})
    return
end

function MOI.get(model::Optimizer, ::BD.RepresentativeVar, varid::MOI.VariableIndex)
    # nothing to return.
    return 
end

function MOI.set(model::Optimizer, ::BD.ListOfRepresentatives, list)
    # nothing to do.
    return
end

function MOI.get(model::Optimizer, ::BD.ListOfRepresentatives)
    # nothing to return
    return
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
    MOI.throw_if_not_valid(model, constrid)
    store!(model.annotations, annotation, _info(model, constrid).constr)
    return
end

function MOI.set(
    model::Optimizer, ::BlockDecomposition.CustomConstrValue, constrid::MOI.ConstraintIndex,
    custom_data
)
    MOI.throw_if_not_valid(model, constrid)
    constr = _info(model, constrid).constr
    constr.custom_data = custom_data
    return
end

function MOI.get(model::Optimizer, ::BD.ConstraintDecomposition, index::MOI.ConstraintIndex)
    MOI.throw_if_not_valid(model, index)
    constrinfo = _info(model, index)
    return get(model.annotations.ann_per_constr, getid(constrinfo.constr), nothing)
end

function MOI.get(model::Optimizer, ::BD.VariableDecomposition, index::MOI.VariableIndex)
    MOI.throw_if_not_valid(model, index)
    varinfo = _info(model, index)
    return get(model.annotations.ann_per_var, getid(varinfo.var), nothing)
end

function MOI.get(model::Optimizer, ::MOI.ListOfConstraintAttributesSet)
    return MOI.AbstractConstraintAttribute[MOI.ConstraintName()]
end

function MOI.get(::Optimizer, ::MOI.ListOfConstraintAttributesSet{MOI.VariableIndex,<:MOI.AbstractScalarSet})
    return MOI.AbstractConstraintAttribute[]
end

############################################################################################
# Objective
############################################################################################
function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    orig_form = get_original_formulation(model.inner)
    if sense == MOI.MIN_SENSE
        set_objective_sense!(orig_form, true) # Min
    elseif sense == MOI.MAX_SENSE
        set_objective_sense!(orig_form, false) # Max
    else
        set_objective_sense!(orig_form, true) # Min
        # Set the cost of all variables to 0
        for (_, varinfo) in model.varinfos
            setperencost!(orig_form, varinfo.var, 0.0)
        end
    end
    model.objective_sense = sense
    return
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveSense)
    if !isnothing(model.objective_sense)
        return model.objective_sense
    end
    return MOI.FEASIBILITY_SENSE
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveFunctionType)
    if model.objective_type == SINGLE_VARIABLE
        return MOI.VariableIndex
    end
    return MOI.ScalarAffineFunction{Float64}
end

function MOI.set(
    model::Optimizer, ::MOI.ObjectiveFunction{F}, func::F
) where {F<:MOI.ScalarAffineFunction{Float64}}
    origform = get_original_formulation(model.inner)
    for (_, varinfo) in model.varinfos
        setperencost!(origform, varinfo.var, 0.0)
    end

    for term in func.terms
        var = _info(model, term.variable).var
        cost = term.coefficient + getperencost(origform, var)
        setperencost!(origform, var, cost)
    end

    if !iszero(func.constant)
        setobjconst!(origform, func.constant)
    end
    model.objective_type = SCALAR_AFFINE
    model.is_objective_set = true
    return
end

function MOI.set(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.VariableIndex},
    func::MOI.VariableIndex
)
    setperencost!(get_original_formulation(model.inner), _info(model, func).var, 1.0)
    model.objective_type = SINGLE_VARIABLE
    model.is_objective_set = true
    return
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveFunction{F}) where {F}
    obj = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    return convert(F, obj)
end

function MOI.get(
    model::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}
)
    orig_form = get_original_formulation(model.inner)
    terms = MOI.ScalarAffineTerm{Float64}[]
    for (id, varinfo) in model.varinfos
        cost = getperencost(orig_form, varinfo.var)
        if !iszero(cost)
            push!(terms, MOI.ScalarAffineTerm(cost, id))
        end
    end
    return MOI.ScalarAffineFunction(terms, getobjconst(orig_form))
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
    model::Optimizer, ::BD.CustomVars, customvars
)
    for customvar in customvars
        _customdata!(model, customvar)
    end
    return
end

function MOI.set(
    model::Optimizer, ::BD.CustomConstrs, customconstrs
)
    for customconstr in customconstrs
        _customdata!(model, customconstr)
    end
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
    return get_primal_sol_pool(spform).solutions[info.column_var_id,varid]
end

function MOI.get(model::Optimizer, ::MOI.NumberOfVariables)
    orig_form = get_original_formulation(model.inner)
    return length(getvars(orig_form))
end

function MOI.get(model::Optimizer, ::MOI.NumberOfConstraints{F, S}) where {F, S}
    return length(MOI.get(model, MOI.ListOfConstraintIndices{F, S}()))
end

function MOI.get(model::Optimizer, ::MOI.ListOfModelAttributesSet)
    attributes = MOI.AbstractModelAttribute[]
    if model.is_objective_set
        F = MOI.get(model, MOI.ObjectiveFunctionType())
        push!(attributes, MOI.ObjectiveFunction{F}())
    end
    if !isnothing(model.objective_sense)
        push!(attributes, MOI.ObjectiveSense())
    end
    if model.has_usercut_cb
        push!(attributes, MOI.UserCutCallback())
    end
    if model.has_lazyconstraint_cb
        push!(attributes, MOI.LazyConstraintCallback())
    end
    if model.has_pricing_cb
        push!(attributes, BD.PricingCallback())
    end
    if model.has_initialcol_cb
        push!(attributes, BD.InitialColumnsCallback())
    end
    return attributes
end

############################################################################################
# is_valid methods
###########################################################################################
_is_valid(::Type{<:MOI.LessThan{Float64}}, lb, ub, kind) = ub == _LESS
_is_valid(::Type{<:MOI.GreaterThan{Float64}}, lb, ub, kind) = lb == _GREATER
_is_valid(::Type{<:MOI.EqualTo{Float64}}, lb, ub, kind) = lb == ub == _EQUAL
_is_valid(::Type{<:MOI.Interval{Float64}}, lb, ub, kind) = lb == ub == _INTERVAL
_is_valid(::Type{<:MOI.ZeroOne}, lb, ub, kind) = kind == _BINARY
_is_valid(::Type{<:MOI.Integer}, lb, ub, kind) = kind == _INT

function MOI.is_valid(
    model::Optimizer, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.VariableIndex,S}
    if !haskey(model.varinfos, MOI.VariableIndex(index.value))
        return false
    end
    varinfo = _info(model, index)
    return _is_valid(S, varinfo.lb_type, varinfo.ub_type, varinfo.kind)
end

function MOI.is_valid(
    model::Optimizer, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.ScalarAffineFunction,S}
    return haskey(model.constrinfos, index.value)
end

function MOI.is_valid(model::Optimizer, index::MOI.VariableIndex)
    return haskey(model.varinfos, index)
end

# ######################
# ### Get functions ####
# ######################

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    return getvalue(get_ip_dual_bound(model.result))
end

function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return getvalue(get_ip_primal_bound(model.result))
end

function MOI.get(model::Optimizer, attr::MOI.DualObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return getvalue(get_lp_dual_bound(model.result))
end

function MOI.get(model::Optimizer, ::MOI.RelativeGap)
    return ip_gap(model.result)
end

function MOI.get(model::Optimizer, attr::MOI.VariablePrimal, ref::MOI.VariableIndex)
    MOI.check_result_index_bounds(model, attr)
    id = getid(_info(model, ref).var) # This gets a coluna VarId
    primalsols = get_ip_primal_sols(model.result)
    if 1 <= attr.result_index <= length(primalsols)
        return get(primalsols[attr.result_index], id, 0.0)
    end
    return error("Invalid result index.")
end

function MOI.get(model::Optimizer, attr::MOI.VariablePrimal, refs::Vector{MOI.VariableIndex})
    MOI.check_result_index_bounds(model, attr)
    best_primal_sol = get_best_ip_primal_sol(model.result)
    if best_primal_sol === nothing
        @warn "Coluna did not find a primal feasible solution."
        return [NaN for ref in refs]
    end
    return [get(best_primal_sol, getid(model.varinfos[ref].var), 0.0) for ref in refs]
end

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    return convert_status(getterminationstatus(model.result))
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    primal_sol = get_best_ip_primal_sol(model.result)
    primal_sol === nothing && return MOI.NO_SOLUTION
    return convert_status(getstatus(primal_sol))
end

function MOI.get(model::Optimizer, attr::MOI.DualStatus)
    if attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    dual_sol = get_best_lp_dual_sol(model.result)
    dual_sol === nothing && return MOI.NO_SOLUTION
    return convert_status(getstatus(dual_sol))
end

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    return string(getterminationstatus(model.result))
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return length(get_ip_primal_sols(model.result))
end

function MOI.get(
    model::Optimizer, attr::MOI.ConstraintPrimal, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.VariableIndex,S}
    # TODO: throw if optimization in progress.
    MOI.check_result_index_bounds(model, attr)
    return MOI.get(model, MOI.VariablePrimal(), MOI.VariableIndex(index.value))
end

function MOI.get(model::Optimizer, attr::MOI.ConstraintPrimal, index::MOI.ConstraintIndex)
    # TODO: throw if optimization in progress.
    MOI.check_result_index_bounds(model, attr)
    constr = _info(model, index).constr
    best_primal_sol = get_best_ip_primal_sol(model.result)
    return constraint_primal(best_primal_sol, getid(constr))
end

MOI.get(model::Optimizer, ::MOI.NodeCount) = model.env.kpis.node_count
MOI.get(model::Optimizer, ::MOI.SolveTimeSec) = model.env.kpis.elapsed_optimization_time

function MOI.get(
    model::Optimizer, attr::MOI.ConstraintDual, 
    index::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}}
)
    MOI.throw_if_not_valid(model, index)
    dualsols = get_lp_dual_sols(model.result)
    sense = model.objective_sense == MOI.MAX_SENSE ? -1.0 : 1.0
    if 1 <= attr.result_index <= length(dualsols)
        return sense * get(dualsols[attr.result_index], getid(_info(model, index).constr), 0.0)
    end
    return error("Invalid result index.")
end

function _singlevarconstrdualval(dualsol, var, ::Type{<:MOI.GreaterThan})
    value, activebound = get(get_var_redcosts(dualsol), getid(var), (0.0, MathProg.LOWER))
    if !iszero(value) && activebound != MathProg.LOWER
        return 0.0
    end
    return value
end

function _singlevarconstrdualval(dualsol, var, ::Type{<:MOI.LessThan})
    value, activebound = get(get_var_redcosts(dualsol), getid(var), (0.0, MathProg.UPPER))
    if !iszero(value) && activebound != MathProg.UPPER
        return 0.0
    end
    return value
end

function _singlevarconstrdualval(dualsol, var, ::Type{<:MOI.EqualTo})
    value, _ = get(get_var_redcosts(dualsol), getid(var), (0.0, MathProg.LOWER))
    return value
end

function _singlevarconstrdualval(dualsol, var, ::Type{<:MOI.Interval})
    value, _ = get(get_var_redcosts(dualsol), getid(var), (0.0, MathProg.LOWER))
    return value
end

function MOI.get(
    model::Optimizer, attr::MOI.ConstraintDual, index::MOI.ConstraintIndex{F,S}
) where {F<:MOI.VariableIndex,S}
    # TODO: check if optimization in progress.
    MOI.check_result_index_bounds(model, attr)
    dualsols = get_lp_dual_sols(model.result)
    sense = model.objective_sense == MOI.MAX_SENSE ? -1.0 : 1.0
    if 1 <= attr.result_index <= length(dualsols)
        dualsol = dualsols[attr.result_index]
        varinfo = _info(model, MOI.VariableIndex(index.value)) 
        return sense * _singlevarconstrdualval(dualsol, varinfo.var, S)
    end
    error("Invalid result index.")
end

# Useful method to retrieve dual values of generated cuts because they don't 
# have MOI.ConstraintIndex
function MOI.get(
    model::Optimizer, attr::MOI.ConstraintDual, constrid::ConstrId
)
    # TODO: check if optimization in progress.
    MOI.check_result_index_bounds(model, attr)
    dualsols = get_lp_dual_sols(model.result)
    sense = model.objective_sense == MOI.MAX_SENSE ? -1.0 : 1.0
    if 1 <= attr.result_index <= length(dualsols)
        return sense * get(dualsols[attr.result_index], constrid, 0.0)
    end
    return error("Invalid result index.")
end
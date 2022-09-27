
# There are two levels of data for each element of a formulation (i.e. variables and 
# constraints).
# The first level is called "peren" (for perennial). It contains data that won't change for
# almost all the optimisation (e.g. the original cost of a variable, the original sense of 
# constraint...). Coluna provides methods to set these data because it can ease the setup
# of a formulation. Algorithm designers are free to use these method at their own risk.
# The second level is called "cur" (for current). It describes the current state of each
# element of the formulation.

getid(vc::AbstractVarConstr) = vc.id
getoriginformuid(vc::AbstractVarConstr) = getoriginformuid(getid(vc))

# no moi record for a single variable constraint
getmoirecord(vc::Variable) = vc.moirecord
getmoirecord(vc::Constraint) = vc.moirecord

# Variables
## Cost
"""
    getperencost(formulation, variable)
    getperencost(formulation, varid)

Return the cost as defined by the user of a variable in a formulation.
"""
getperencost(form::Formulation, varid::VarId) = getperencost(form, getvar(form, varid))
getperencost(::Formulation, var::Variable) = var.perendata.cost

"""
    getcurcost(formulation, variable)
    getcurcost(formulation, varid)

Return the current cost of the variable in the formulation.
"""
getcurcost(form::Formulation, varid::VarId) = getcurcost(form, getvar(form, varid))
getcurcost(::Formulation, var::Variable) = var.curdata.cost

"""
    setperencost!(formulation, variable, cost)
    setperencost!(formulation, varid, cost)

Set the perennial cost of a variable and then propagate change to the current cost of the
variable.
"""
function setperencost!(form::Formulation, var::Variable, cost)
    var.perendata.cost = cost
    return setcurcost!(form, var, cost)
end
setperencost!(form::Formulation, varid::VarId, cost) = setperencost!(form, getvar(form, varid), cost)

"""
    setcurcost!(formulation, varid, cost::Float64)
    setcurcost!(formulation, variable, cost::Float64)

Set the current cost of variable in the formulation.
If the variable is active and explicit, this change is buffered before application to the 
subsolver.
"""
function setcurcost!(form::Formulation, var::Variable, cost)
    var.curdata.cost = cost
    if isexplicit(form, var) && iscuractive(form, var)
        change_cost!(form.buffer, getid(var))
    end
    return
end

function setcurcost!(form::Formulation, varid::VarId, cost)
    return setcurcost!(form, getvar(form, varid), cost)
end

## Lower bound
"""
    setperenlb!(formulation, var, rhs)

Set the perennial lower bound of a variable in a formulation.
Change is propagated to the current lower bound of the variable.
"""
function setperenlb!(form::Formulation, var::Variable, lb)
    var.perendata.lb = lb
    _setperenbounds_wrt_perenkind!(form, var, getperenkind(form, var))
    return setcurlb!(form, var, lb)
end

"""
    getperenlb(formulation, varid)
    getperenlb(formulation, var)

Return the lower bound as defined by the user of a variable in a formulation.
"""
getperenlb(form::Formulation, varid::VarId) = getperenlb(form, getvar(form, varid))
getperenlb(::Formulation, var::Variable) = var.perendata.lb

"""
    getcurlb(formulation, varid)
    getcurlb(formulation, var)

Return the current lower bound of a variable in a formulation.
"""
getcurlb(form::Formulation, varid::VarId) = getcurlb(form, getvar(form, varid))
getcurlb(::Formulation, var::Variable) = var.curdata.lb

"""
    setcurlb!(formulation, varid, lb::Float64)
    setcurlb!(formulation, var, lb::Float64)

Set the current lower bound of a variable in a formulation.
If the variable is active and explicit, change is buffered before application to the
subsolver.
If the variable had fixed value, it unfixes the variable.
"""
function setcurlb!(form::Formulation, var::Variable, lb)
    if isfixed(form, var)
        @warn "Cannot change lower bound of fixed variable."
        return
    end

    var.curdata.lb = lb
    if isexplicit(form, var) && iscuractive(form, var)
        change_bound!(form.buffer, getid(var))
    end
    _setcurbounds_wrt_curkind!(form, var, getcurkind(form, var))
    return
end
setcurlb!(form::Formulation, varid::VarId, lb) =  setcurlb!(form, getvar(form, varid), lb)


## Upper bound
"""
    setperenub!(formulation, var, rhs)

Set the perennial upper bound of a variable in a formulation.
Change is propagated to the current upper bound of the variable.
"""
function setperenub!(form::Formulation, var::Variable, ub)
    var.perendata.ub = ub
    _setperenbounds_wrt_perenkind!(form, var, getperenkind(form, var))
    return setcurub!(form, var, ub)
end

"""
    getperenub(formulation, varid)
    getperenub(formulation, var)

Return the upper bound as defined by the user of a variable in a formulation.
"""
getperenub(form::Formulation, varid::VarId) = getperenub(form, getvar(form, varid))
getperenub(::Formulation, var::Variable) = var.perendata.ub

"""
    getcurub(formulation, varid)
    getcurub(formulation, var)

Return the current upper bound of a variable in a formulation.
"""
getcurub(form::Formulation, varid::VarId) = getcurub(form, getvar(form, varid))
getcurub(::Formulation, var::Variable) = var.curdata.ub

"""
    setcurub!(formulation, varid, ub::Float64)
    setcurub!(formulation, var, ub::Float64)

Set the current upper bound of a variable in a formulation.
If the variable is active and explicit, change is buffered before application to the
subsolver.
If the variable had fixed value, it unfixes the variable.
"""
function setcurub!(form::Formulation, var::Variable, ub)
    if isfixed(form, var)
        @warn "Cannot change upper bound of fixed variable."
        return
    end

    var.curdata.ub = ub
    if isexplicit(form, var) && iscuractive(form, var)
        change_bound!(form.buffer, getid(var))
    end
    _setcurbounds_wrt_curkind!(form, var, getcurkind(form, var))
    return
end
setcurub!(form::Formulation, varid::VarId, ub) = setcurub!(form, getvar(form, varid), ub)

## fix cur bounds
function _propagate_fix!(form, var_id, value)
    var_members = @view getcoefmatrix(form)[:, var_id]
    for (constr_id, coef) in var_members
        fixed_term = value * coef
        rhs = getcurrhs(form, constr_id)
        setcurrhs!(form, constr_id, rhs - fixed_term)
    end
    return
end

"""
    fix!(formulation, varid, value)
    fix!(formulation, variable, value)
    
Fixes the current bounds of an active and explicit variable to a given value.
It deactives the variable and updates the rhs of the constraints that involve this variable.

You must use `unfix!` to change the bounds of the variable.
"""
fix!(form::Formulation, varid::VarId, value) = fix!(form, getvar(form, varid), value)
function fix!(form::Formulation, var::Variable, value)
    if !isfixed(form, var) && isexplicit(form, var) && iscuractive(form, var)
        deactivate!(form, var)
        var.curdata.is_fixed = true
        var.curdata.ub = value
        var.curdata.lb = value
        _fixvar!(form.manager, var)
        _propagate_fix!(form, getid(var), value)
        return true
    end
    name = getname(form, var)
    @warn "Cannot fix variable $name because it is non-explicit, or unactive, or already fixed."
    return false
end

"""
    unfix!(formulation, varid)
    unfix!(formulation, variable)

Unfixes the variable.
It activates the variable and update the rhs of the constraints that involve this variable.
"""
unfix!(form::Formulation, varid::VarId) = unfix!(form, getvar(form, varid))
function unfix!(form::Formulation, var::Variable)
    if isfixed(form, var) && isexplicit(form, var) && !iscuractive(form, var)
        value = getcurlb(form, var)
        var.curdata.is_fixed = false
        _unfixvar!(form.manager, var)
        activate!(form, var)
        _propagate_fix!(form, getid(var), -value)
        return true
    end
    name = getname(form, var)
    @warn "Cannot unfix variable $name because it is unfixed, non-explicit, or active."
    return false
end

"""
    getfixedvars(formulation)

Returns a set that contains the ids of the fixed variables in the formulation.
"""
getfixedvars(form::Formulation) = _fixedvars(form.manager)

# Constraint
## rhs
"""
    getperenrhs(formulation, constraint)
    getperenrhs(formulation, constrid)

Return the right-hand side as defined by the user of a constraint in a formulation.
"""
getperenrhs(form::Formulation, constrid::ConstrId) = getperenrhs(form, getconstr(form, constrid))
getperenrhs(::Formulation, constr::Constraint) = constr.perendata.rhs

"""
    getcurrhs(formulation, constraint)
    getcurrhs(formulation, constrid)

Return the current right-hand side of a constraint in a formulation.
"""
getcurrhs(form::Formulation, constrid::ConstrId) = getcurrhs(form, getconstr(form, constrid))
getcurrhs(::Formulation, constr::Constraint) = constr.curdata.rhs

"""
    setperenrhs!(formulation, constr, rhs)
    setperenrhs!(formulation, constrid, rhs)

Set the perennial rhs of a constraint in a formulation.
Change is propagated to the current rhs of the constraint.
"""
function setperenrhs!(form::Formulation, constr::Constraint, rhs)
    constr.perendata.rhs = rhs
    return setcurrhs!(form, constr, rhs)
end
setperenrhs!(form::Formulation, constrid::ConstrId, rhs) =
    setperenrhs!(form, getconstr(form, constrid), rhs)

"""
    setcurrhs(formulation, constraint, rhs::Float64)
    setcurrhs(formulation, constrid, rhs::Float64)

Set the current right-hand side of a constraint in a formulation. 
If the constraint is active and explicit, this change is buffered before application to the
subsolver.

**Warning** : if you change the rhs of a single variable constraint, make sure that you
perform bound propagation before calling the subsolver of the formulation.
"""
function setcurrhs!(form::Formulation, constr::Constraint, rhs::Float64) 
    constr.curdata.rhs = rhs
    if isexplicit(form, constr) && iscuractive(form, constr)
        change_rhs!(form.buffer, getid(constr))
    end
    return
end

setcurrhs!(form::Formulation, constrid::ConstrId, rhs::Float64) = 
    setcurrhs!(form, getconstr(form, constrid), rhs)

# Variable & Constraints
## kind
"""
    getperenkind(formulation, varconstr)
    getperenkind(formulation, varconstrid)

Return the kind as defined by the user of a variable or a constraint in a formulation.

Kinds of variable (`enum VarKind`) are `Continuous`, `Binary`, or `Integ`.
    
Kinds of a constraint (`enum ConstrKind`) are : 
 - `Essential` when the constraint structures the problem
 - `Facultative` when the constraint does not structure the problem
 - `SubSystem` (to do)

The kind of a constraint cannot change.
"""
getperenkind(form::Formulation, varid::VarId) = getperenkind(form, getvar(form, varid))
getperenkind(::Formulation, var::Variable) = var.perendata.kind
getperenkind(form::Formulation, constrid::ConstrId) = getperenkind(form, getconstr(form, constrid))
getperenkind(::Formulation, constr::Constraint) = constr.perendata.kind

"""
    getcurkind(formulation, variable)
    getcurkind(formulation, varid)

Return the current kind of a variable in a formulation.
"""
getcurkind(form::Formulation, varid::VarId) = getcurkind(form, getvar(form, varid))
getcurkind(::Formulation, var::Variable) = var.curdata.kind

function _setperenbounds_wrt_perenkind!(form::Formulation, var::Variable, kind::VarKind)
    if kind == Binary
        if getperenlb(form, var) < 0
            setperenlb!(form, var, 0.0)
        end
        if getperenub(form, var) > 1
            setperenub!(form, var, 1.0)
        end
    elseif kind == Integer
        setperenlb!(form, var, ceil(getperenlb(form, var)))
        setperenub!(form, var, floor(getperenub(form, var)))
    end
end

"""
    setperenkind!(formulation, variable, kind)
    setperenkind!(formulation, varid, kind)

Set the perennial kind of a variable in a formulation.
This change is then propagated to the current kind of the variable.
"""
function setperenkind!(form::Formulation, var::Variable, kind::VarKind)
    var.perendata.kind = kind
    _setperenbounds_wrt_perenkind!(form, var, kind)
    return setcurkind!(form, var, kind)
end
setperenkind!(form::Formulation, varid::VarId, kind::VarKind) = setperenkind!(form, getvar(form, varid), kind)

function _setcurbounds_wrt_curkind!(form::Formulation, var::Variable, kind::VarKind)
    if kind == Binary
        if getcurlb(form, var) < 0
            setcurlb!(form, var, 0.0)
        end
        if getcurub(form, var) > 1
            setcurub!(form, var, 1.0)
        end
    elseif kind == Integer
        setcurlb!(form, var, ceil(getcurlb(form, var)))
        setcurub!(form, var, floor(getcurub(form, var)))
    end
end

"""
    setcurkind!(formulation, variable, kind::VarKind)
    setcurkind!(formulation, varid, kind::VarKind)

Set the current kind of a variable in a formulation.
If the variable is active and explicit, this change is buffered before
application to the subsolver
"""
function setcurkind!(form::Formulation, var::Variable, kind::VarKind)
    var.curdata.kind = kind
    _setcurbounds_wrt_curkind!(form, var, kind)
    if isexplicit(form, var) && iscuractive(form, var)
        change_kind!(form.buffer, getid(var))
    end
    return
end
setcurkind!(form::Formulation, varid::VarId, kind::VarKind) = setcurkind!(form, getvar(form, varid), kind) 

## sense
function _senseofvar(lb::Float64, ub::Float64)
    lb >= 0 && return Positive
    ub <= 0 && return Negative
    return Free 
end

"""
    getperensense(formulation, varconstr)
    getperensense(formulation, varconstrid)

Return the sense as defined by the user of a variable or a constraint in a formulation.

Senses or a variable are (`enum VarSense`)  `Positive`, `Negative`, and `Free`.
Senses or a constraint are (`enum ConstrSense`) `Greater`, `Less`, and `Equal`.

The perennial sense of a variable depends on its perennial bounds.
"""
getperensense(form::Formulation, varid::VarId) = getperensense(form, getvar(form, varid))
getperensense(form::Formulation, var::Variable) = _senseofvar(getperenlb(form, var), getperenub(form, var))
getperensense(form::Formulation, constrid::ConstrId) = getperensense(form, getconstr(form, constrid))
getperensense(::Formulation, constr::Constraint) = constr.perendata.sense

"""
    getcursense(formulation, varconstr)
    getcursense(formulation, varconstrid)

Return the current sense of a variable or a constraint in a formulation.
The current sense of a variable depends on its current bounds.
"""
getcursense(form::Formulation, varid::VarId) = getcursense(form, getvar(form, varid))
getcursense(form::Formulation, var::Variable) = _senseofvar(getcurlb(form, var), getcurub(form, var))
getcursense(form::Formulation, constrid::ConstrId) = getcursense(form, getconstr(form, constrid))
getcursense(::Formulation, constr::Constraint) = constr.curdata.sense

"""
    setperensense!(form, constr, sense)
    setperensense!(form, constrid, sense)

Set the perennial sense of a constraint in a formulation.
Change is propagated to the current sense of the constraint.

**Warning** : if you set the sense of a single var constraint, make sure you perform bound
propagation before calling the subsolver of the formulation.
"""
function setperensense!(form::Formulation, constr::Constraint, sense::ConstrSense)
    constr.perendata.sense = sense
    return setcursense!(form, constr, sense)
end

setperensense!(form::Formulation, constrid::ConstrId, sense::ConstrSense) =
    setperensense!(form, getconstr(form, constrid), sense)

"""
    setcursense!(formulation, constr, sense::ConstrSense)
    setcursense!(formulation, constrid, sense::ConstrSense)

Set the current sense of a constraint in a formulation.

This method is not applicable to variables because the sense of a variable depends on its
bounds.

**Warning** : if you set the sense of a single var constraint, make sure you perform bound
propagation before calling the subsolver of the formulation.
"""
function setcursense!(form::Formulation, constr::Constraint, sense::ConstrSense)
    constr.curdata.sense = sense
    if isexplicit(form, constr) 
        change_rhs!(form.buffer, getid(constr)) # it's sense & rhs
    end
    return
end

setcursense!(form::Formulation, constrid::ConstrId, sense::ConstrSense) =
    setcursense!(form, getconstr(form, constrid), sense)

## inc_val
"""
    getperenincval(formulation, varconstrid)
    getperenincval(formulation, varconstr)

Return the incumbent value as defined by the user of a variable or a constraint in a formulation. 
The incumbent value is the primal value associated to a variable or the dual value associated to
a constraint.
"""
getperenincval(form::Formulation, varid::VarId) = getperenincval(form, getvar(form, varid))
getperenincval(::Formulation, var::Variable) = var.perendata.inc_val
getperenincval(form::Formulation, constrid::ConstrId) = getperenincval(form, getconstr(form, constrid))
getperenincval(::Formulation, constr::Constraint) = constr.perendata.inc_val

"""
    getcurincval(formulation, varconstrid)
    getcurincval(formulation, varconstr)

Return the current incumbent value of a variable or a constraint in a formulation.
"""
getcurincval(form::Formulation, varid::VarId) = getcurincval(form, getvar(form, varid))
getcurincval(::Formulation, var::Variable) = var.curdata.inc_val
getcurincval(form::Formulation, constrid::ConstrId) = getcurincval(form, getconstr(form, constrid))
getcurincval(::Formulation, constr::Constraint) = constr.curdata.inc_val

"""
    setcurincval!(formulation, varconstrid, value::Real)

Set the current incumbent value of a variable or a constraint in a formulation.
"""
setcurincval!(::Formulation, var::Variable, inc_val::Real) =
    var.curdata.inc_val = inc_val

setcurincval!(form::Formulation, varid::VarId, inc_val) = 
    setcurincval!(form, getvar(form, varid), inc_val)

setcurincval!(::Formulation, constr::Constraint, inc_val::Real) =
    constr.curdata.inc_val = inc_val

setcurincval!(form::Formulation, constrid::ConstrId, inc_val) = 
    setcurincval!(form, getconstr(form, constrid), inc_val)

## fixed
isfixed(form::Formulation, varid::VarId) = isfixed(form, getvar(form, varid))
isfixed(::Formulation, var::Variable) = var.curdata.is_fixed

## active
"""
    isperenactive(formulation, varconstrid)
    isperenactive(formulation, varconstr)

Return `true` if the variable or the constraint is active in the formulation; `false` otherwise.
A variable (or a constraint) is active if it is used in the formulation. You can fake the 
deletion of the variable by deativate it. This allows you to keep the variable if you want 
to reactivate it later.
"""
isperenactive(form::Formulation, varid::VarId) = isperenactive(form, getvar(form, varid))
isperenactive(::Formulation, var::Variable) = var.perendata.is_active
isperenactive(form::Formulation, constrid::ConstrId) = isperenactive(form, getconstr(form, constrid))
isperenactive(::Formulation, constr::Constraint) = constr.perendata.is_active

"""
    iscuractive(formulation, varconstrid)
    iscuractive(formulation, varconstr)

Return `true` if the variable or the constraint is currently active; `false` otherwise.
"""
iscuractive(form::Formulation, varid::VarId) = iscuractive(form, getvar(form, varid))
iscuractive(::Formulation, var::Variable) = var.curdata.is_active
iscuractive(form::Formulation, constrid::ConstrId) = iscuractive(form, getconstr(form, constrid))
iscuractive(::Formulation, constr::Constraint) = constr.curdata.is_active


## activate!
function _activate!(form::Formulation, varconstr::AbstractVarConstr)
    if isexplicit(form, varconstr) && !iscuractive(form, varconstr)
        add!(form.buffer, getid(varconstr))
    end
    varconstr.curdata.is_active = true
    return
end

"""
    activate!(formulation, varconstrid)
    activate!(formulation, varconstr)

Activate a variable or a constraint in a formulation.

    activate!(formulation, function)

It is also possible to activate variables and constraints of a formulation such that 
`function(varconstrid)` returns `true`.
"""
function activate!(form::Formulation, constr::Constraint)
    _activate!(form, constr)
    for varid in constr.art_var_ids
        _activate!(form, getvar(form, varid))
    end
    return
end

activate!(form::Formulation, var::Variable) = _activate!(form, var)

function activate!(form::Formulation, varconstrid::Id{VC}) where {VC <: AbstractVarConstr}
    return activate!(form, getelem(form, varconstrid))
end

function activate!(form::Formulation, f::Function)
    for (varid, var) in getvars(form)
        if !iscuractive(form, varid) && f(varid)
            activate!(form, var)
        end
    end
    for (constrid, constr) in getconstrs(form)
        if !iscuractive(form, constrid) && f(constrid)
            activate!(form, constr)
        end
    end
    return
end

## deactivate!
function _deactivate!(form::Formulation, varconstr::AbstractVarConstr)
    if isexplicit(form, varconstr) && iscuractive(form, varconstr)
        remove!(form.buffer, getid(varconstr))
    end
    varconstr.curdata.is_active = false
    return
end

"""
    deactivate!(formulation, varconstrid)
    deactivate!(formulation, varconstr)

Deactivate a variable or a constraint in a formulation.

    deactivate!(formulation, function)

It is also possible to deactivate variables and constraints such that 
`function(varconstrid)` returns `true`.
"""
function deactivate!(form::Formulation, constr::Constraint)
    _deactivate!(form, constr)
    for varid in constr.art_var_ids
        _deactivate!(form, getvar(form, varid))
    end
    return
end
deactivate!(form::Formulation, var::Variable) = _deactivate!(form, var)
deactivate!(form::Formulation, varconstrid::Id{VC}) where {VC<:AbstractVarConstr} = deactivate!(form, getelem(form, varconstrid))

function deactivate!(form::Formulation, f::Function)
    for (varid, var) in getvars(form)
        if iscuractive(form, var) && f(varid)
            deactivate!(form, var)
        end
    end
    for (constrid, constr) in getconstrs(form)
        if iscuractive(form, constr) && f(constrid)
            deactivate!(form, constr)
        end
    end
    return
end

## delete
"""
    delete!(formulation, varconstr)
    delete!(formulation, varconstrid)

Delete a variable or a constraint from a formulation.
"""
function Base.delete!(form::Formulation, var::Variable)
    varid = getid(var)
    definitive_deletion!(form.buffer, var)
    delete!(form.manager.vars, varid)
    return
end
Base.delete!(form::Formulation, id::VarId) = delete!(form, getvar(form, id))

function Base.delete!(form::Formulation, constr::Constraint)
    definitive_deletion!(form.buffer, constr)
    constrid = getid(constr)
    coefmatrix = getcoefmatrix(form)
    varids = VarId[]
    for (varid, _) in @view coefmatrix[constrid, :]
        push!(varids, varid)
    end
    for varid in varids
        coefmatrix[constrid, varid] = 0.0
    end
    delete!(form.manager.constrs, constrid)
    return
end
Base.delete!(form::Formulation, id::ConstrId) = delete!(form, getconstr(form, id))

## explicit
"""
    isexplicit(formulation, varconstr)
    isexplicit(formulation, varconstrid)

Return `true` if a variable or a constraint is explicit in a formulation; `false` otherwise.
"""
isexplicit(form::Formulation, varid::VarId) = isexplicit(form, getvar(form, varid))
isexplicit(::Formulation, var::Variable) = var.perendata.is_explicit
isexplicit(form::Formulation, constrid::ConstrId) = isexplicit(form, getconstr(form, constrid))
isexplicit(::Formulation, constr::Constraint) = constr.perendata.is_explicit

## name
"""
    getname(formulation, varconstr)
    getname(formulation, varconstrid)

Return the name of a variable or a constraint in a formulation.
"""
getname(form::Formulation, varid::VarId) = getvar(form, varid).name
getname(::Formulation, var::Variable) = var.name
getname(form::Formulation, constrid::ConstrId) = getconstr(form, constrid).name
getname(::Formulation, constr::Constraint) = constr.name

## branching_priority
"""
    getbranchingpriority(formulation, var)
    getbranchingpriority(formulation, varid)

Return the branching priority of a variable
"""
getbranchingpriority(form::Formulation, varid::VarId) = getvar(form, varid).branching_priority
getbranchingpriority(::Formulation, var::Variable) = var.branching_priority

# Reset (this method is used only in tests... @guimarqu doesn't know if we should keep it)
"""
    reset!(form, var)
    reset!(form, varid)
    reset!(form, constr)
    reset!(form, constraint)

doc todo
"""
function reset!(form::Formulation, var::Variable)
    setcurcost!(form, var, getperencost(form, var))
    setcurlb!(form, var, getperenlb(form, var))
    setcurub!(form, var, getperenub(form, var))
    setcurkind!(form, var, getperenkind(form, var))
    setcurincval!(form, var, getperenincval(form, var))
    if isperenactive(form, var)
        activate!(form, var)
    else
        deactivate!(form, var)
    end
    return
end
reset!(form::Formulation, varid::VarId)  = reset!(form, getvar(form, varid)) 

function reset!(form::Formulation, constr::Constraint)
    setcurrhs!(form, constr, getperenrhs(form, constr))
    setcursense!(form, constr, getperensense(form, constr))
    setcurincval!(form, constr , getperenincval(form, constr))
    if isperenactive(form, constr)
        activate!(form, constr)
    else
        deactivate!(form, constr)
    end
    return
end
reset!(form::Formulation, constrid::ConstrId) = reset!(form, getconstr(form,constrid))

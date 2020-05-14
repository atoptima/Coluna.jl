# Variables
## Cost
"""
    getperencost(formulation, variable)
    getperencost(formulation, varid)

Return the cost as defined by the user of a variable in a formulation.

*Performance note* : use a variable rather than its id.
"""
getperencost(form::Formulation, varid::VarId) = getperencost(form, getvar(form, varid))
getperencost(form::Formulation, var::Variable) = var.peren_data.cost

"""
    getcurcost(formulation, variable)
    getcurcost(formulation, varid)

Return the current cost of the variable in the formulation.
"""
getcurcost(form::Formulation, varid::VarId) = form.manager.var_datas[varid].cost
getcurcost(form::Formulation, var::Variable) = getcurcost(form, getid(var))

"""
    setcurcost!(formulation, varid, cost::Float64)
    setcurcost!(formulation, variable, cost::Float64)

Set the current cost of variable in the formulation.
If the variable is active and explicit, this change is buffered before application to the 
subsolver.

*Performance note* : use a variable rather than its id.
"""
function setcurcost!(form::Formulation, var::Variable, cost::Float64)
    varid = getid(var)
    form.manager.var_datas[varid].cost = cost
    if iscurexplicit(form, var) && iscuractive(form, var)
        change_cost!(form.buffer, varid)
    end
    return
end

function setcurcost!(form::Formulation, varid::VarId, cost::Float64)
    return setcurcost!(form, getvar(form, varid), cost)
end

## Lower bound
"""
    getperenlb(formulation, varid)
    getperenlb(formulation, var)

Return the lower bound as defined by the user of a variable in a formulation.

*Performance note* : use a variable rather than its id.
"""
getperenlb(form::Formulation, varid::VarId) = getperenlb(form, getvar(form, varid))
getperenlb(form::Formulation, var::Variable) = var.peren_data.lb

"""
    getcurlb(formulation, varid)
    getcurlb(formulation, var)

Return the current lower bound of a variable in a formulation.
"""
getcurlb(form::Formulation, varid::VarId) = form.manager.var_datas[varid].lb
getcurlb(form::Formulation, var::Variable) = getcurlb(form, getid(var))

"""
    setcurlb!(formulation, varid, lb::Float64)
    setcurlb!(formulation, var, lb::Float64)

Set the current lower bound of a variable in a formulation.
If the variable is active and explicit, change is buffered before application to the
subsolver.

*Performance note* : use a variable rather than its id.
"""
function setcurlb!(form::Formulation, var::Variable, lb::Float64)
    varid = getid(var)
    form.manager.var_datas[varid].lb = lb
    if iscurexplicit(form, var) && iscuractive(form, var)
        change_bound!(form.buffer, varid)
    end
    return
end
setcurlb!(form::Formulation, varid::VarId, lb::Float64) =  setcurlb!(form, getvar(form, varid), lb)


## Upper bound
"""
    getperenub(formulation, varid)
    getperenub(formulation, var)

Return the upper bound as defined by the user of a variable in a formulation.

*Performance note* : use the variable rather than its id.
"""
getperenub(form::Formulation, varid::VarId) = getperenub(form, getvar(form, varid))
getperenub(form::Formulation, var::Variable) = var.peren_data.ub

"""
    getcurub(formulation, varid)
    getcurub(formulation, var)

Return the current upper bound of a variable in a formulation.
"""
#getcurub(form::Formulation, varid::VarId) = form.manager.var_ubs[getuid(varid)]
getcurub(form::Formulation, varid::VarId) = form.manager.var_datas[varid].ub #get(form.manager.var_ubs, varid, Inf)
getcurub(form::Formulation, var::Variable) = getcurub(form, getid(var))

"""
    setcurub!(formulation, varid, ub::Float64)
    setcurub!(formulation, var, ub::Float64)

Set the current upper bound of a variable in a formulation.
If the variable is active and explicit, change is buffered before application to the
subsolver.

*Performance note* : use a variable rather than its id.
"""
function setcurub!(form::Formulation, var::Variable, ub::Float64)
    varid = getid(var)
    form.manager.var_datas[varid].ub = ub
    if iscurexplicit(form, var) && iscuractive(form, var)
        change_bound!(form.buffer, varid)
    end
    return
end
setcurub!(form::Formulation, varid::VarId, ub::Float64) = setcurub!(form, getvar(form, varid), ub)


# Constraint
## rhs
"""
    getperenrhs(formulation, constraint)
    getperenrhs(formulation, constrid)

Return the right-hand side as defined by the user of a constraint in a formulation.

*Performance note* : use a constraint rather than its id.
"""
getperenrhs(form::Formulation, constr::Constraint) = constr.peren_data.rhs
getperenrhs(form::Formulation, constrid::ConstrId) = getperenrhs(form, getconstr(form, constrid))

"""
    getcurrhs(formulation, constraint)
    getcurrhs(formulation, constrid)

Return the current right-hand side of a constraint in a formulation.
"""
getcurrhs(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].rhs
getcurrhs(form::Formulation, constr::Constraint) = getcurrhs(form, getid(constr))

"""
    setcurrhs(formulation, constraint, rhs::Float64)
    setcurrhs(formulation, constrid, rhs::Float64)

Set the current right-hand side of a constraint in a formulation. 
If the constraint is active and explicit, this change is buffered before application to the
subsolver.

*Performance note* : use a constraint rather than its id.
"""
function setcurrhs!(form::Formulation, constr::Constraint, rhs::Float64) 
    constrid = getid(constr)
    form.manager.constr_datas[constrid].rhs = rhs
    if iscurexplicit(form, constr) && iscuractive(form, constr)
        change_rhs!(form.buffer, constrid)
    end
    return
end
setcurrhs!(form::Formulation, constrid::ConstrId, rhs::Float64) = setcurrhs!(form, getconstr(form, constrid), rhs)


# Variable & Constraints
## kind
"""
    getperenkind(formulation, varconstr)
    getperenkind(formulation, varconstrid)

Return the kind as defined by the user of a variable or a constraint in a formulation.

Kinds of variable (`enum VarKind`) are `Continuous`, `Binary`, or `Integ`.
    
Kinds of a constraint (`enum ConstrKind`) are : 
 - `Core` when the constraint structures the problem
 - `Facultative` when the constraint does not structure the problem
 - `SubSystem` (to do)

*Performance note* : use a variable or a constraint rather than its id.
"""
getperenkind(form::Formulation, varid::VarId) = getperenkind(form, getvar(form, varid))
getperenkind(form::Formulation, var::Variable) = var.peren_data.kind
getperenkind(form::Formulation, constrid::ConstrId) = getperenkind(form, getconstr(form, constrid))
getperenkind(form::Formulation, constr::Constraint) = constr.peren_data.kind

"""
    getcurkind(formulation, varconstr)
    getcurkind(formulation, varconstrid)

Return the current kind of a variable or a constraint in a formulation.
"""
getcurkind(form::Formulation, varid::VarId) = form.manager.var_datas[varid].kind
getcurkind(form::Formulation, var::Variable) = getcurkind(form, getid(var))
getcurkind(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].kind
getcurkind(form::Formulation, constr::Constraint) = getcurkind(form, getid(constr))

"""
    setcurkind!(formulation, variable, kind::VarKind)
    setcurkind!(formulation, varid, kind::VarKind)
    setcurkind!(formulation, constraint, kind::ConstrKind)
    setcurkind!(formulation, constrid, kind::ConstrKind)

Set the current kind of a variable or a constraint in a formulation.
If the variable or the constraint is active and explicit, this change is buffered before
application to the subsolver
"""
function setcurkind!(form::Formulation, varid::VarId, kind::VarKind)
    form.manager.var_datas[varid].kind = kind
    if iscurexplicit(form, varid) && iscuractive(form, varid)
        change_kind!(form.buffer, varid)
    end
    return
end
setcurkind!(form::Formulation, var::Variable, kind::VarKind) = setcurkind!(form, getid(var), kind)
function setcurkind!(form::Formulation, constrid::ConstrId, kind::ConstrKind)
    form.manager.constr_datas[constrid].kind = kind
    if iscurexplicit(form, constrid) && iscuractive(form, constrid)
        change_kind!(form.buffer, constrid)
    end
    return
end
setcurkind!(form::Formulation, constr::Constraint, kind::ConstrKind) = setcurkind!(form, getid(constr), kind) 


## sense
"""
    getperensense(formulation, varconstr)
    getperensense(formulation, varconstrid)

Return the sense as defined by the user of a variable or a constraint in a formulation.

Senses or a variable are (`enum VarSense`)  `Positive`, `Negative`, and `Free`.
Senses or a constraint are (`enum ConstrSense`) `Greater`, `Less`, and `Equal`.

*Performance note* : use a variable or a constraint rather than its id.
"""
getperensense(form::Formulation, varid::VarId) = getperensense(form, getvar(form, varid))
getperensense(form::Formulation, var::Variable) = var.peren_data.sense
getperensense(form::Formulation, constrid::ConstrId) = getperensense(form, getconstr(form, constrid))
getperensense(form::Formulation, constr::Constraint) = constr.peren_data.sense

"""
    getcursense(formulation, varconstr)
    getcursense(formulation, varconstrid)

Return the current sense of a variable or a constraint in a formulation.
"""
getcursense(form::Formulation, varid::VarId) = form.manager.var_datas[varid].sense
getcursense(form::Formulation, var::Variable) = getcursense(form, getid(var))
getcursense(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].sense
getcursense(form::Formulation, constr::Constraint) = getcursense(form, getid(constr))

"""
    setcursense!(formulation, constr, sense::ConstrSense)
    setcursense!(formulation, constrid, sense::ConstrSense)

Set the current sense of a constraint in a formulation.
"""
function setcursense!(form::Formulation, varid::VarId, sense::VarSense)
    form.manager.var_datas[varid].sense = sense
    if iscurexplicit(form, varid) 
        #change_sense!(form.buffer, getvar(form, varid))
    end
    return
end
setcursense!(form::Formulation, var::Variable, sense::VarSense) = setcursense!(form, getid(var), sense)
function setcursense!(form::Formulation, constrid::ConstrId, sense::ConstrSense)
    form.manager.constr_datas[constrid].sense = sense
    if iscurexplicit(form, constrid) 
        #change_sense!(form.buffer, getvar(form, varid))
    end
    return
end
setcursense!(form::Formulation, constr::Constraint, sense::ConstrSense) = setcursense!(form, getid(constr), sense)

## inc_val
"""
    getperenincval(formulation, varconstrid)
    getperenincval(formulation, varconstr)

Return the incumbent value as defined by the user of a variable or a constraint in a formulation. 
The incumbent value is ?
"""
getperenincval(form::Formulation, varid::VarId) = getperenincval(form, getvar(form, varid))
getperenincval(form::Formulation, var::Variable) = var.peren_data.inc_val
getperenincval(form::Formulation, constrid::ConstrId) = getperenincval(form, getconstr(form, constr))
getperenincval(form::Formulation, constr::Constraint) = constr.peren_data.inc_val

"""
    getcurincval(formulation, varconstrid)
    getcurincval(formulation, varconstr)

Return the current incumbent value of a variable or a constraint in a formulation.
"""
getcurincval(form::Formulation, varid::VarId) = form.manager.var_datas[varid].inc_val
getcurincval(form::Formulation, var::Variable) = getcurincval(form, getid(var))
getcurincval(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].inc_val 
getcurincval(form::Formulation, constr::Constraint) = getcurincval(form, getid(constr))

"""
    setcurincval!(formulation, varconstrid, value::Real)

Set the current incumbent value of a variable or a constraint in a formulation.
"""
function setcurincval!(form::Formulation, varid::VarId, inc_val::Real)
    form.manager.var_datas[varid].inc_val = inc_val
    # if iscurexplicit(form, varid) 
    #     #change_inc_val!(form.buffer, getvar(form, varid))
    # end
    return
end
setcurincval!(form::Formulation, var::Variable, inc_val::Real) = setcurincval!(form, getid(var), inc_val)
function setcurincval!(form::Formulation, constrid::ConstrId, inc_val::Real)
    form.manager.constr_datas[constrid].inc_val = inc_val
    # if iscurexplicit(form, constrid) 
    #     #change_inc_val!(form.buffer, getconstr(form, constrid))
    # end
    return
end
setcurincval!(form::Formulation, constr::Constraint, inc_val::Real) = setcurincval!(form, getid(constr), inc_val)

## active
"""
    isperenactive(formulation, varconstrid)
    isperenactive(formulation, varconstr)

Return `true` if the variable or the constraint is active in the formulation; `false` otherwise.
A variable (or a constraint) is active if it is used in the formulation. You can fake the 
deletion of the variable by deativate it. This allows you to keep the variable if you want 
to reactivate it later.

*Performance note* : use a variable or a constraint rather than its id.
"""
isperenactive(form::Formulation, varid::VarId) = isperenactive(form, getvar(form, varid))
isperenactive(form::Formulation, var::Variable) = var.peren_data.is_active
isperenactive(form::Formulation, constrid::ConstrId) = isperenactive(form, getconstr(form, constrid))
isperenactive(form::Formulation, constr::Constraint) = constr.peren_data.is_active

"""
    iscuractive(formulation, varconstrid)
    iscuractive(formulation, varconstr)

Return `true` if the variable or the constraint is currently active; `false` otherwise.
"""
iscuractive(form::Formulation, varid::VarId) = form.manager.var_datas[varid].is_active
iscuractive(form::Formulation, var::Variable) = iscuractive(form, getid(var))
iscuractive(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].is_active
iscuractive(form::Formulation, constr::Constraint) = iscuractive(form, getid(constr))

function _setiscuractive!(form::Formulation, varid::VarId, is_active::Bool)
    form.manager.var_datas[varid].is_active = is_active
    return
end

function _setiscuractive!(form::Formulation, constrid::ConstrId, is_active::Bool) 
    form.manager.constr_datas[constrid].is_active = is_active
    return
end

function _activate!(form::Formulation, varconstrid::Id{VC}) where {VC<:AbstractVarConstr}
    if iscurexplicit(form, varconstrid) && !iscuractive(form, varconstrid)
        add!(form.buffer, varconstrid)
    end
    _setiscuractive!(form, varconstrid, true)
    return
end

"""
    activate!(formulation, varconstrid)
    activate!(formulation, varconstr)

Activate a variable or a constraint in a formulation.
"""
function activate!(form::Formulation, constrid::ConstrId)
    _activate!(form, constrid)
    constr = getconstr(form, constrid)
    for varid in constr.art_var_ids
        _activate!(form, varid)
    end
    return
end

activate!(form::Formulation, varid::VarId) = _activate!(form, varid)
activate!(form::Formulation, varconstr::AbstractVarConstr) = activate!(form, getid(varconstr))

function activate!(form::Formulation, f::Function)
    for (varid, _) in getvars(form)
        if !iscuractive(form, varid) && f(varid)
            activate!(form, varid)
        end
    end
    for (constrid, _) in getconstrs(form)
        if !iscuractive(form, constrid) && f(constrid)
            activate!(form, constrid)
        end
    end
    return
end

function _deactivate!(form::Formulation, varconstrid::Id{VC}) where {VC<:AbstractVarConstr}
    if iscurexplicit(form, varconstrid) && iscuractive(form, varconstrid)
        remove!(form.buffer, varconstrid)
    end
    _setiscuractive!(form, varconstrid, false)
    return
end

"""
    deactivate!(formulation, varconstrid)
    deactivate!(formulation, varconstr)

Deactivate a variable or a constraint in a formulation
"""
function deactivate!(form::Formulation, constrid::ConstrId)
    _deactivate!(form, constrid)
    constr = getconstr(form, constrid)
    for varid in constr.art_var_ids
        _deactivate!(form, varid)
    end
    return
end

deactivate!(form::Formulation, varid::VarId) = _deactivate!(form, varid)
deactivate!(form::Formulation, varconstr::AbstractVarConstr) = deactivate!(form, getid(varconstr))

function deactivate!(form::Formulation, f::Function)
    for (varid, _) in getvars(form)
        if iscuractive(form, varid) && f(varid)
            deactivate!(form, varid)
        end
    end
    for (constrid, _) in getconstrs(form)
        if iscuractive(form, constrid) && f(constrid)
            deactivate!(form, constrid)
        end
    end
    return
end

## explicit
"""
todo
"""
isperenexplicit(form::Formulation, varid::VarId) = getperenisexplicit(form, getvar(form, varid))
isperenexplicit(form::Formulation, var::Variable) = var.peren_data.is_explicit
isperenexplicit(form::Formulation, constrid::ConstrId) = isperenexplicit(form, getconstr(form, constr))
isperenexplicit(form::Formulation, constr::Constraint) = constr.peren_data.is_explicit

"""
todo
"""
iscurexplicit(form::Formulation, varid::VarId) = form.manager.var_datas[varid].is_explicit
iscurexplicit(form::Formulation, var::Variable) = iscurexplicit(form, getid(var))
iscurexplicit(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].is_explicit
iscurexplicit(form::Formulation, constr::Constraint) = iscurexplicit(form, getid(constr))

"""
todo
"""
function setiscurexplicit!(form::Formulation, varid::VarId, is_explicit::Bool)
    form.manager.var_datas[varid].is_explicit = is_explicit
    #change_is_explicit!(form.buffer, getvar(form, varid))
    return
end
setiscurexplicit!(form::Formulation, var::Variable, is_explicit::Bool) = setiscurexplicit!(form, getid(var), is_explicit)
function setiscurexplicit!(form::Formulation, constrid::ConstrId, is_explicit::Bool)
    form.manager.constr_datas[constrid].is_explicit = is_explicit
    #change_is_explicit!(form.buffer, getvar(form, varid))
    return
end
setiscurexplicit!(form::Formulation, constr::Constraint, is_explicit::Bool) = setiscurexplicit!(form, getid(constr), is_explicit)

## name
"""
todo
"""
getname(form::Formulation, varid::VarId) = getvar(form, varid).name
getname(form::Formulation, var::Variable) = var.name
getname(form::Formulation, constrid::ConstrId) = getconstr(form, constrid).name
getname(form::Formulation, constr::Constraint) = constr.name

# Reset

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
    setcursense!(form, var, getperensense(form, var))
    setcurincval!(form, var, getperenincval(form, var))

    if isperenactive(form, var)
        activate!(form, var)
    else
        deactivate!(form, var)
    end

    setiscurexplicit!(form, var, isperenexplicit(form, var))
    return
end
reset!(form::Formulation, varid::VarId)  = reset!(form, getvar(form, varid)) 


function reset!(form::Formulation, constr::Constraint)
    setcurrhs!(form, constr, getperenrhs(form, constr))
    setcurkind!(form, constr, getperenkind(form, constr))
    setcursense!(form, constr, getperensense(form, constr))
    setcurincval!(form, constr , getperenincval(form, constr))
    
    if isperenactive(form, constr)
        activate!(form, constr)
    else
        deactivate!(form, constr)
    end

    setiscurexplicit!(form, constr, isperenexplicit(form, constr))
    return
end

reset!(form::Formulation, constrid::ConstrId) = reset!(form, getconstr(form,constrid))

# Variables
## Cost
"""
doc todo
"""
getperenecost(form::Formulation, varid::VarId) = getperenecost(form, getvar(form, varid))
getperenecost(form::Formulation, var::Variable) = var.perene_data.cost

"""
doc todo
"""
#getcurcost(form::Formulation, varid::VarId) = form.manager.var_costs[getuid(varid)]
getcurcost(form::Formulation, varid::VarId) = form.manager.var_costs[varid]
getcurcost(form::Formulation, var::Variable) = getcurcost(form, getid(var))

"""
    setcurcost!(form::Formulation, id::Id{Variable}, cost::Float64)
    setcurcost!(form::Formulation, var::Variable, cost::Float64)

Set the current cost of variable `var` with id `id` to `cost` in formulation
`form`.
"""
function setcurcost!(form::Formulation, varid::VarId, cost::Float64)
    form.manager.var_costs[varid] = cost
    change_cost!(form.buffer, getvar(form, varid)) # TODO : change buffer
    return
end

function setcurcost!(form::Formulation, var::Variable, cost::Float64)
    return setcurcost!(form, getid(var), cost)
end

## Lower bound
"""
doc todo
"""
getperenelb(form::Formulation, varid::VarId) = getperenelb(form, getvar(form, varid))
getperenelb(form::Formulation, var::Variable) = var.perene_data.lb

"""
doc todo
"""
#getcurlb(form::Formulation, varid::VarId) = form.manager.var_lbs[getuid(varid)]
getcurlb(form::Formulation, varid::VarId) = get(form.manager.var_lbs, varid, 0.0)
getcurlb(form::Formulation, var::Variable) = getcurlb(form, getid(var))

"""
    setcurlb!(form::Formulation, id::Id{Variable}, lb::Float64)
    setcurlb!(form::Formulation, var::Variable, lb::Float64)

Sets `v.cur_data.lb` as well as the bounds constraint of `v` in `f.optimizer`
according to `new_lb`. Change on `f.optimizer` will be buffered.
"""
function setcurlb!(form::Formulation, varid::VarId, lb::Float64)
    form.manager.var_lbs[varid] = lb
    change_bound!(form.buffer, getvar(form, varid))
    return
end

function setcurlb!(form::Formulation, var::Variable, lb::Float64)
    return setcurlb!(form, getid(var), lb)
end

## Upper bound
"""
doc todo
"""
getpereneub(form::Formulation, varid::VarId) = getpereneub(form, getvar(form, varid))
getpereneub(form::Formulation, var::Variable) = var.perene_data.ub

"""
doc todo
"""
#getcurub(form::Formulation, varid::VarId) = form.manager.var_ubs[getuid(varid)]
getcurub(form::Formulation, varid::VarId) = get(form.manager.var_ubs, varid, Inf)
getcurub(form::Formulation, var::Variable) = getcurub(form, getid(var))

"""
    setcurub!(form::Formulation, id::Id{Variable}, ub::Float64)
    setcurub!(form::Formulation, var::Variable, ub::Float64)

Sets `v.cur_data.ub` as well as the bounds constraint of `v` in `f.optimizer`
according to `new_ub`. Change on `f.optimizer` will be buffered.
"""
function setcurub!(form::Formulation, varid::VarId, ub::Float64)
    form.manager.var_ubs[varid] = ub
    change_bound!(form.buffer, getvar(form, varid))
    return
end

function setcurub!(form::Formulation, var::Variable, ub::Float64)
    return setcurub!(form, getid(var), ub)
end

# Constraint
## rhs


# Variable & Constraints
## kind
"""
todo
"""
getperenekind(form::Formulation, varid::VarId) = getperenekind(form, getvar(form, varid))
getperenekind(form::Formulation, var::Variable) = var.perene_data.kind
getperenekind(form::Formulation, constrid::ConstrId) = getperenekind(form, getconstr(form, constrid))
getperenekind(form::Formulation, constr::Constraint) = constr.perene_data.kind

"""
todo
"""
getcurkind(form::Formulation, varid::VarId) = getcurkind(form, getvar(form, varid))
getcurkind(form::Formulation, var::Variable) = var.cur_data.kind
getcurkind(form::Formulation, constrid::ConstrId) = getcurkind(form, getconstr(form, constrid))
getcurkind(form::Formulation, constr::Constraint) = constr.cur_data.kind

"""
    setcurkind!(f::Formulation, v::Variable, kind::VarKind)
    setcurkind!(f::Formulation, c::Constraint, kind::ConstrKind)

Sets `v.cur_data.kind` as well as the kind constraint of `v` in `f.optimizer`
according to `new_kind`. Change on `f.optimizer` will be buffered.
"""
setcurkind!(form::Formulation, varid::VarId, kind::VarKind) = setcurkind!(form, getvar(form, varid), kind)
function setcurkind!(form::Formulation, var::Variable, kind::VarKind)
    var.cur_data.kind = kind
    change_kind!(form.buffer, var)
    return
end
setcurkind!(form::Formulation, constrid::ConstrId, kind::ConstrKind) = setcurkind!(form, getconstr(form, constrid), kind)
setcurkind!(form::Formulation, constr::Constraint, kind::ConstrKind) = constr.cur_data.kind = kind


## sense
"""
todo
"""
getperenesense(form::Formulation, varid::VarId) = getperenesense(form, getvar(form, varid))
getperenesense(form::Formulation, var::Variable) = var.perene_data.sense
getperenesense(form::Formulation, constrid::ConstrId) = getperenesense(form, getconstr(form, constrid))
getperenesense(form::Formulation, constr::Constraint) = constr.perene_data.sense

"""
todo
"""
getcursense(form::Formulation, varid::VarId) = getcursense(form, getvar(form, varid))
getcursense(form::Formulation, var::Variable) = var.cur_data.sense
getcursense(form::Formulation, constrid::ConstrId) = getcursense(form, getconstr(form, constrid))
getcursense(form::Formulation, constr::Constraint) = constr.cur_data.sense

"""
todo
"""
setcursense!(form::Formulation, varid::VarId, sense::VarSense) = setcursense!(form, getvar(form, varid), sense)
setcursense!(form::Formulation, var::Variable, sense::VarSense) = var.cur_data.sense = sense
setcursense!(form::Formulation, constrid::ConstrId, sense::ConstrSense) = setcursense!(form, getconstr(form, constrid), sense)
setcursense!(form::Formulation, constr::Constraint, sense::ConstrSense) = constr.cur_data.sense = sense

## inc_val
"""
todo
"""
getpereneincval(form::Formulation, varid::VarId) = getpereneincval(form, getvar(form, varid))
getpereneincval(form::Formulation, var::Variable) = var.perene_data.inc_val
getpereneincval(form::Formulation, constrid::ConstrId) = getpereneincval(form, getconstr(form, constr))
getpereneincval(form::Formulation, constr::Constraint) = constr.perene_data.inc_val

"""
todo
"""
getcurincval(form::Formulation, varid::VarId) = getcurincval(form, getvar(form, varid))
getcurincval(form::Formulation, var::Variable) = var.cur_data.inc_val
getcurincval(form::Formulation, constrid::ConstrId) = getcurincval(form, getconstr(form, constrid))
getcurincval(form::Formulation, constr::Constraint) = constr.cur_data.inc_val

"""
todo
"""
setcurincval!(form::Formulation, varid::VarId, inc_val::Real) = setcurincval!(form, getvar(form, varid), inc_val)
setcurincval!(form::Formulation, var::Variable, inc_val::Real) = var.cur_data.inc_val = inc_val
setcurincval!(form::Formulation, constrid::ConstrId, inc_val::Real) = setcurincval!(form, getconstr(form, constrid), inc_val)
setcurincval!(form::Formulation, constr::Constraint, inc_val::Real) = constr.cur_data.inc_val = inc_val

## active

## explicit



# Reset

"""
    reset!(form, var)
    reset!(form, varid)
    reset!(form, constr)
    reset!(form, constraint)

doc todo
"""
function reset!(form::Formulation, var::Variable)
    setcurcost!(form, var, getperenecost(form, var))
    setcurlb!(form, var, getperenelb(form, var))
    setcurub!(form, var, getpereneub(form, var))
    var.cur_data.inc_val = var.perene_data.inc_val
    var.cur_data.kind = var.perene_data.kind
    var.cur_data.sense = var.perene_data.sense
    var.cur_data.is_active = var.perene_data.is_active
    return
end
reset!(form::Formulation, varid::VarId) = reset!(form, getvar(form, varid))

function reset!(form::Formulation, constr::Constraint)
    constr.cur_data.rhs = constr.perene_data.rhs
    constr.cur_data.inc_val = constr.perene_data.inc_val
    constr.cur_data.kind = constr.perene_data.kind
    constr.cur_data.sense = constr.perene_data.sense
    constr.cur_data.is_active = constr.perene_data.is_active
    return
end
reset!(form::Formulation, constrid::ConstrId) = reset!(form, getconstr(form, constrid))
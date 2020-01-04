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
getcurcost(form::Formulation, varid::VarId) = get(form.manager.var_costs, varid, 0.0)
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
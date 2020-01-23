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
getcurcost(form::Formulation, varid::VarId) = form.manager.var_datas[varid].cost
getcurcost(form::Formulation, var::Variable) = getcurcost(form, getid(var))

"""
    setcurcost!(form::Formulation, id::Id{Variable}, cost::Float64)
    setcurcost!(form::Formulation, var::Variable, cost::Float64)

Set the current cost of variable `var` with id `id` to `cost` in formulation
`form`.
"""
function setcurcost!(form::Formulation, varid::VarId, cost::Float64)
    form.manager.var_datas[varid].cost = cost
    if getcurisexplicit(form, varid) 
        change_cost!(form.buffer, getvar(form, varid)) # TODO : change buffer
    end
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
getcurlb(form::Formulation, varid::VarId) = form.manager.var_datas[varid].lb #get(form.manager.var_lbs, varid, 0.0)
getcurlb(form::Formulation, var::Variable) = getcurlb(form, getid(var))

"""
    setcurlb!(form::Formulation, id::Id{Variable}, lb::Float64)
    setcurlb!(form::Formulation, var::Variable, lb::Float64)

Sets `v.cur_data.lb` as well as the bounds constraint of `v` in `f.optimizer`
according to `new_lb`. Change on `f.optimizer` will be buffered.
"""
function setcurlb!(form::Formulation, varid::VarId, lb::Float64)
    form.manager.var_datas[varid].lb = lb
    if getcurisexplicit(form, varid) 
        change_bound!(form.buffer, getvar(form, varid))
    end

    return
end
setcurlb!(form::Formulation, var::Variable, lb::Float64) =  setcurlb!(form, getid(var), lb)


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
getcurub(form::Formulation, varid::VarId) = form.manager.var_datas[varid].ub #get(form.manager.var_ubs, varid, Inf)
getcurub(form::Formulation, var::Variable) = getcurub(form, getid(var))

"""
    setcurub!(form::Formulation, id::Id{Variable}, ub::Float64)
    setcurub!(form::Formulation, var::Variable, ub::Float64)

Sets `v.cur_data.ub` as well as the bounds constraint of `v` in `f.optimizer`
according to `new_ub`. Change on `f.optimizer` will be buffered.
"""
function setcurub!(form::Formulation, varid::VarId, ub::Float64)
    form.manager.var_datas[varid].ub = ub
    if getcurisexplicit(form, varid) 
        change_bound!(form.buffer, getvar(form, varid))
    end
    return
end
setcurub!(form::Formulation, var::Variable, ub::Float64) = setcurub!(form, getid(var), ub)


# Constraint
## rhs
getperenerhs(form::Formulation, constr::Constraint) = constr.perene_data.rhs
getperenerhs(form::Formulation, constrid::ConstrId) = getperenerhs(form, getconstr(form, constrid))
setperenerhs!(form::Formulation, constr::Constraint, rhs::Float64) = constr.perene_data.rhs = rhs
setperenerhs!(form::Formulation, constrid::ConstrId, rhs::Float64) = setperenerhs!(form, getconstr(form, constrid), rhs)

# Current
getcurrhs(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].rhs
getcurrhs(form::Formulation, constr::Constraint) = getcurrhs(form, getid(constr))
function setcurrhs!(form::Formulation, constrid::ConstrId, rhs::Float64) 
    form.manager.constr_datas[constrid].rhs = rhs
    if getcurisexplicit(form, constrid) 
        change_rhs!(form.buffer, constr) #change_rhs!(form.buffer, getconstr(form, constrid))
    end
    return
end
setcurrhs!(form::Formulation, constr::Constraint, rhs::Float64) = setcurrhs!(form, getid(form), rhs)


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
getcurkind(form::Formulation, varid::VarId) = form.manager.var_datas[varid].kind # getcurkind(form, getvar(form, varid))
getcurkind(form::Formulation, var::Variable) = getcurkind(form, getid(var))
getcurkind(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].kind
getcurkind(form::Formulation, constr::Constraint) = getcurkind(form, getid(constr))

"""
    setcurkind!(f::Formulation, v::Variable, kind::VarKind)
    setcurkind!(f::Formulation, c::Constraint, kind::ConstrKind)

Sets `v.cur_data.kind` as well as the kind constraint of `v` in `f.optimizer`
according to `new_kind`. Change on `f.optimizer` will be buffered.
"""
function setcurkind!(form::Formulation, varid::VarId, kind::VarKind)
    form.manager.var_datas[varid].kind = kind
    if getcurisexplicit(form, varid) 
        change_kind!(form.buffer, getvar(form, varid))
    end
    return
end
setcurkind!(form::Formulation, var::Variable, kind::VarKind) = setcurkind!(form, getid(var), kind)
function setcurkind!(form::Formulation, constrid::ConstrId, kind::ConstrKind)
    form.manager.constr_datas[constrid].kind = kind
    if getcurisexplicit(form, constrid) 
        change_kind!(form.buffer, getconstr(form, constrid))
    end
    return
end
setcurkind!(form::Formulation, constr::Constraint, kind::ConstrKind) = setcurkind!(form, getid(constr), kind) 


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
getcursense(form::Formulation, varid::VarId) = form.manager.var_datas[varid].sense
getcursense(form::Formulation, var::Variable) = getcursense(form, getid(var))
getcursense(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].sense
getcursense(form::Formulation, constr::Constraint) = getcursense(form, getid(constr))

"""
todo
"""
function setcursense!(form::Formulation, varid::VarId, sense::VarSense)
    form.manager.var_datas[varid].sense = sense
    if getcurisexplicit(form, varid) 
        #change_sense!(form.buffer, getvar(form, varid))
    end
    return
end
setcursense!(form::Formulation, var::Variable, sense::VarSense) = setcursense!(form, getid(var), sense)
function setcursense!(form::Formulation, constrid::ConstrId, sense::ConstrSense)
    form.manager.constr_datas[constrid].sense = sense
    if getcurisexplicit(form, constrid) 
        #change_sense!(form.buffer, getvar(form, varid))
    end
    return
end
setcursense!(form::Formulation, constr::Constraint, sense::ConstrSense) = setcursense!(form, getid(constr), sense)

## inc_val
"""
todo
"""
getpereneincval(form::Formulation, varid::VarId) = getperenincval(form, getvar(form, varid))
getpereneincval(form::Formulation, var::Variable) = var.perene_data.inc_val
getpereneincval(form::Formulation, constrid::ConstrId) = getpereneincval(form, getconstr(form, constr))
getpereneincval(form::Formulation, constr::Constraint) = constr.perene_data.inc_val

"""
todo
"""
getcurincval(form::Formulation, varid::VarId) = form.manager.var_datas[varid].inc_val
getcurincval(form::Formulation, var::Variable) = getcurincval(form, getid(var))
getcurincval(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].inc_val 
getcurincval(form::Formulation, constr::Constraint) = getcurincval(form, getid(constr))

"""
todo
"""
function setcurincval!(form::Formulation, varid::VarId, inc_val::Real)
    form.manager.var_datas[varid].inc_val = inc_val
    if getcurisexplicit(form, varid) 
        #change_inc_val!(form.buffer, getvar(form, varid))
    end
    return
end
setcurincval!(form::Formulation, var::Variable, inc_val::Real) = setcurincval!(form, getid(var), inc_val)
function setcurincval!(form::Formulation, constrid::ConstrId, inc_val::Real)
    form.manager.constr_datas[constrid].inc_val = inc_val
    if getcurisexplicit(form, constrid) 
        #change_inc_val!(form.buffer, getconstr(form, constrid))
    end
    return
end
setcurincval!(form::Formulation, constr::Constraint, inc_val::Real) = setcurincval!(form, getid(constr), inc_val)

## active
"""
todo
"""
getpereneisactive(form::Formulation, varid::VarId) = getperenisactive(form, getvar(form, varid))
getpereneisactive(form::Formulation, var::Variable) = var.perene_data.is_active
getpereneisactive(form::Formulation, constrid::ConstrId) = getpereneisactive(form, getconstr(form, constr))
getpereneisactive(form::Formulation, constr::Constraint) = constr.perene_data.is_active

"""
todo
"""
getcurisactive(form::Formulation, varid::VarId) = form.manager.var_datas[varid].is_active
getcurisactive(form::Formulation, var::Variable) = getcurisactive(form, getid(var))
getcurisactive(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].is_active
getcurisactive(form::Formulation, constr::Constraint) = getcurisactive(form, getid(constr))

"""
todo
"""
function setcurisactive!(form::Formulation, varid::VarId, is_active::Bool)
    form.manager.var_datas[varid].is_active = is_active
    #change_is_active!(form.buffer, getvar(form, varid))
    return
end
setcurisactive!(form::Formulation, var::Variable, is_active::Bool) = setcurisactive!(form, getid(var), is_active)
function setcurisactive!(form::Formulation, constrid::ConstrId, is_active::Bool) 
    form.manager.constr_datas[constrid].is_active = is_active
    #change_is_active!(form.buffer, getvar(form, constrid))
    return
end
setcurisactive!(form::Formulation, constr::Constraint, is_active::Bool) = setcurisactive!(form, getid(constr), is_active)

## explicit
"""
todo
"""
getpereneisexplicit(form::Formulation, varid::VarId) = getperenisexplicit(form, getvar(form, varid))
getpereneisexplicit(form::Formulation, var::Variable) = var.perene_data.is_explicit
getpereneisexplicit(form::Formulation, constrid::ConstrId) = getpereneisexplicit(form, getconstr(form, constr))
getpereneisexplicit(form::Formulation, constr::Constraint) = constr.perene_data.is_explicit

"""
todo
"""
getcurisexplicit(form::Formulation, varid::VarId) = form.manager.var_datas[varid].is_explicit
getcurisexplicit(form::Formulation, var::Variable) = getcurisexplicit(form, getid(var))
getcurisexplicit(form::Formulation, constrid::ConstrId) = form.manager.constr_datas[constrid].is_explicit
getcurisexplicit(form::Formulation, constr::Constraint) = getcurisexplicit(form, getid(constr))

"""
todo
"""
function setcurisexplicit!(form::Formulation, varid::VarId, is_explicit::Bool)
    form.manager.var_datas[varid].is_explicit = is_explicit
    #change_is_explicit!(form.buffer, getvar(form, varid))
    return
end
setcurisexplicit!(form::Formulation, var::Variable, is_explicit::Bool) = setcurisexplicit!(form, getid(var), is_explicit)
function setcurisexplicit!(form::Formulation, constrid::ConstrId, is_explicit::Bool)
    form.manager.constr_datas[constrid].is_explicit = is_explicit
    #change_is_explicit!(form.buffer, getvar(form, varid))
    return
end
setcurisexplicit!(form::Formulation, constr::Constraint, is_explicit::Bool) = setcurisexplicit!(form, getid(constr), is_explicit)



# Reset

"""
    reset!(form, var)
    reset!(form, varid)
    reset!(form, constr)
    reset!(form, constraint)

doc todo
"""
function reset!(form::Formulation, var::Variable)
   #=  form.manager.var_datas[getid(var)] = var.perene_data
=# 
    setcurcost!(form, var, getperenecost(form, var))
    setcurlb!(form, var, getperenelb(form, var))
    setcurub!(form, var, getpereneub(form, var))
    setcurkind!(form, var, getperenekind(form, var))
    setcursense!(form, var, getperenesense(form, var))
    setcurincval!(form, var, getpereneincval(form, var))
    setcurisactive!(form, var, getpereneisactive(form, var))
    setcurisexplicit!(form, var, getpereneisexplicit(form, var))
    return
end
reset!(form::Formulation, varid::VarId)  = reset!(form, getvar(form, varid)) 
#==
function reset!(form::Formulation, varid::VarId) 
    form.manager.var_datas[varid] = getvar(form, varid).perene_data
    return
end
==#


function reset!(form::Formulation, constr::Constraint)
     #== form.manager.constr_datas[getid(constr)] = constr.perene_data
    ==#
    setcurrhs!(form, constr, getperenerhs(form, constr))
    setcurkind!(form, constr, getperenekind(form, constr))
    setcursense!(form, constr, getperenesense(form, constr))
    setcurincval!(form, constr , getpereneincval(form, constr))
    setcurisactive!(form, constr, getpereneisactive(form, constr))
    setcurisexplicit!(form, constr, getpereneisexplicit(form, constr))
    return
end

reset!(form::Formulation, constrid::ConstrId) = reset!(form, getconstr(form,constrid))
#==
function reset!(form::Formulation, constrid::ConstrId) 
    form.manager.constr_datas[constrid] = getconstr(form, constrid).perene_data
    return 
end
==#

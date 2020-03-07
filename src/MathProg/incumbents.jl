

# TODO : check that the type of the variable is integer
function Base.isinteger(sol::Coluna.Containers.Solution)
    for (vc_id, val) in sol
        !isinteger(val) && return false
    end
    return true
end

isfractional(sol::Coluna.Containers.Solution) = !Base.isinteger(sol)

function contains(form::AbstractFormulation, sol::PrimalSolution, duty::Duty{Variable})
    for (varid, val) in sol
        getduty(varid) <= duty && return true
    end
    return false
end

function contains(form::AbstractFormulation, sol::DualSolution, duty::Duty{Constraint})
    for (constrid, val) in sol
        getduty(constrid) <= duty && return true
    end
    return false
end


# TO DO : should contain only bounds, solutions should be in OptimizationResult
mutable struct Incumbents{M,S} 
    ip_primal_sol::PrimalSolution{M}
    ip_primal_bound::PrimalBound{S}
    ip_dual_bound::DualBound{S} # the IP dual bound can be the result of computation other than using the LP dual bound
    lp_primal_sol::PrimalSolution{M}
    lp_primal_bound::PrimalBound{S}
    lp_dual_sol::DualSolution{M}
    lp_dual_bound::DualBound{S}
end

"""
    Incumbents(sense)

Returns `Incumbents` for an objective function with sense `sense`.
Given a mixed-integer program,  `Incumbents` contains the best primal solution
to the program, the best primal solution to the linear relaxation of the 
program, the best  dual solution to the linear relaxation of the program, 
and the best dual bound to the program.
"""
function Incumbents(form::M) where {M<:AbstractFormulation}
    S = getobjsense(form)
    return Incumbents{M,S}(
        PrimalSolution(form),
        PrimalBound(form),
        DualBound(form),
        PrimalSolution(form),
        PrimalBound(form),
        DualSolution(form),
        DualBound(form)
     )
end

getsense(::Incumbents{M,S}) where {M,S} = S

# Getters solutions
"Return the best primal solution to the mixed-integer program."
get_ip_primal_sol(i::Incumbents) = i.ip_primal_sol

"Return the best dual solution to the linear program."
get_lp_dual_sol(i::Incumbents) = i.lp_dual_sol

"Return the best primal solution to the linear program."
get_lp_primal_sol(i::Incumbents) = i.lp_primal_sol

# Getters bounds
"Return the best primal bound of the mixed-integer program."
get_ip_primal_bound(i::Incumbents) = i.ip_primal_bound

"Return the best dual bound of the mixed-integer program."
get_ip_dual_bound(i::Incumbents) = i.ip_dual_bound

"Return the best primal bound of the linear program."
get_lp_primal_bound(i::Incumbents) = i.lp_primal_bound # getbound(i.lp_primal_sol)

"Return the best dual bound of the linear program."
get_lp_dual_bound(i::Incumbents) = i.lp_dual_bound

# Gaps
"Return the gap between the best primal and dual bounds of the integer program."
ip_gap(i::Incumbents) = gap(get_ip_primal_bound(i), get_ip_dual_bound(i))

"Return the gap between the best primal and dual bounds of the linear program."
lp_gap(i::Incumbents) = gap(get_lp_primal_bound(i), get_lp_dual_bound(i))

# Setters
# Methods to set IP primal sol.
"""
Update the best primal solution to the mixed-integer program if the new one is
better than the current one according to the objective sense.
"""
function update_ip_primal_sol!(
    inc::Incumbents{M,S}, sol::PrimalSolution{M}
) where {M,S}
    newbound = PrimalBound{S}(getvalue(sol))
    if isbetter(newbound, PrimalBound{S}(getvalue(inc.ip_primal_sol)))
        inc.ip_primal_bound = newbound
        inc.ip_primal_sol = sol
        return true
    end
    return false
end
update_ip_primal_sol!(inc::Incumbents, ::Nothing) = false

# Methods to set IP primal bound.
"""
Update the primal bound of the mixed-integer program if the new one is better
than the current one according to the objective sense.
"""
function update_ip_primal_bound!(
    inc::Incumbents{M,S}, bound::PrimalBound{S}
) where {M,S}
    if isbetter(bound, get_ip_primal_bound(inc))
        inc.ip_primal_bound = bound
        return true
    end
    return false
end

"Set the current primal bound of the mixed-integer program."
function set_ip_primal_bound!(
    inc::Incumbents{M,S}, bound::PrimalBound{S}
) where {M,S}
    inc.ip_primal_bound = bound
    return 
end

# Methods to set IP dual bound.
"""
Update the dual bound of the mixed-integer program if the new one is better than
the current one according to the objective sense.
"""
function update_ip_dual_bound!(
    inc::Incumbents{M,S}, bound::DualBound{S}
) where {M,S}
    if isbetter(bound, get_ip_dual_bound(inc))
        inc.ip_dual_bound = bound
        return true
    end
    return false
end

"Set the current dual bound of the mixed-integer program."
function set_ip_dual_bound!(inc::Incumbents{M,S}, bound::DualBound{S}) where {M,S}
    inc.ip_dual_bound = bound
    return 
end

# Methods to set LP primal solution.
"""
Update the best primal solution to the linear program if the new one is better
than the current one according to the objective sense.
"""
function update_lp_primal_sol!(
    inc::Incumbents{M,S}, sol::PrimalSolution{M}
) where {M,S}
    newbound = PrimalBound{S}(getvalue(sol))
    if isbetter(newbound, PrimalBound{S}(getvalue(inc.lp_primal_sol)))
        inc.lp_primal_bound = newbound
        inc.lp_primal_sol = sol
        return true
    end
    return false
end
update_lp_primal_sol!(inc::Incumbents, ::Nothing) = false

# Methods to set LP primal bound.
"""
Update the primal bound of the linear program if the new one is better than the
current one according to the objective sense.
"""
function update_lp_primal_bound!(
    inc::Incumbents{M,S}, bound::PrimalBound{S}
) where {M,S}
   if isbetter(bound, get_lp_primal_bound(inc))
        inc.lp_primal_bound = bound
        return true
    end
    return false
end

"Set the primal bound of the linear program"
function set_lp_primal_bound!(
    inc::Incumbents{M,S}, bound::PrimalBound{S}
) where {M,S}
    inc.lp_primal_bound = bound
    return 
end

# Methods to set LP dual sol.
"""
Update the dual bound of the linear program if the new one is better than the 
current one according to the objective sense.
"""
function update_lp_dual_bound!(
    inc::Incumbents{M,S}, bound::DualBound{S}
) where {M,S}
    if isbetter(bound, get_lp_dual_bound(inc))
        inc.lp_dual_bound = bound
        return true
    end
    return false
end

"Set the dual bound of the linear program."
function set_lp_dual_bound!(
    inc::Incumbents{M,S}, bound::DualBound{S}
) where {M,S}
    inc.lp_dual_bound = bound
    return 
end

# Methods to set LP dual bound.
"""
Update the dual solution to the linear program if the new one is better than the
current one according to the objective sense.
"""
function update_lp_dual_sol!(inc::Incumbents{M,S}, sol::DualSolution{M}) where {M,S}
    newbound = DualBound{S}(getvalue(sol))
    if isbetter(newbound, DualBound{S}(getvalue(inc.lp_dual_sol)))
        inc.lp_dual_bound = newbound 
        inc.lp_dual_sol = sol
        return true
    end
    return false
end
update_lp_dual_sol!(inc::Incumbents, ::Nothing) = false

"Update the fields of `dest` that are worse than those of `src`."
function update!(dest::Incumbents{M,S}, src::Incumbents{M,S}) where {M,S}
    update_ip_dual_bound!(dest, get_ip_dual_bound(src))
    update_ip_primal_bound!(dest, get_ip_primal_bound(src))
    update_lp_dual_bound!(dest, get_lp_dual_bound(src))
    update_lp_primal_bound!(dest, get_lp_primal_bound(src))
    update_ip_primal_sol!(dest, get_ip_primal_sol(src))
    update_lp_primal_sol!(dest, get_lp_primal_sol(src))
    update_lp_dual_sol!(dest, get_lp_dual_sol(src))
    return
end

function Base.show(io::IO, i::Incumbents{M,S}) where {M,S}
    println(io, "Incumbents{", S, "}:")
    println(io, "ip_primal_bound : ", i.ip_primal_bound)
    println(io, "ip_dual_bound : ", i.ip_dual_bound)
    println(io, "lp_primal_bound : ", i.lp_primal_bound)
    println(io, "lp_dual_bound : ", i.lp_dual_bound)
    print(io, "ip_primal_sol : ", i.ip_primal_sol)
    print(io, "lp_primal_sol : ", i.lp_primal_sol)
    print(io, "lp_dual_sol : ", i.lp_dual_sol)
end

mutable struct Incumbents{S}
    ip_primal_sol::PrimalSolution{S}
    ip_primal_bound::PrimalBound{S}
    ip_dual_bound::DualBound{S}
    lp_primal_sol::PrimalSolution{S}
    lp_primal_bound::PrimalBound{S}
    lp_dual_sol::DualSolution{S}
end

"""
    Incumbents(sense)

Returns `Incumbents` for an objective function with sense `sense`.
Given a mixed-integer program,  `Incumbents` contains the best primal solution
to the program, the best primal solution to the linear relaxation of the 
program, the best  dual solution to the linear relaxation of the program, 
and the best dual bound to the program.
"""
function Incumbents(S::Type{<: AbstractObjSense})
    return Incumbents{S}(
        PrimalSolution{S}(),
        PrimalBound{S}(),
        DualBound{S}(),
        PrimalSolution{S}(),
        PrimalBound{S}(),
        DualSolution{S}()
    )
end

getsense(::Incumbents{MinSense}) = MinSense
getsense(::Incumbents{MaxSense}) = MaxSense

# Getters solutions
"Returns the best primal solution to the mixed-integer program."
get_ip_primal_sol(i::Incumbents) = i.ip_primal_sol

"Returns the best dual solution to the linear program."
get_lp_dual_sol(i::Incumbents) = i.lp_dual_sol

"Returns the best primal solution to the linear program."
get_lp_primal_sol(i::Incumbents) = i.lp_primal_sol

# Getters bounds
"Returns the best primal bound of the mixed-integer program."
get_ip_primal_bound(i::Incumbents) = getbound(i.ip_primal_sol)

"Returns the best dual bound of the mixed-integer program."
get_ip_dual_bound(i::Incumbents) = i.ip_dual_bound

"Returns the best primal bound of the linear program."
get_lp_primal_bound(i::Incumbents) = i.lp_primal_bound # getbound(i.lp_primal_sol)

"Returns the best dual bound of the linear program."
get_lp_dual_bound(i::Incumbents) = getbound(i.lp_dual_sol)

# Gaps
"Returns the gap between the best primal and dual bounds of the integer program."
ip_gap(i::Incumbents) = gap(get_ip_primal_bound(i), get_ip_dual_bound(i))

"Returns the gap between the best primal and dual bounds of the linear program."
lp_gap(i::Incumbents) = gap(get_lp_primal_bound(i), get_lp_dual_bound(i))

# Setters
"""
Updates the best primal solution to the mixed-integer program if the new one is
better than the current one according to the objective sense.
"""
function set_ip_primal_sol!(inc::Incumbents{S},
                            sol::PrimalSolution{S};
                            correction::PrimalBound{S} = PrimalBound{S}(0.0)) where {S}

    newbound = getbound(sol) + correction

    if isbetter(newbound, getbound(inc.ip_primal_sol))
        inc.ip_primal_bound = newbound
        inc.ip_primal_sol = sol
        return true
    end
    return false
end
set_ip_primal_sol!(inc::Incumbents, ::Nothing) = false

"""
Updates the best primal solution to the linear program if the new one is better
than the current one according to the objective sense.
"""
function set_lp_primal_sol!(inc::Incumbents{S},
                            sol::PrimalSolution{S};
                            correction::PrimalBound{S} = PrimalBound{S}(0.0)) where {S}

    newbound = getbound(sol) + correction
     
    if isbetter(newbound, getbound(inc.lp_primal_sol))
        inc.lp_primal_bound = newbound
        inc.lp_primal_sol = sol
        return true
    end
    return false
end
set_lp_primal_sol!(inc::Incumbents, ::Nothing) = false


"""
Updates the dual bound of the mixed-integer program if the new one is better than
the current one according to the objective sense.
"""
function set_ip_dual_bound!(inc::Incumbents{S},
                            new_bound::DualBound{S}) where {S}
    if isbetter(new_bound, get_ip_dual_bound(inc))
        inc.ip_dual_bound = new_bound
        return true
    end
    return false
end

function set_lp_primal_bound!(inc::Incumbents{S},
                              new_bound::PrimalBound{S}) where {S}
    if isbetter(new_bound, get_lp_primal_bound(inc))
        inc.lp_primal_bound = new_bound
        return true
    end
    return false
end

"""
Updates the dual solution to the linear program if the new one is better than the
current one according to the objective sense.
"""
function set_lp_dual_sol!(inc::Incumbents{S},
                          sol::DualSolution{S}) where {S}
    if isbetter(getbound(sol), getbound(inc.lp_dual_sol))
        inc.lp_dual_sol = sol
        return true
    end
    return false
end
set_lp_dual_sol!(inc::Incumbents, ::Nothing) = false

"Updates the fields of `dest` that are worse than those of `src`."
function set!(dest::Incumbents{S}, src::Incumbents{S}) where {S}
    set_ip_primal_sol!(dest, get_ip_primal_sol(src))
    set_lp_primal_sol!(dest, get_lp_primal_sol(src))
    set_ip_dual_bound!(dest, get_ip_dual_bound(src))
    set_lp_dual_sol!(dest, get_lp_dual_sol(src))
    return
end

function Base.show(io::IO, i::Incumbents{S}) where {S}
    println(io, "Incumbents{", S, "}:")
    print(io, "ip_primal_sol : ", i.ip_primal_sol)
    println(io, "ip_dual_bound : ", i.ip_dual_bound)
    print(io, "lp_primal_sol : ", i.lp_primal_sol)
    print(io, "lp_dual_sol : ", i.lp_dual_sol)
end

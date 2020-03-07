# new structures for solutions

# Constructors for Primal & Dual Solutions
const PrimalSolution{M} = Solution{M, VarId, Float64}
const DualSolution{M} = Solution{M, ConstrId, Float64}
const PrimalBound{S} = Bound{Primal, S}
const DualBound{S} = Bound{Dual, S}

function PrimalBound(form::AbstractFormulation)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Primal,Se}()
end

function PrimalBound(form::AbstractFormulation, val::Float64)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Primal,Se}(val)
end

function PrimalSolution(form::M) where {M}
    return Coluna.Containers.Solution{M,VarId,Float64}(form)
end

function PrimalSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64
) where {M<:AbstractFormulation,De,Va}
    return Coluna.Containers.Solution{M,De,Va}(form, decisions, vals, val)
end

function DualBound(form::AbstractFormulation)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Dual,Se}()
end

function DualBound(form::AbstractFormulation, val::Float64)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Dual,Se}(val)
end

function DualSolution(form::M) where {M}
    return Coluna.Containers.Solution{M,ConstrId,Float64}(form)
end

function DualSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64
) where {M<:AbstractFormulation,De,Va}
    return Coluna.Containers.Solution{M,De,Va}(form, decisions, vals, val)
end

valueinminsense(b::PrimalBound{MinSense}) = b.value
valueinminsense(b::DualBound{MinSense}) = b.value
valueinminsense(b::PrimalBound{MaxSense}) = -b.value
valueinminsense(b::DualBound{MaxSense}) = -b.value

function Base.print(io::IO, form::AbstractFormulation, sol::Coluna.Containers.Solution)
    println(io, "Solution")
    for (id, val) in sol
        println(io, getname(form, id), " = ", val)
    end
    return
end

# ObjValues
mutable struct ObjValues{S}
    lp_primal_bound::PrimalBound{S}
    lp_dual_bound::DualBound{S}
    ip_primal_bound::PrimalBound{S}
    ip_dual_bound::DualBound{S}
end

"""
    ObjValues(form)

todo
"""
function ObjValues(form::M) where {M<:AbstractFormulation}
    S = getobjsense(form)
    return ObjValues{S}(
        PrimalBound(form), DualBound(form), PrimalBound(form), DualBound(form)
    )
end

## Getters bounds
"Return the best primal bound of the mixed-integer program."
get_ip_primal_bound(ov::ObjValues) = ov.ip_primal_bound

"Return the best dual bound of the mixed-integer program."
get_ip_dual_bound(ov::ObjValues) = ov.ip_dual_bound

"Return the best primal bound of the linear program."
get_lp_primal_bound(ov::ObjValues) = ov.lp_primal_bound

"Return the best dual bound of the linear program."
get_lp_dual_bound(ov::ObjValues) = ov.lp_dual_bound

## Gaps
"""
Return the gap between the best primal and dual bounds of the integer program.
Should not be used to check convergence
"""
ip_gap(ov::ObjValues) = gap(get_ip_primal_bound(ov), get_ip_dual_bound(ov))

"Return the gap between the best primal and dual bounds of the linear program."
lp_gap(ov::ObjValues) = gap(get_lp_primal_bound(ov), get_lp_dual_bound(ov))

#ip_ratio(ov::ObjValues) = get_ip_primal_bound(ov) / get_ip_dual_bound(ov)

#lp_ratio(ov::ObjValues) = get_lp_primal_bound(ov) / get_lp_dual_bound(ov)

function set_lp_primal_bound!(ov::ObjValues{S}, b::PrimalBound{S}) where {S}
    inc.lp_primal_bound = b
    return
end

function set_lp_dual_bound!(ov::ObjValues{S}, b::DualBound{S}) where {S}
    inc.lp_dual_bound = b
    return
end

function set_ip_primal_bound!(ov::ObjValues{S}, b::PrimalBound{S}) where {S}
    inc.ip_primal_bound = b
    return
end

function set_ip_dual_bound!(ov::ObjValues{S}, b::DualBound{S}) where {S}
    inc.ip_dual_bound = b
    return
end

function update_lp_primal_bound!(ov::ObjValues{S}, b::PrimalBound{S}) where {S}
    if isbetter(b, get_lp_primal_bound(ov))
        inc.lp_primal_bound = b
        return true
    end
    return false
end

function update_lp_dual_bound!(ov::ObjValues{S}, b::DualBound{S}) where {S}
    if isbetter(b, get_lp_dual_bound(ov))
        inc.lp_dual_bound = b
        return true
    end
    return false
end

function update_ip_primal_bound!(ov::ObjValues{S}, b::PrimalBound{S}) where {S}
    if isbetter(b, get_ip_primal_bound(ov))
        inc.ip_primal_bound = b
        return true
    end
    return false
end

function update_ip_dual_bound!(ov::ObjValues{S}, b::DualBound{S}) where {S}
    if isbetter(b, get_ip_dual_bound(ov))
        inc.ip_dual_bound = b
        return true
    end
    return false
end

function update!(dest::ObjValues{S}, src::ObjValues{S}) where {S}
    update_ip_dual_bound!(dest, get_ip_dual_bound(src))
    update_ip_primal_bound!(dest, get_ip_primal_bound(src))
    update_lp_dual_bound!(dest, get_lp_dual_bound(src))
    update_lp_primal_bound!(dest, get_lp_primal_bound(src))
    return
end

function Base.show(io::IO, ov::ObjValues{S}) where {S}
    println(io, "ObjValues{", S, "}:")
    println(io, "ip_primal_bound : ", ov.ip_primal_bound)
    println(io, "ip_dual_bound : ", ov.ip_dual_bound)
    println(io, "lp_primal_bound : ", ov.lp_primal_bound)
    println(io, "lp_dual_bound : ", ov.lp_dual_bound)
end
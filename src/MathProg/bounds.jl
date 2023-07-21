"""
    PrimalBound(formulation)
    PrimalBound(formulation, value)
    PrimalBound(formualtion, pb)

Create a new primal bound for the formulation `formulation`.
The value of the primal bound is infinity if you do not specify any initial value.
"""
function PrimalBound(form::AbstractFormulation)
    min = getobjsense(form) == MinSense
    return ColunaBase.Bound(min, true)
end

function PrimalBound(form::AbstractFormulation, val)
    min = getobjsense(form) == MinSense
    return ColunaBase.Bound(min, true, val)
end

function PrimalBound(form::AbstractFormulation, pb::ColunaBase.Bound)
    min = getobjsense(form) == MinSense
    @assert pb.primal && pb.min == min
    return ColunaBase.Bound(min, true, ColunaBase.getvalue(pb))
end

PrimalBound(::AbstractFormulation, ::Nothing) = nothing

"""
    DualBound(formulation)
    DualBound(formulation, value)
    DualBound(formulation, db)

Create a new dual bound for the formulation `formulation`.
The value of the dual bound is infinity if you do not specify any initial value.
"""
function DualBound(form::AbstractFormulation)
    min = getobjsense(form) == MinSense
    return ColunaBase.Bound(min, false)
end

function DualBound(form::AbstractFormulation, val::Real)
    min = getobjsense(form) == MinSense
    return ColunaBase.Bound(min, false, val)
end

DualBound(::AbstractFormulation, ::Nothing) = nothing

function DualBound(form::AbstractFormulation, db::ColunaBase.Bound)
    min = getobjsense(form) == MinSense
    @assert !db.primal && db.min == min
    return ColunaBase.Bound(min, false, ColunaBase.getvalue(db))
end

# ObjValues
mutable struct ObjValues
    min::Bool
    lp_primal_bound::Union{Nothing,ColunaBase.Bound}
    lp_dual_bound::Union{Nothing,ColunaBase.Bound}
    ip_primal_bound::Union{Nothing,ColunaBase.Bound}
    ip_dual_bound::Union{Nothing,ColunaBase.Bound}
end

"A convenient structure to maintain and return incumbent bounds."
function ObjValues(
    form::M; 
    ip_primal_bound = nothing,
    ip_dual_bound = nothing,
    lp_primal_bound = nothing,
    lp_dual_bound = nothing
) where {M<:AbstractFormulation}
    min = getobjsense(form) == MinSense
    ov = ObjValues(
        min, PrimalBound(form), DualBound(form), PrimalBound(form), DualBound(form)
    )
    if !isnothing(ip_primal_bound)
        ov.ip_primal_bound = PrimalBound(form, ip_primal_bound)
    end
    if !isnothing(ip_dual_bound)
        ov.ip_dual_bound = DualBound(form, ip_dual_bound)
    end
    if !isnothing(lp_primal_bound)
        ov.lp_primal_bound = PrimalBound(form, lp_primal_bound)
    end
    if !isnothing(lp_dual_bound)
        ov.lp_dual_bound = DualBound(form, lp_dual_bound)
    end
    return ov
end


## Gaps
_ip_gap(ov::ObjValues) = gap(ov.ip_primal_bound, ov.ip_dual_bound)
_lp_gap(ov::ObjValues) = gap(ov.lp_primal_bound, ov.lp_dual_bound)

function gap_closed(
    pb::Bound, db::Bound; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL
)
    return gap(pb, db) <= 0 || _gap_closed(
        pb.value, db.value, atol = atol, rtol = rtol
    )
end


function _ip_gap_closed(
    ov::ObjValues; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL
)
    return gap_closed(ov.ip_primal_bound, ov.ip_dual_bound; atol, rtol)
end


function _lp_gap_closed(
    ov::ObjValues; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL
)
    return gap_closed(ov.lp_primal_bound, ov.lp_dual_bound; atol, rtol)
end

function _gap_closed(
    x::Number, y::Number; atol::Real = 0, rtol::Real = atol > 0 ? 0 : √eps, 
    norm::Function = abs
) 
    return x == y || (isfinite(x) && isfinite(y) && norm(x - y) <= max(atol, rtol*min(norm(x), norm(y))))
end

## Bound updates
function _update_lp_primal_bound!(ov::ObjValues, pb::ColunaBase.Bound)
    @assert pb.primal && pb.min == ov.min
    if ColunaBase.isbetter(pb, ov.lp_primal_bound)
        ov.lp_primal_bound = pb
        return true
    end
    return false
end

function _update_lp_dual_bound!(ov::ObjValues, db::ColunaBase.Bound)
    @assert !db.primal && db.min == ov.min
    if ColunaBase.isbetter(db, ov.lp_dual_bound)
        ov.lp_dual_bound = db
        return true
    end
    return false
end

function _update_ip_primal_bound!(ov::ObjValues, pb::ColunaBase.Bound)
    @assert pb.primal && pb.min == ov.min
    if ColunaBase.isbetter(pb, ov.ip_primal_bound)
        ov.ip_primal_bound = pb
        return true
    end
    return false
end

function _update_ip_dual_bound!(ov::ObjValues, db::ColunaBase.Bound)
    @assert !db.primal && db.min == ov.min
    if ColunaBase.isbetter(db, ov.ip_dual_bound)
        ov.ip_dual_bound = db
        return true
    end
    return false
end
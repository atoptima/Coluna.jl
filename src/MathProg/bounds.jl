const PrimalBound{S} = Bound{Primal, S}
const DualBound{S} = Bound{Dual, S}

"""
    PrimalBound(formulation)
    PrimalBound(formulation, value)
    PrimalBound(formualtion, pb)

Create a new primal bound for the formulation `formulation`.
The value of the primal bound is infinity if you do not specify any initial value.
"""
function PrimalBound(form::AbstractFormulation)
    Se = getobjsense(form)
    return Bound{Primal,Se}()
end

function PrimalBound(form::AbstractFormulation, val)
    Se = getobjsense(form)
    return Bound{Primal,Se}(val)
end

function PrimalBound(form::AbstractFormulation, pb::PrimalBound{S}) where {S}
    Se = getobjsense(form)
    if Se != S
        msg = """
        Cannot create primal bound.
        Sense of the formulation is $Se and sense of the bound is $S.
        """
        error(msg)
    end
    return Bound{Primal,Se}(getvalue(pb))
end

"""
    DualBound(formulation)
    DualBound(formulation, value)
    DualBound(formulation, db)

Create a new dual bound for the formulation `formulation`.
The value of the dual bound is infinity if you do not specify any initial value.
"""
function DualBound(form::AbstractFormulation)
    Se = getobjsense(form)
    return Bound{Dual,Se}()
end

function DualBound(form::AbstractFormulation, val)
    Se = getobjsense(form)
    return Bound{Dual,Se}(val)
end

function DualBound(form::AbstractFormulation, db::DualBound{S}) where {S}
    Se = getobjsense(form)
    if Se != S
        msg = """
        Cannot create primal bound.
        Sense of the formulation is $Se and sense of the bound is $S.
        """
        error(msg)
    end
    return Bound{Dual,Se}(getvalue(db))
end

# valueinminsense(b::PrimalBound{MinSense}) = b.value
# valueinminsense(b::DualBound{MinSense}) = b.value
# valueinminsense(b::PrimalBound{MaxSense}) = -b.value
# valueinminsense(b::DualBound{MaxSense}) = -b.value

# ObjValues
mutable struct ObjValues{S}
    lp_primal_bound::PrimalBound{S}
    lp_dual_bound::DualBound{S}
    ip_primal_bound::PrimalBound{S}
    ip_dual_bound::DualBound{S}
end

"A convenient structure to maintain and return incumbent bounds."
function ObjValues(
    form::M; 
    ip_primal_bound = nothing,
    ip_dual_bound = nothing,
    lp_primal_bound = nothing,
    lp_dual_bound = nothing
) where {M<:AbstractFormulation}
    S = getobjsense(form)
    ov = ObjValues{S}(
        PrimalBound(form), DualBound(form), PrimalBound(form), DualBound(form)
    )
    if ip_primal_bound !== nothing
        ov.ip_primal_bound = PrimalBound(form, ip_primal_bound)
    end
    if ip_dual_bound !== nothing
        ov.ip_dual_bound = DualBound(form, ip_dual_bound)
    end
    if lp_primal_bound !== nothing
        ov.lp_primal_bound = PrimalBound(form, lp_primal_bound)
    end
    if lp_dual_bound !== nothing
        ov.lp_dual_bound = DualBound(form, lp_dual_bound)
    end
    return ov
end

## Gaps
_ip_gap(ov::ObjValues) = gap(ov.ip_primal_bound, ov.ip_dual_bound)
_lp_gap(ov::ObjValues) = gap(ov.lp_primal_bound, ov.lp_dual_bound)

function _ip_gap_closed(
    ov::ObjValues; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL
)
    return (_ip_gap(ov) <= 0) || _gap_closed(
        ov.ip_primal_bound.value, ov.ip_dual_bound.value, atol = atol, rtol = rtol
    )
end

function _lp_gap_closed(
    ov::ObjValues; atol = Coluna.DEF_OPTIMALITY_ATOL, rtol = Coluna.DEF_OPTIMALITY_RTOL
)
    return (_lp_gap(ov) <= 0) || _gap_closed(
       ov.lp_primal_bound.value, ov.lp_dual_bound.value, atol = atol, rtol = rtol
    )
end

function _gap_closed(
    x::Number, y::Number; atol::Real = 0, rtol::Real = atol > 0 ? 0 : √eps, 
    norm::Function = abs
) 
    return (x == y) || (isfinite(x) && isfinite(y) && norm(x - y) <= max(atol, rtol*min(norm(x), norm(y))))
end

## Bound updates
function _update_lp_primal_bound!(ov::ObjValues{S}, b::PrimalBound{S}) where {S}
    if isbetter(b, ov.lp_primal_bound)
        ov.lp_primal_bound = b
        return true
    end
    return false
end

function _update_lp_dual_bound!(ov::ObjValues{S}, b::DualBound{S}) where {S}
    if isbetter(b, ov.lp_dual_bound)
        ov.lp_dual_bound = b
        return true
    end
    return false
end

function _update_ip_primal_bound!(ov::ObjValues{S}, b::PrimalBound{S}) where {S}
    if isbetter(b, ov.ip_primal_bound)
        ov.ip_primal_bound = b
        return true
    end
    return false
end

function _update_ip_dual_bound!(ov::ObjValues{S}, b::DualBound{S}) where {S}
    if isbetter(b, ov.ip_dual_bound)
        ov.ip_dual_bound = b
        return true
    end
    return false
end
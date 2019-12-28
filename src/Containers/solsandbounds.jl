# alias only used in this file
const Primal = Coluna.AbstractPrimalSpace
const Dual = Coluna.AbstractDualSpace
const MinSense = Coluna.AbstractMinSense
const MaxSense = Coluna.AbstractMaxSense

struct Bound{Space<:Coluna.AbstractSpace,Sense<:Coluna.AbstractSense} <: Number
    value::Float64
end   

_defaultboundvalue(::Type{<: Primal}, ::Type{<: MinSense}) = Inf
_defaultboundvalue(::Type{<: Primal}, ::Type{<: MaxSense}) = -Inf
_defaultboundvalue(::Type{<: Dual}, ::Type{<: MinSense}) = -Inf
_defaultboundvalue(::Type{<: Dual}, ::Type{<: MaxSense}) = Inf

"""
    Bound{Space, Sense}

doc todo
"""
function Bound{Space,Sense}() where {Space<:Coluna.AbstractSpace,Sense<:Coluna.AbstractSense}
    val = _defaultboundvalue(Space, Sense)
    return Bound{Space,Sense}(val)
end

getvalue(b::Bound) = b.value
Base.float(b::Bound) = b.value

"""
    isbetter

doc todo
"""
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Primal,Se<:MinSense} = b1.value < b2.value
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Primal,Se<:MaxSense} = b1.value > b2.value
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Dual,Se<:MinSense} = b1.value > b2.value
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Dual,Se<:MaxSense} = b1.value < b2.value
# should we add a fallback ?

"""
    diff

distance to reach the dual bound from the primal bound;
non-positive if dual bound reached.
"""
function diff(pb::Bound{<:Primal,<:MinSense}, db::Bound{<:Dual,<:MinSense})
    return pb.value - db.value
end

function diff(db::Bound{<:Dual,<:MinSense}, pb::Bound{<:Primal,<:MinSense})
    return pb.value - db.value
end

function diff(pb::Bound{<:Primal,<:MaxSense}, db::Bound{<:Dual,<:MaxSense})
    return db.value - pb.value
end

function diff(db::Bound{<:Dual,<:MaxSense}, pb::Bound{<:Primal,<:MaxSense})
    return db.value - pb.value
end

# fallback ?

"""
    gap

relative gap. Gap is non-positive if pb reached db
"""
function gap(pb::Bound{<:Primal,<:MinSense}, db::Bound{<:Dual,<:MinSense})
    return diff(pb, db) / abs(db.value)
end

function gap(db::Bound{<:Dual,<:MinSense}, pb::Bound{<:Primal,<:MinSense})
    return diff(pb, db) / abs(db.value)
end

function gap(pb::Bound{<:Primal,<:MaxSense}, db::Bound{<:Dual,<:MaxSense})
    return diff(pb, db) / abs(pb.value)
end

function gap(db::Bound{<:Dual,<:MaxSense}, pb::Bound{<:Primal,<:MaxSense})
    return diff(pb, db) / abs(pb.value)
end

function printbounds(db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}) where {S<:MinSense}
    Printf.@printf "[ %.4f , %.4f ]" getvalue(db) getvalue(pb)
end

function printbounds(db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}) where {S<:MaxSense}
    Printf.@printf "[ %.4f , %.4f ]" getvalue(pb) getvalue(db)
end

function Base.show(io::IO, b::Bound)
    print(io, getvalue(b))
end

Base.promote_rule(B::Type{<:Bound}, ::Type{<:Real}) = B
Base.convert(::Type{Float64}, b::Bound) = b.value
Base.convert(B::Type{<:Bound}, r::Real)  = B(float(r))

Base.:*(b1::B, b2::B) where {B<:Bound} = B(float(b1) * float(b2))
Base.:-(b1::B, b2::B) where {B<:Bound} = B(float(b1) - float(b2))
Base.:+(b1::B, b2::B) where {B<:Bound} = B(float(b1) + float(b2))
Base.:/(b1::B, b2::B) where {B<:Bound} = B(float(b1) / float(b2))

Base.isless(b::Bound, r::Real) = b.value < r
Base.isless(r::Real, b::Bound) = r < b.value
Base.isless(b1::B, b2::B) where {B<:Bound} = float(b1) < float(b2)

"""
    Solution
"""

struct Solution{Space <: Coluna.AbstractSpace, Sense <: Coluna.AstractSense, Decision, Value}
    bound::Bound{Space, Sense}
    sol::DataStructures.SortedDict{Decision,Value}
end



# TODO move : 
# const PrimalSolVector = MembersVector{Id{Variable}, Variable, Float64}
# const DualSolVector = MembersVector{Id{Constraint}, Constraint, Float64}

"""
    PrimalSolution{S} where S <: AbstractObjSense

A struct to represent a `PrimalSolution` for an objective function with sense `S`.
The expected behaviour of a solution is implemented according to the sense `S`.
"""
# mutable struct PrimalSolution{S <: AbstractObjSense} <: AbstractSolution
#     bound::PrimalBound{S}
#     sol::PrimalSolVector
# end

function PrimalSolution{S}() where{S<:AbstractObjSense}
    return PrimalSolution{S}(PrimalBound{S}(), MembersVector{Float64}(Dict{VarId, Variable}()))
end

function PrimalSolution(f::AbstractFormulation)
    Sense = getobjsense(f)
    sol = MembersVector{Float64}(getvars(f))
    return PrimalSolution{Sense}(PrimalBound{Sense}(), sol)
end

function PrimalSolution(f::AbstractFormulation,
                        value::Number, 
                        soldict::Dict{Id{Variable},Float64})
    S = getobjsense(f)
    sol = MembersVector{Float64}(getvars(f))
    for (key, val) in soldict
        sol[key] = val
    end
    return PrimalSolution{S}(PrimalBound{S}(float(value)), sol)
end

"""
    DualSolution{S} where S <: AbstractObjSense

A struct to represent a `DualSolution` for an objective function with sense `S`.
The expected behaviour of a solution is implemented according to the sense `S`.
"""
# mutable struct DualSolution{S <: AbstractObjSense} <: AbstractSolution
#     bound::DualBound{S}
#     sol::DualSolVector
# end

function DualSolution{S}() where {S<:AbstractObjSense}
    return DualSolution{S}(DualBound{S}(), MembersVector{Float64}(Dict{ConstrId, Constraint}()))
end

function DualSolution(f::AbstractFormulation)
    Sense = getobjsense(f)
    sol = MembersVector{Float64}(getconstrs(f))
    return DualSolution{Sense}(DualBound{Sense}(), sol)
end

function DualSolution(f::AbstractFormulation, 
                      value::Number, 
                      soldict::Dict{Id{Constraint},Float64})
    S = getobjsense(f)
    sol = MembersVector{Float64}(getconstrs(f))
    for (key, val) in soldict
        sol[key] = val
    end
    return DualSolution{S}(DualBound{S}(float(value)), sol)
end

getbound(s::AbstractSolution) = s.bound
getsol(s::AbstractSolution) = s.sol
getvalue(s::AbstractSolution) = float(s.bound)
setvalue!(s::AbstractSolution, v::Float64) = s.bound = v

iterate(s::AbstractSolution) = iterate(s.sol)
iterate(s::AbstractSolution, state) = iterate(s.sol, state)
length(s::AbstractSolution) = length(s.sol)
lastindex(s::AbstractSolution) = lastindex(s.sol)

_show_sol_type(io::IO, p::PrimalSolution) = println(io, "\n┌ Primal Solution :")
_show_sol_type(io::IO, d::DualSolution) = println(io, "\n┌ Dual Solution :")

function Base.show(io::IO, sol::AbstractSolution)
    _show_sol_type(io, sol)
    _sol = getsol(sol)
    ids = sort!(collect(keys(_sol)))
    for id in ids
        println(io, "| ", getname(getelement(_sol, id)), " = ", _sol[id])
    end
    @printf(io, "└ value = %.2f \n", float(getbound(sol)))
end

Base.copy(s::T) where {T<:AbstractSolution} = T(s.bound, copy(s.sol))

function Base.isinteger(sol::AbstractSolution)
    for (vc_id, val) in getsol(sol)
        !isinteger(val) && return false
    end
    return true
end

isfractional(s::AbstractSolution) = !Base.isinteger(s)

function contains(sol::PrimalSolution, d::AbstractVarDuty)
    filtered_sol = filter(v -> getduty(v) <= d, getsol(sol))
    return length(filtered_sol) > 0
end

function contains(sol::DualSolution, d::AbstractConstrDuty)
    filtered_sol = filter(c -> getduty(c) <= d, getsol(sol))
    return length(filtered_sol) > 0
end

_value(constr::Constraint) = getcurrhs(constr)
_value(var::Variable) = getcurcost(var)
function Base.filter(f::Function, sol::T) where {T<:AbstractSolution}
    newsol = filter(f, getsol(sol))
    elements = getelements(getsol(sol))
    bound = 0.0
    for (id, val) in newsol
        bound += val * _value(elements[id])
    end
    return T(bound, newsol) 
end

struct PrimalBound{S <: AbstractObjSense} <: AbstractBound
    value::Float64
end
PrimalBound{MinSense}() = PrimalBound{MinSense}(Inf)
PrimalBound{MaxSense}() = PrimalBound{MaxSense}(-Inf)

struct DualBound{S <: AbstractObjSense} <: AbstractBound
    value::Float64
end
DualBound{MinSense}() = DualBound{MinSense}(-Inf)
DualBound{MaxSense}() = DualBound{MaxSense}(Inf)

getvalue(b::AbstractBound) = b.value

gap(pb::PrimalBound{MinSense}, db::DualBound{MinSense}) = diff(pb, db) / abs(db.value)
gap(pb::PrimalBound{MaxSense}, db::DualBound{MaxSense}) = diff(pb, db) / abs(pb.value)
gap(db::DualBound{MinSense}, pb::PrimalBound{MinSense}) = diff(pb, db) / abs(db.value)
gap(db::DualBound{MaxSense}, pb::PrimalBound{MaxSense}) = diff(pb, db) / abs(pb.value)

isbetter(b1::PrimalBound{MinSense}, b2::PrimalBound{MinSense}) = b1.value < b2.value
isbetter(b1::PrimalBound{MaxSense}, b2::PrimalBound{MaxSense}) = b1.value > b2.value
isbetter(b1::DualBound{MinSense}, b2::DualBound{MinSense}) = b1.value > b2.value
isbetter(b1::DualBound{MaxSense}, b2::DualBound{MaxSense}) = b1.value < b2.value

diff(pb::PrimalBound{MinSense}, db::DualBound{MinSense}) = pb.value - db.value
diff(db::DualBound{MinSense}, pb::PrimalBound{MinSense}) = pb.value - db.value
diff(pb::PrimalBound{MaxSense}, db::DualBound{MaxSense}) = db.value - pb.value
diff(db::DualBound{MaxSense}, pb::PrimalBound{MaxSense}) = db.value - pb.value

function printbounds(db::DualBound{S}, pb::PrimalBound{S}) where {S<:MinSense}
    print("[ ", db,  " , ", pb, " ]")
end

function printbounds(db::DualBound{S}, pb::PrimalBound{S}) where {S<:MaxSense}
    print("[ ", pb,  " , ", db, " ]")
end

function Base.show(io::IO, b::AbstractBound)
    print(io, getvalue(b))
end
Base.promote_rule(::Type{<:AbstractBound}, ::Type{<:Real}) = Float64
Base.convert(::Type{Float64}, b::AbstractBound) = b.value

Base.isless(b::AbstractBound, r::Real) = b.value < r

abstract type AbstractSolution end

struct PrimalSolution{S <: AbstractObjSense} <: AbstractSolution
    bound::PrimalBound{S}
    sol::Dict{Id{Variable},Float64}
end

function PrimalSolution{S}() where {S <: AbstractObjSense}
    return PrimalSolution{S}(PrimalBound{S}(), Dict{Id{Variable},Float64}())
end

function PrimalSolution{S}(value::Float64, sol::Dict{Id{Variable},Float64}
                           ) where {S <: AbstractObjSense}
    return PrimalSolution{S}(PrimalBound{S}(value), sol)
end

struct DualSolution{S <: AbstractObjSense} <: AbstractSolution
    bound::DualBound{S}
    sol::Dict{Id{Constraint},Float64}
end

function DualSolution{S}() where {S <: AbstractObjSense}
    return DualSolution{S}(DualBound{S}(), Dict{Id{Constraint},Float64}())
end

function DualSolution{S}(value::Float64, sol::Dict{Id{Constraint},Float64}
                           ) where {S <: AbstractObjSense}
    return DualSolution{S}(DualBound{S}(value), sol)
end

getbound(s::AbstractSolution) = s.bound
getsol(s::AbstractSolution) = s.sol
Base.copy(s::T) where {T<:AbstractSolution} = T(s.bound, copy(s.sol))

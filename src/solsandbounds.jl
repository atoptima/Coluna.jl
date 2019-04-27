Base.float(b::AbstractBound) = b.value

"""
    PrimalBound{S} where S <: AbstractObjSense

A struct to represent a `PrimalBound` for an objective function with sense `S`.
The expected behaviour of a bound is implemented according to the sense `S`.
"""
struct PrimalBound{S <: AbstractObjSense} <: AbstractBound
    value::Float64
end
PrimalBound(S::Type{MinSense}) = PrimalBound{S}(Inf)
PrimalBound(S::Type{MaxSense}) = PrimalBound{S}(-Inf)
PrimalBound(S::Type{<: AbstractObjSense}, n::Number) = PrimalBound{S}(float(n))

"""
    DualBound{S} where S <: AbstractObjSense

A struct to represent a `DualBound` for an objective function with sense `S`.
The expected behaviour of a bound is implemented according to the sense `S`.
"""
struct DualBound{S <: AbstractObjSense} <: AbstractBound
    value::Float64
end
DualBound(S::Type{MinSense}) = DualBound{S}(-Inf)
DualBound(S::Type{MaxSense}) = DualBound{S}(Inf)
DualBound(S::Type{<: AbstractObjSense}, n::Number) = DualBound{S}(float(n))

getvalue(b::AbstractBound) = b.value

"Returns `true` iff `b1` is considered to be a better primal bound than `b2` for a minimization objective function."
isbetter(b1::PrimalBound{MinSense}, b2::PrimalBound{MinSense}) = b1.value < b2.value

"Returns `true` iff `b1` is considered to be a better primal bound than `b2` for a maximization objective function."
isbetter(b1::PrimalBound{MaxSense}, b2::PrimalBound{MaxSense}) = b1.value > b2.value

"Returns `true` iff `b1` is considered to be a better dual bound than `b2` for a minimization objective function."
isbetter(b1::DualBound{MinSense}, b2::DualBound{MinSense}) = b1.value > b2.value

"Returns `true` iff `b1` is considered to be a better dual bound than `b2` for a maximization objective function."
isbetter(b1::DualBound{MaxSense}, b2::DualBound{MaxSense}) = b1.value < b2.value

"Returns the `pb` - `db` for a minimization objective function. In this sense because in a minimization problem the primal bound is supposed to be larger than the dual bound."
diff(pb::PrimalBound{MinSense}, db::DualBound{MinSense}) = pb.value - db.value

"Returns the `pb` - `db` for a minimization objective function. In this sense because in a minimization problem the primal bound is supposed to be larger than the dual bound."
diff(db::DualBound{MinSense}, pb::PrimalBound{MinSense}) = pb.value - db.value

"Returns the `db` - `pb` for a maximization objective function. In this sense because in a maximization problem the dual bound is supposed to be larger than the primal bound."
diff(pb::PrimalBound{MaxSense}, db::DualBound{MaxSense}) = db.value - pb.value

"Returns the `db` - `pb` for a maximization objective function. In this sense because in a maximization problem the dual bound is supposed to be larger than the primal bound."
diff(db::DualBound{MaxSense}, pb::PrimalBound{MaxSense}) = db.value - pb.value

"Returns the relative gap between `pb` and `db`. A negative number if `db` is larger than `pb`."
gap(pb::PrimalBound{MinSense}, db::DualBound{MinSense}) = diff(pb, db) / abs(db.value)

"Returns the relative gap between `pb` and `db`. A negative number if `db` is larger than `pb`."
gap(db::DualBound{MinSense}, pb::PrimalBound{MinSense}) = diff(pb, db) / abs(db.value)

"Returns the relative gap between `pb` and `db`. A negative number if `pb` is larger than `db`."
gap(pb::PrimalBound{MaxSense}, db::DualBound{MaxSense}) = diff(pb, db) / abs(pb.value)

"Returns the relative gap between `pb` and `db`. A negative number if `pb` is larger than `db`."
gap(db::DualBound{MaxSense}, pb::PrimalBound{MaxSense}) = diff(pb, db) / abs(pb.value)

function printbounds(db::DualBound{S}, pb::PrimalBound{S}) where {S<:MinSense}
    print("[ ", db,  " , ", pb, " ]")
end

function printbounds(db::DualBound{S}, pb::PrimalBound{S}) where {S<:MaxSense}
    print("[ ", pb,  " , ", db, " ]")
end

function Base.show(io::IO, b::AbstractBound)
    print(io, getvalue(b))
end
Base.promote_rule(B::Type{<:AbstractBound}, ::Type{<:Real}) = B
Base.convert(::Type{Float64}, b::AbstractBound) = b.value
Base.convert(B::Type{<: AbstractBound}, r::Real)  = B(float(r))

Base.:*(b1::B, b2::B) where {B <: AbstractBound} = B(float(b1) * float(b2))
Base.:-(b1::B, b2::B) where {B <: AbstractBound} = B(float(b1) - float(b2))
Base.:+(b1::B, b2::B) where {B <: AbstractBound} = B(float(b1) + float(b2))
Base.:/(b1::B, b2::B) where {B <: AbstractBound} = B(float(b1) / float(b2))

Base.isless(b::AbstractBound, r::Real) = b.value < r
Base.isless(b1::B, b2::B) where {B <: AbstractBound} = float(b1) < float(b2)

abstract type AbstractSolution end

"""
    PrimalSolution{S} where S <: AbstractObjSense

A struct to represent a `PrimalSolution` for an objective function with sense `S`.
The expected behaviour of a solution is implemented according to the sense `S`.
"""
struct PrimalSolution{S <: AbstractObjSense} <: AbstractSolution
    bound::PrimalBound{S}
    sol::Dict{Id{Variable},Float64}
end

function PrimalSolution(S::Type{<: AbstractObjSense})
    return PrimalSolution{S}(PrimalBound(S), Dict{Id{Variable},Float64}())
end

function PrimalSolution(S::Type{<: AbstractObjSense}, 
                        value::Number, 
                        sol::Dict{Id{Variable},Float64})
    return PrimalSolution{S}(PrimalBound(S, value), sol)
end

"""
    DualSolution{S} where S <: AbstractObjSense

A struct to represent a `DualSolution` for an objective function with sense `S`.
The expected behaviour of a solution is implemented according to the sense `S`.
"""
struct DualSolution{S <: AbstractObjSense} <: AbstractSolution
    bound::DualBound{S}
    sol::Dict{Id{Constraint},Float64}
end

function DualSolution(S::Type{<: AbstractObjSense})
    return DualSolution{S}(DualBound(S), Dict{Id{Constraint},Float64}())
end

function DualSolution(S::Type{<: AbstractObjSense}, 
                      value::Number, 
                      sol::Dict{Id{Constraint},Float64})
    return DualSolution{S}(DualBound(S, value), sol)
end

getbound(s::AbstractSolution) = s.bound
getvalue(s::AbstractSolution) = float(s.bound)
getsol(s::AbstractSolution) = s.sol

iterate(s::AbstractSolution) = iterate(s.sol)
iterate(s::AbstractSolution, state) = iterate(s.sol, state)
length(s::AbstractSolution) = length(s.sol)
lastindex(s::AbstractSolution) = lastindex(s.sol)

_show_sol_type(io::IO, p::PrimalSolution) = println(io, "\n┌ Primal Solution :")
_show_sol_type(io::IO, d::DualSolution) = println(io, "\n┌ Dual Solution :")

function Base.show(io::IO, sol::AbstractSolution)
    _show_sol_type(io, sol)
    for (id, val) in sol
        println(io, "| ", id, " => ", val)
    end
    @printf(io, "└ value = %.2f \n", float(getbound(sol)))
end
Base.copy(s::T) where {T<:AbstractSolution} = T(s.bound, copy(s.sol))

function showdebug(io::IO, sol::AbstractSolution, 
                   formulation::AbstractFormulation)
    _show_sol_type(io, sol)
    ids = sort!(collect(keys(getsol(sol))))
    for id in ids
        println(io, "| ", getname(getelem(formulation, id)), " => ", sol.sol[id])
    end
    @printf(io, "└ value = %.2f \n", float(getbound(sol)))
end

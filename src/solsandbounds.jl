Base.float(b::AbstractBound) = b.value

"""
    PrimalBound{S} where S <: AbstractObjSense

A struct to represent a `PrimalBound` for an objective function with sense `S`.
The expected behaviour of a bound is implemented according to the sense `S`.
"""
struct PrimalBound{S <: AbstractObjSense} <: AbstractBound
    value::Float64
end
PrimalBound{S}() where {S<:AbstractObjSense} = PrimalBound{S}(defaultprimalboundvalue(S))

defaultprimalboundvalue(::Type{MinSense}) = Inf
defaultprimalboundvalue(::Type{MaxSense}) = -Inf

"""
    DualBound{S} where S <: AbstractObjSense

A struct to represent a `DualBound` for an objective function with sense `S`.
The expected behaviour of a bound is implemented according to the sense `S`.
"""
struct DualBound{S <: AbstractObjSense} <: AbstractBound
    value::Float64
end
DualBound{S}() where {S<:AbstractObjSense} = DualBound{S}(defaultdualboundvalue(S))

defaultdualboundvalue(::Type{MinSense}) = -Inf
defaultdualboundvalue(::Type{MaxSense}) = +Inf

getvalue(b::AbstractBound) = b.value

valueinminsense(b::PrimalBound) = b.value
valueinminsense(b::DualBound) = -b.value

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
Base.isless(r::Real, b::AbstractBound) = r < b.value
Base.isless(b1::B, b2::B) where {B <: AbstractBound} = float(b1) < float(b2)

abstract type AbstractSolution end

"""
    PrimalSolution{S} where S <: AbstractObjSense

A struct to represent a `PrimalSolution` for an objective function with sense `S`.
The expected behaviour of a solution is implemented according to the sense `S`.
"""
mutable struct PrimalSolution{S <: AbstractObjSense} <: AbstractSolution
    bound::PrimalBound{S}
    sol::MembersVector{Id{Variable}, Variable, Float64}
end

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

function Base.isinteger(s::PrimalSolution)
    for (var_id, val) in getsol(s)
        !isinteger(val) && return false
    end
    return true
end

isfractional(s::AbstractSolution) = !Base.isinteger(s)

"""
    DualSolution{S} where S <: AbstractObjSense

A struct to represent a `DualSolution` for an objective function with sense `S`.
The expected behaviour of a solution is implemented according to the sense `S`.
"""
struct DualSolution{S <: AbstractObjSense} <: AbstractSolution
    bound::DualBound{S}
    sol::MembersVector{Id{Constraint}, Constraint, Float64}
end

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


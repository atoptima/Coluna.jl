# alias only used in this file
const Primal = Coluna.AbstractPrimalSpace
const Dual = Coluna.AbstractDualSpace
const MinSense = Coluna.AbstractMinSense
const MaxSense = Coluna.AbstractMaxSense


# Bounds
mutable struct Bound{Space<:Coluna.AbstractSpace,Sense<:Coluna.AbstractSense} <: Real
    value::Float64
end   

_defaultboundvalue(::Type{<:Primal}, ::Type{<:MinSense}) = Inf
_defaultboundvalue(::Type{<:Primal}, ::Type{<:MaxSense}) = -Inf
_defaultboundvalue(::Type{<:Dual}, ::Type{<:MinSense}) = -Inf
_defaultboundvalue(::Type{<:Dual}, ::Type{<:MaxSense}) = Inf

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
# diff already exist in Base, rename this method dist ?
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

"""
    printbounds

doc todo
"""
function printbounds(io::IO, db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}) where {S<:MinSense}
    Printf.@printf io "[ %.4f , %.4f ]" getvalue(db) getvalue(pb)
end

function printbounds(io::IO, db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}) where {S<:MaxSense}
    Printf.@printf io "[ %.4f , %.4f ]" getvalue(pb) getvalue(db)
end

function Base.show(io::IO, b::Bound)
    print(io, getvalue(b))
end

Base.promote_rule(B::Type{<:Bound}, ::Type{<:AbstractFloat}) = B
Base.promote_rule(B::Type{<:Bound}, ::Type{<:Integer}) = B
Base.promote_rule(B::Type{<:Bound}, ::Type{<:AbstractIrrational}) = B
Base.promote_rule(::Type{Bound{Primal,Se}}, ::Type{Bound{Dual,Se}}) where {Se<:Coluna.AbstractSense} = Float64

Base.convert(::Type{<:AbstractFloat}, b::Bound) = b.value
Base.convert(::Type{<:Integer}, b::Bound) = b.value
Base.convert(::Type{<:AbstractIrrational}, b::Bound) = b.value
Base.convert(B::Type{<:Bound}, f::AbstractFloat) = B(f)
Base.convert(B::Type{<:Bound}, i::Integer) = B(i)
Base.convert(B::Type{<:Bound}, i::AbstractIrrational) = B(i)

Base.:+(b1::B, b2::B) where {B<:Bound} = B(b1.value + b2.value)
Base.:-(b1::B, b2::B) where {B<:Bound} = B(b1.value - b2.value)
Base.:*(b1::B, b2::B) where {B<:Bound} = B(b1.value * b2.value)
Base.:/(b1::B, b2::B) where {B<:Bound} = B(b1.value / b2.value)
Base.:(==)(b1::B, b2::B) where {B<:Bound} = b1.value == b2.value
Base.:<(b1::B, b2::B) where {B<:Bound} = b1.value < b2.value
Base.:(<=)(b1::B, b2::B) where {B<:Bound} = b1.value <= b2.value
Base.:(>=)(b1::B, b2::B) where {B<:Bound} = b1.value >= b2.value
Base.:>(b1::B, b2::B) where {B<:Bound} = b1.value > b2.value 

# Solution
struct Solution{Space<:Coluna.AbstractSpace,Sense<:Coluna.AbstractSense,Decision,Value} <: AbstractDict{Decision,Value}
    bound::Bound{Space, Sense}
    sol::DataStructures.SortedDict{Decision,Value}
end

"""
    Solution

Should be used like a dict
doc todo
"""
function Solution{Sp,Se,De,Va}() where {Sp<:Coluna.AbstractSpace,Se<:Coluna.AbstractSense,De,Va}
    bound = Bound{Sp,Se}()
    sol = DataStructures.SortedDict{De,Va}()
    return Solution(bound, sol)
end

function Solution{Sp,Se,De,Va}(solution::Dict{De,Va}, value::Float64) where {Sp<:Coluna.AbstractSpace,Se<:Coluna.AbstractSense,De,Va}
    bound = Bound{Sp,Se}(value)
    sol = DataStructures.SortedDict{De,Va}(solution)
    return Solution(bound, sol)
end

function Solution{Sp,Se,De,Va}(solution::Dict{De,Va}, bound::Bound{Sp,Se}) where {Sp<:Coluna.AbstractSpace,Se<:Coluna.AbstractSense,De,Va}
    sol = DataStructures.SortedDict{De,Va}(solution)
    return Solution(bound, sol)
end

getbound(s::Solution) = s.bound
getvalue(s::Solution) = float(s.bound)
setvalue!(s::Solution, v::Float64) = s.bound = v

Base.iterate(s::Solution) = iterate(s.sol)
Base.iterate(s::Solution, state) = iterate(s.sol, state)
Base.length(s::Solution) = length(s.sol)
Base.lastindex(s::Solution) = lastindex(s.sol)

_show_sol_type(io::IO, ::Type{<:Primal}) = println(io, "\n┌ Primal Solution :")
_show_sol_type(io::IO, ::Type{<:Dual}) = println(io, "\n┌ Dual Solution :")
function Base.show(io::IO, solution::Solution{Sp,Se,De,Va}) where {Sp,Se,De,Va}
    _show_sol_type(io, Sp)
    for (decision, value) in solution
        println(io, "| ", decision, " = ", value)
    end
    Printf.@printf(io, "└ value = %.2f \n", float(getbound(solution)))
end

Base.copy(s::S) where {S<:Solution} = S(s.bound, copy(s.sol))

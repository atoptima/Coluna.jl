# alias only used in this file
const Primal = Coluna.AbstractPrimalSpace
const Dual = Coluna.AbstractDualSpace
const MinSense = Coluna.AbstractMinSense
const MaxSense = Coluna.AbstractMaxSense


# Bounds
struct Bound{Space<:Coluna.AbstractSpace,Sense<:Coluna.AbstractSense} <: Real
    value::Float64
    Bound{Space,Sense}(x::Number) where {Space,Sense} = new(x === NaN ? _defaultboundvalue(Space, Sense) : x)
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


"""
    diff 

distance to reach the dual bound from the primal bound;
non-positive if dual bound reached.
"""
function Base.diff(pb::Bound{<:Primal,<:MinSense}, db::Bound{<:Dual,<:MinSense})
    return pb.value - db.value
end

function Base.diff(db::Bound{<:Dual,<:MinSense}, pb::Bound{<:Primal,<:MinSense})
    return pb.value - db.value
end

function Base.diff(pb::Bound{<:Primal,<:MaxSense}, db::Bound{<:Dual,<:MaxSense})
    return db.value - pb.value
end

function Base.diff(db::Bound{<:Dual,<:MaxSense}, pb::Bound{<:Primal,<:MaxSense})
    return db.value - pb.value
end

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
function printbounds(db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}) where {S<:MinSense}
    Printf.@printf "[ %.4f , %.4f ]" getvalue(db) getvalue(pb)
end

function printbounds(db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}) where {S<:MaxSense}
    Printf.@printf "[ %.4f , %.4f ]" getvalue(pb) getvalue(db)
end

function Base.show(io::IO, b::Bound)
    print(io, getvalue(b))
end

Base.promote_rule(B::Type{<:Bound}, ::Type{<:AbstractFloat}) = B
Base.promote_rule(B::Type{<:Bound}, ::Type{<:Integer}) = B
Base.promote_rule(B::Type{<:Bound}, ::Type{<:AbstractIrrational}) = B
Base.promote_rule(::Type{<:Bound{<:Primal,Se}}, ::Type{<:Bound{<:Dual,Se}}) where {Se<:Coluna.AbstractSense} = Float64

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
Base.isapprox(b1::B, b2::B) where {B<:Bound} = isapprox(b1.value, b2.value)
Base.isapprox(b::B, val::Number) where {B<:Bound} = isapprox(b.value, val)
Base.isapprox(val::Number, b::B) where {B<:Bound} = isapprox(b.value, val)

# Solution
struct Solution{Model<:AbstractModel,Decision,Value} <: AbstractDict{Decision,Value}
    model::Model
    bound::Float64
    sol::DynamicSparseArrays.PackedMemoryArray{Decision,Value}
end

"""
    Solution

Should be used like a dict
doc todo
"""
function Solution{Mo,De,Va}(model::Mo) where {Mo<:AbstractModel,De,Va}
    sol = DynamicSparseArrays.dynamicsparsevec(De[], Va[])
    return Solution(model, NaN, sol)
end

function Solution{Mo,De,Va}(model::Mo, decisions::Vector{De}, vals::Vector{Va}, value::Float64) where {Mo<:AbstractModel,De,Va}
    sol = DynamicSparseArrays.dynamicsparsevec(decisions, vals)
    return Solution(model, value, sol)
end

getsol(s::Solution) = s.sol
getvalue(s::Solution) = float(s.bound)

Base.iterate(s::Solution) = iterate(s.sol)
Base.iterate(s::Solution, state) = iterate(s.sol, state)
Base.length(s::Solution) = length(s.sol)
Base.get(s::Solution{Mo,De,Va}, id::De, default) where {Mo,De,Va} = s.sol[id]
Base.setindex!(s::Solution{Mo,De,Va}, val::Va, id::De) where {Mo,De,Va} = s.sol[id] = val

# todo: move in DynamicSparseArrays or avoid using filter ?
function Base.filter(f::Function, pma::DynamicSparseArrays.PackedMemoryArray{K,T,P}) where {K,T,P}
    ids = Vector{K}()
    vals = Vector{T}()
    for e in pma
        if f(e)
            push!(ids, e[1])
            push!(vals, e[2])
        end
    end
    return DynamicSparseArrays.dynamicsparsevec(ids, vals)
end

function Base.filter(f::Function, s::S) where {S <: Solution}
    return S(s.model, s.bound, filter(f, s.sol))
end

function Base.show(io::IO, solution::Solution{Mo,De,Va}) where {Mo,De,Va}
    println(io, "Solution")
    for (decision, value) in solution
        println(io, "| ", decision, " = ", value)
    end
    Printf.@printf(io, "└ value = %.2f \n", getvalue(solution))
end

Base.copy(s::S) where {S<:Solution} = S(s.bound, copy(s.sol))
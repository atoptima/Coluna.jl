# alias only used in this file
const Primal = AbstractPrimalSpace
const Dual = AbstractDualSpace
const MinSense = AbstractMinSense
const MaxSense = AbstractMaxSense

# Bounds
struct Bound{Space<:AbstractSpace,Sense<:AbstractSense} <: Real
    value::Float64
    Bound{Space,Sense}(x::Number) where {Space,Sense} = new(x === NaN ? _defaultboundvalue(Space, Sense) : x)
end

_defaultboundvalue(::Type{<:Primal}, ::Type{<:MinSense}) = Inf
_defaultboundvalue(::Type{<:Primal}, ::Type{<:MaxSense}) = -Inf
_defaultboundvalue(::Type{<:Dual}, ::Type{<:MinSense}) = -Inf
_defaultboundvalue(::Type{<:Dual}, ::Type{<:MaxSense}) = Inf

"""
    Bound{Space,Sense}()

Create a default bound for a problem with objective sense `Sense<:AbstractSense` in `Space<:AbstractSpace`.  
"""
function Bound{Space,Sense}() where {Space<:AbstractSpace,Sense<:AbstractSense}
    val = _defaultboundvalue(Space, Sense)
    return Bound{Space,Sense}(val)
end

getvalue(b::Bound) = b.value
Base.float(b::Bound) = b.value

"""
    isbetter(b1, b2)

Returns true if bound b1 is better than bound b2.
The function take into account the space (primal or dual) and the objective sense (min, max) of the bounds.
"""
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Primal,Se<:MinSense} = b1.value < b2.value
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Primal,Se<:MaxSense} = b1.value > b2.value
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Dual,Se<:MinSense} = b1.value > b2.value
isbetter(b1::Bound{Sp,Se}, b2::Bound{Sp,Se}) where {Sp<:Dual,Se<:MaxSense} = b1.value < b2.value

"""
    best(b1, b2)

Returns the best bound between b1 and b2.
"""
best(b1::B, b2::B) where {B<:Bound} = isbetter(b1, b2) ? b1 : b2

"""
    worst(b1, b2)

Returns the worst bound between b1 and b2.
"""
worst(b1::B, b2::B) where {B<:Bound} = isbetter(b1, b2) ? b2 : b1


"""
    diff(pb, db)
    diff(db, pb)

Distance between a primal bound and a dual bound that have the same objective sense.
Distance is non-positive if dual bound reached primal bound.
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
    gap(pb, db)
    gap(db, pb)

Return relative gap. Gap is non-positive if pb reached db.
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
    isunbounded(pb)
    isunbounded(db)

Return true is the primal bound or the dual bound is unbounded.
"""
isunbounded(b::Bound{<:Primal,<:MinSense}) = getvalue(b) == -Inf
isunbounded(b::Bound{<:Dual,<:MinSense}) = getvalue(b) == Inf
isunbounded(b::Bound{<:Primal,<:MaxSense}) = getvalue(b) == Inf
isunbounded(b::Bound{<:Dual,<:MaxSense}) = getvalue(b) == -Inf


"""
    isinfeasible(pb)
    isinfeasible(db)

Return true is the primal bound or the dual bound is infeasible.
"""
isinfeasible(b::Bound{<:Primal,<:MinSense}) = getvalue(b) == Inf
isinfeasible(b::Bound{<:Dual,<:MinSense}) = getvalue(b) == -Inf
isinfeasible(b::Bound{<:Primal,<:MaxSense}) = getvalue(b) == -Inf
isinfeasible(b::Bound{<:Dual,<:MaxSense}) = getvalue(b) == Inf

"""
    printbounds(db, pb [, io])
    
Prints the lower and upper bound according to the objective sense.

Can receive io::IO as an input, to eventually output the print to a file or buffer.
"""
function printbounds(db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}, io::IO=Base.stdout) where {S<:MinSense}
    Printf.@printf io "[ %.4f , %.4f ]" getvalue(db) getvalue(pb)
end

function printbounds(db::Bound{<:Dual,S}, pb::Bound{<:Primal,S}, io::IO=Base.stdout) where {S<:MaxSense}
    Printf.@printf io "[ %.4f , %.4f ]" getvalue(pb) getvalue(db)
end

function Base.show(io::IO, b::Bound)
    print(io, getvalue(b))
end

Base.promote_rule(B::Type{<:Bound}, ::Type{<:AbstractFloat}) = B
Base.promote_rule(B::Type{<:Bound}, ::Type{<:Integer}) = B
Base.promote_rule(B::Type{<:Bound}, ::Type{<:AbstractIrrational}) = B
Base.promote_rule(::Type{<:Bound{<:Primal,Se}}, ::Type{<:Bound{<:Dual,Se}}) where {Se<:AbstractSense} = Float64

Base.convert(::Type{<:AbstractFloat}, b::Bound) = b.value
Base.convert(::Type{<:Integer}, b::Bound) = b.value
Base.convert(::Type{<:AbstractIrrational}, b::Bound) = b.value
Base.convert(B::Type{<:Bound}, f::AbstractFloat) = B(f)
Base.convert(B::Type{<:Bound}, i::Integer) = B(i)
Base.convert(B::Type{<:Bound}, i::AbstractIrrational) = B(i)

Base.:-(b::B) where {B<:Bound} = B(-b.value)
Base.:+(b1::B, b2::B) where {B<:Bound} = B(b1.value + b2.value)
Base.:-(b1::B, b2::B) where {B<:Bound} = B(b1.value - b2.value)
Base.:*(b1::B, b2::B) where {B<:Bound} = B(b1.value * b2.value)
Base.:/(b1::B, b2::B) where {B<:Bound} = B(b1.value / b2.value)
Base.:(==)(b1::B, b2::B) where {B<:Bound} = b1.value == b2.value
Base.:<(b1::B, b2::B) where {B<:Bound} = b1.value < b2.value
Base.:(<=)(b1::B, b2::B) where {B<:Bound} = b1.value <= b2.value
Base.:(>=)(b1::B, b2::B) where {B<:Bound} = b1.value >= b2.value
Base.:>(b1::B, b2::B) where {B<:Bound} = b1.value > b2.value

"""
    TerminationStatus

Theses statuses are the possible reasons why an algorithm stopped the optimization. 
When a subsolver is called through MOI, the
MOI [`TerminationStatusCode`](https://jump.dev/MathOptInterface.jl/stable/apireference/#MathOptInterface.TerminationStatusCode)
is translated into a Coluna `TerminationStatus`.

Description of the termination statuses: 
- `OPTIMAL` : the algorithm found a global optimal solution given the optimality tolerance
- `INFEASIBLE` : the algorithm proved infeasibility
- `DUAL_INFEASIBLE` : the algorithm proved unboundedness
- `INFEASIBLE_OR_UNBOUNDED` : the algorithm proved infeasibility or unboundedness
- `TIME_LIMIT` : the algorithm stopped because of the time limit
- `NODE_LIMIT` : the branch-and-bound based algorithm stopped due to the node limit
- `OTHER_LIMIT` : the algorithm stopped because of a limit that is neither the time limit 
nor the node limit

If the algorithm has not been called, the default value of the termination status should be:
- `OPTIMIZE_NOT_CALLED`

If the conversion of a `MOI.TerminationStatusCode` returns `UNCOVERED_TERMINATION_STATUS`,
Coluna should stop because it enters in an undefined behavior.
"""
@enum(
    TerminationStatus, OPTIMIZE_NOT_CALLED, OPTIMAL, INFEASIBLE, DUAL_INFEASIBLE, INFEASIBLE_OR_UNBOUNDED,
    TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, UNCOVERED_TERMINATION_STATUS
)

"""
    SolutionStatus

Description of the solution statuses:
- `FEASIBLE_SOL` : the solution is feasible
- `INFEASIBLE_SOL` : the solution is not feasible

If there is no solution or if we don't have information about the solution, the 
solution status should be :
- `UNKNOWN_SOLUTION_STATUS`

"""
@enum(
    SolutionStatus, FEASIBLE_SOL, INFEASIBLE_SOL, UNKNOWN_FEASIBILITY, 
    UNKNOWN_SOLUTION_STATUS, UNCOVERED_SOLUTION_STATUS
)

"""
    convert_status(status::MOI.TerminationStatusCode) -> Coluna.TerminationStatus
    convert_status(status::Coluna.TerminationStatus) -> MOI.TerminationStatusCode
    convert_status(status::MOI.ResultStatusCode) -> Coluna.SolutionStatus
    convert_status(status::Coluna.SolutionStatus) -> MOI.ResultStatusCode

Convert a termination or solution `status` of a given type to the corresponding status in another type.
This method is used to communicate between Coluna and MathOptInterface.
"""
function convert_status(moi_status::MOI.TerminationStatusCode)
    moi_status == MOI.OPTIMIZE_NOT_CALLED && return OPTIMIZE_NOT_CALLED
    moi_status == MOI.OPTIMAL && return OPTIMAL
    moi_status == MOI.INFEASIBLE && return INFEASIBLE
    moi_status == MOI.DUAL_INFEASIBLE && return DUAL_INFEASIBLE
    moi_status == MOI.INFEASIBLE_OR_UNBOUNDED && return INFEASIBLE_OR_UNBOUNDED
    moi_status == MOI.TIME_LIMIT && return TIME_LIMIT
    moi_status == MOI.NODE_LIMIT && return NODE_LIMIT
    moi_status == MOI.OTHER_LIMIT && return OTHER_LIMIT
    return UNCOVERED_TERMINATION_STATUS
end

function convert_status(coluna_status::TerminationStatus)
    coluna_status == OPTIMIZE_NOT_CALLED && return MOI.OPTIMIZE_NOT_CALLED
    coluna_status == OPTIMAL && return MOI.OPTIMAL
    coluna_status == INFEASIBLE_OR_UNBOUNDED && return MOI.INFEASIBLE_OR_UNBOUNDED
    coluna_status == INFEASIBLE && return MOI.INFEASIBLE
    coluna_status == DUAL_INFEASIBLE && return MOI.DUAL_INFEASIBLE
    coluna_status == TIME_LIMIT && return MOI.TIME_LIMIT
    coluna_status == NODE_LIMIT && return MOI.NODE_LIMIT
    coluna_status == OTHER_LIMIT && return MOI.OTHER_LIMIT
    return MOI.OTHER_LIMIT
end

function convert_status(moi_status::MOI.ResultStatusCode)
    moi_status == MOI.NO_SOLUTION && return UNKNOWN_SOLUTION_STATUS
    moi_status == MOI.FEASIBLE_POINT && return FEASIBLE_SOL
    moi_status == MOI.INFEASIBLE_POINT && return INFEASIBLE_SOL
    return UNCOVERED_SOLUTION_STATUS
end

function convert_status(coluna_status::SolutionStatus)
    coluna_status == FEASIBLE_SOL && return MOI.FEASIBLE_POINT
    coluna_status == INFEASIBLE_SOL && return MOI.INFEASIBLE_POINT
    return MOI.OTHER_RESULT_STATUS
end

# Basic structure of a solution
struct Solution{Model<:AbstractModel,Decision<:Integer,Value} <: AbstractSparseVector{Decision,Value}
    model::Model
    bound::Float64
    status::SolutionStatus
    sol::SparseVector{Value,Decision}
end

"""
Solution is an internal data structure of Coluna and should not be used in
algorithms. See `MathProg.PrimalSolution` & `MathProg.DualSolution` instead.

    Solution(
        model::AbstractModel,
        decisions::Vector,
        values::Vector,
        solution_value::Float64,
        status::SolutionStatus
    )

Create a solution to the `model`. Other arguments are: 
- `decisions` is a vector with the index of each decision.
- `values` is a vector with the values for each decision.
- `solution_value` is the value of the solution.
- `status` is the solution status.
"""
function Solution{Mo,De,Va}(
    model::Mo, decisions::Vector{De}, values::Vector{Va}, solution_value::Float64, status::SolutionStatus
) where {Mo<:AbstractModel,De,Va}
    sol = sparsevec(decisions, values, Coluna.MAX_NB_ELEMS)
    return Solution(model, solution_value, status, sol)
end

"Return the model of a solution."
getmodel(s::Solution) = s.model

"Return the value (as a Bound) of `solution`"
getbound(s::Solution) = s.bound

"Return the value of `solution`."
getvalue(s::Solution) = float(s.bound)

"Return the solution status of `solution`."
getstatus(s::Solution) = s.status

# implementing indexing interface
Base.getindex(s::Solution, i::Integer) = getindex(s.sol, i)
Base.setindex!(s::Solution, v, i::Integer) = setindex!(s.sol, v, i)
Base.firstindex(s::Solution) = firstindex(s.sol)
Base.lastindex(s::Solution) = lastindex(s.sol)

# implementing abstract array interface
Base.size(s::Solution) = size(s.sol)
Base.length(s::Solution) = length(s.sol)
Base.IndexStyle(::Type{<:Solution{Mo,De,Va}}) where {Mo,De,Va} =
    IndexStyle(SparseVector{Va,De})
SparseArrays.nnz(s::Solution) = nnz(s.sol)

# It iterates only on non-zero values because:
# - we use indices (`Id`) that behaves like an Int with additional information and given a 
#   indice, we cannot deduce the additional information for the next one (i.e. impossible to
#   create an Id for next integer);
# - we don't know the length of the vector (it depends on the number of variables & 
#   constraints that varies over time).
function Base.iterate(s::Solution)
    iterator = Iterators.zip(findnz(s.sol)...)
    next = iterate(iterator)
    isnothing(next) && return nothing
    (item, zip_state) = next
    return (item, (zip_state, iterator))
end

function Base.iterate(::Solution, state)
    (zip_state, iterator) = state
    next = iterate(iterator, zip_state)
    isnothing(next) && return nothing
    (next_item, next_zip_state) = next
    return (next_item, (next_zip_state, iterator))
end

# # implementing sparse array interface
# SparseArrays.nnz(s::Solution) = nnz(s.sol)
# SparseArrays.nonzeroinds(s::Solution) = SparseArrays.nonzeroinds(s.sol)
# SparseArrays.nonzeros(s::Solution) = nonzeros(s.sol)

function _eq_sparse_vec(a::SparseVector, b::SparseVector)
    a_ids, a_vals = findnz(a)
    b_ids, b_vals = findnz(b)
    return a_ids == b_ids && a_vals == b_vals
end

Base.:(==)(::Solution, ::Solution) = false
function Base.:(==)(a::S, b::S) where {S<:Solution}
    return a.model == b.model && a.bound == b.bound && a.status == b.status &&
        _eq_sparse_vec(a.sol, b.sol)
end

function Base.in(p::Tuple{De,Va}, a::Solution{Mo,De,Va}, valcmp=(==)) where {Mo,De,Va}
    v = get(a, p[1], Base.secret_table_token)
    if v !== Base.secret_table_token
        return valcmp(v, p[2])
    end
    return false
end

function Base.show(io::IOContext, solution::Solution{Mo,De,Va}) where {Mo,De,Va}
    println(io, "Solution")
    for (decision, value) in solution
        println(io, "| ", decision, " = ", value)
    end
    Printf.@printf(io, "└ value = %.2f \n", getvalue(solution))
end

# Todo : revise method
Base.copy(s::S) where {S<:Solution} = S(s.bound, copy(s.sol))

# Implementing comparison between solution & dynamic matrix col view for solution comparison
function Base.:(==)(v1::DynamicMatrixColView, v2::Solution)
    for ((i1,j1), (i2,j2)) in Iterators.zip(v1,v2)
        if !(i1 == i2 && j1 == j2)
            return false
        end
    end
    return true
end

# Implementation of the addition & subtraction in SparseArrays always converts indices into
# `Int`. We need a custom implementation to presever the index type.
function _sol_custom_binarymap(
    f::Function, s1::Solution{Mo,De,Va1}, s2::Solution{Mo,De,Va2}
) where {Mo,De,Va1,Va2}
    x = s1.sol
    y = s2.sol
    R = Base.Broadcast.combine_eltypes(f, (x, y))
    n = length(x)
    length(y) == n || throw(DimensionMismatch())
    xnzind = SparseArrays.nonzeroinds(x)
    xnzval = nonzeros(x)
    ynzind = SparseArrays.nonzeroinds(y)
    ynzval = nonzeros(y)
    mx = length(xnzind)
    my = length(ynzind)
    cap = mx + my
    rind = Vector{De}(undef,cap)
    rval = Vector{R}(undef,cap)
    ir = SparseArrays._binarymap_mode_1!(f, mx, my, xnzind, xnzval, ynzind, ynzval, rind, rval)
    resize!(rind, ir)
    resize!(rval, ir)
    return SparseVector(n, rind, rval)
end
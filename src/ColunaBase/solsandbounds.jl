# Bounds
struct Bound <: Real
    min::Bool # max if false.
    primal::Bool # dual if false.
    value::Float64
    Bound(min::Bool, primal::Bool, x::Number) = new(min, primal, x === NaN ? _defaultboundvalue(primal, min) : x)
end

function _defaultboundvalue(primal::Bool, min::Bool)
    sc1 = min ? 1 : -1
    sc2 = primal ? 1 : -1
    return sc1 * sc2 * Inf
end

"""
    Bound(min, primal)

Create a default primal bound for a problem with objective sense (min or max) in the space (primal or dual).  
"""
function Bound(min, primal)
    val = _defaultboundvalue(primal, min)
    return Bound(min, primal, val)
end

getvalue(b::Bound) = b.value

"""
    isbetter(b1, b2)

Returns true if bound b1 is better than bound b2.
The function take into account the space (primal or dual) and the objective sense (min, max) of the bounds.
"""
function isbetter(b1::Bound, b2::Bound)
    @assert b1.min == b2.min && b1.primal == b2.primal
    sc1 = b1.min ? 1 : -1
    sc2 = b1.primal ? 1 : -1
    return sc1 * sc2 * b1.value < sc1 * sc2 * b2.value
end

"""
    best(b1, b2)

Returns the best bound between b1 and b2.
"""
best(b1::Bound, b2::Bound) = isbetter(b1, b2) ? b1 : b2

"""
    worst(b1, b2)

Returns the worst bound between b1 and b2.
"""
worst(b1::Bound, b2::Bound) = isbetter(b1, b2) ? b2 : b1


"""
    diff(pb, db)
    diff(db, pb)

Distance between a primal bound and a dual bound that have the same objective sense.
Distance is non-positive if dual bound reached primal bound.
"""
function diff(b1::Bound, b2::Bound)
    @assert b1.min == b2.min && b1.primal != b2.primal
    pb = b1.primal ? b1 : b2
    db = b1.primal ? b2 : b1
    sc = b1.min ? 1 : -1
    return sc * (pb.value - db.value)
end

"""
    gap(pb, db)
    gap(db, pb)

Return relative gap. Gap is non-positive if pb reached db.
"""
function gap(b1::Bound, b2::Bound)
    @assert b1.primal != b2.primal && b1.min == b2.min
    db = b1.primal ? b2 : b1
    pb = b1.primal ? b1 : b2
    den = b1.min ? db : pb
    return diff(b1, b2) / abs(den.value)
end

"""
    isunbounded(bound)

Return true is the primal bound or the dual bound is unbounded.
"""
function isunbounded(bound::Bound)
    inf = - _defaultboundvalue(bound.primal, bound.min)
    return getvalue(bound) == inf
end


"""
    isinfeasible(bound)

Return true is the primal bound or the dual bound is infeasible.
"""
isinfeasible(b::Bound) = isnothing(getvalue(b))

"""
    printbounds(db, pb [, io])
    
Prints the lower and upper bound according to the objective sense.

Can receive io::IO as an input, to eventually output the print to a file or buffer.
"""
function printbounds(db::Bound, pb::Bound, io::IO=Base.stdout)
    @assert !db.primal && pb.primal && db.min == pb.min
    if db.min
        Printf.@printf io "[ %.4f , %.4f ]" getvalue(db) getvalue(pb)
    else
        Printf.@printf io "[ %.4f , %.4f ]" getvalue(pb) getvalue(db)
    end
end

function Base.show(io::IO, b::Bound)
    print(io, getvalue(b))
end

# If you work with a Bound and another type, the Bound is promoted to the other type.
Base.promote_rule(::Type{Bound}, F::Type{<:AbstractFloat}) = F
Base.promote_rule(::Type{Bound}, I::Type{<:Integer}) = I
Base.promote_rule(::Type{Bound}, I::Type{<:AbstractIrrational}) = I

Base.convert(::Type{<:AbstractFloat}, b::Bound) = b.value
Base.convert(::Type{<:Integer}, b::Bound) = b.value
Base.convert(::Type{<:AbstractIrrational}, b::Bound) = b.value

"""
    TerminationStatus

Theses statuses are the possible reasons why an algorithm stopped the optimization. 
When a subsolver is called through MOI, the
MOI [`TerminationStatusCode`](https://jump.dev/MathOptInterface.jl/stable/apireference/#MathOptInterface.TerminationStatusCode)
is translated into a Coluna `TerminationStatus`.

Description of the termination statuses: 
- `OPTIMAL` : the algorithm found a global optimal solution given the optimality tolerance
- `INFEASIBLE` : the algorithm proved infeasibility
- `UNBOUNDED` : the algorithm proved unboundedness
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
    TerminationStatus, OPTIMIZE_NOT_CALLED, OPTIMAL, INFEASIBLE, UNBOUNDED,
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
    moi_status == MOI.LOCALLY_INFEASIBLE && return INFEASIBLE
    moi_status == MOI.DUAL_INFEASIBLE && return UNBOUNDED
    # TODO: Happens in MIP presolve (cf JuMP doc), we treat this case as unbounded. 
    moi_status == MOI.INFEASIBLE_OR_UNBOUNDED && return UNBOUNDED
    moi_status == MOI.TIME_LIMIT && return TIME_LIMIT
    moi_status == MOI.NODE_LIMIT && return NODE_LIMIT
    moi_status == MOI.OTHER_LIMIT && return OTHER_LIMIT
    return UNCOVERED_TERMINATION_STATUS
end

function convert_status(coluna_status::TerminationStatus)
    coluna_status == OPTIMIZE_NOT_CALLED && return MOI.OPTIMIZE_NOT_CALLED
    coluna_status == OPTIMAL && return MOI.OPTIMAL
    coluna_status == UNBOUNDED && return MOI.DUAL_INFEASIBLE
    coluna_status == INFEASIBLE && return MOI.INFEASIBLE
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
    sol = sparsevec(decisions, values, typemax(Int32)) #Coluna.MAX_NB_ELEMS)
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
Base.copy(s::S) where {S<:Solution} = S(s.model, s.bound, s.status, copy(s.sol))

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
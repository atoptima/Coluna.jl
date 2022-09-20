############################################################################################
# MathProg > Solutions
# Representations of the primal & dual solutions to a MILP formulation
############################################################################################

"Supertype for solutions operated by Coluna."
abstract type AbstractSolution end

# The API for `AbstractSolution` is not very clear yet.

# Redefine methods from ColunaBase to access the formulation, the value, the
# status of a Solution, and other specific information
ColunaBase.getmodel(s::AbstractSolution) = getmodel(s.solution)
ColunaBase.getvalue(s::AbstractSolution) = getvalue(s.solution)
ColunaBase.getbound(s::AbstractSolution) = getbound(s.solution)
ColunaBase.getstatus(s::AbstractSolution) = getstatus(s.solution)

Base.length(s::AbstractSolution) = length(s.solution)
Base.get(s::AbstractSolution, id, default) = get(s.solution, id, default)
Base.getindex(s::AbstractSolution, id) = getindex(s.solution, id)
Base.setindex!(s::AbstractSolution, val, id) = setindex!(s.solution, val, id)

# Iterating over a PrimalSolution or a DualSolution is similar to iterating over
# ColunaBase.Solution
Base.iterate(s::AbstractSolution) = iterate(s.solution)
Base.iterate(s::AbstractSolution, state) = iterate(s.solution, state)

function contains(sol::AbstractSolution, f::Function)
    for (elemid, _) in sol
        f(elemid) && return true
    end
    return false
end

function _sols_from_same_model(sols::NTuple{N, S}) where {N,S<:AbstractSolution}
    for i in 2:length(sols)
        getmodel(sols[i-1]) != getmodel(sols[i]) && return false
    end
    return true
end

# To check if a solution is part of solutions from the pool.
Base.:(==)(v1::DynamicMatrixColView, v2::AbstractSolution) = v1 == v2.solution

# To allocate an array with size equals to the number of non-zero elements when using
# "generation" syntax.
Base.length(gen::Base.Generator{<:AbstractSolution}) = nnz(gen.iter.solution)

############################################################################################
# Primal Solution                                                                          
############################################################################################
struct PrimalSolution{M} <: AbstractSolution
    solution::Solution{M,VarId,Float64}
    custom_data::Union{Nothing, BlockDecomposition.AbstractCustomData}
end

"""
    PrimalSolution(
        form::AbstractFormulation,
        varids::Vector{VarId},
        varvals::Vector{Float64},
        cost::Float64,
        status::SolutionStatus;
        custom_data::Union{Nothing, BlockDecomposition.AbstractCustomData} = nothing
    )

Create a primal solution to the formulation `form` of cost `cost` and status `status`.
The representations of the soslution is `varids` the set of the ids of the variables 
and `varvals` the values of the variables (`varvals[i]` is value of variable `varids[i]`).

The user can also attach to the primal solution a customized representation 
`custom_data`.
"""
function PrimalSolution(
    form::M, varids, varvals, cost, status; custom_data = nothing
) where {M<:AbstractFormulation}
    @assert length(varids) == length(varvals)
    sol = Solution{M,VarId,Float64}(form, varids, varvals, cost, status)
    return PrimalSolution{M}(sol, custom_data)
end

function Base.:(==)(a::PrimalSolution, b::PrimalSolution)
    return a.solution == b.solution && a.custom_data == b.custom_data
end

Base.copy(s::P) where {P<:PrimalSolution}= P(copy(s.solution), copy(s.custom_data))

function Base.isinteger(sol::PrimalSolution)
    for (vc_id, val) in sol
        if getperenkind(getmodel(sol), vc_id) !== Continuous && abs(round(val) - val) > 1e-5
            return false
        end
    end
    return true
end

function Base.isless(s1::PrimalSolution, s2::PrimalSolution)
    getobjsense(getmodel(s1)) == MinSense && return s1.solution.bound > s2.solution.bound
    return s1.solution.bound < s2.solution.bound
end

# Method `cat` is not implemented for a set of DualSolutions because @guimarqu don't know 
# how to concatenate var red cost of a variable if both bounds are active in different 
# solutions and because we don't need it for now.
function Base.cat(sols::PrimalSolution...)
    if !_sols_from_same_model(sols)
        error("Cannot concatenate solutions not attached to the same model.")
    end

    ids = VarId[]
    vals = Float64[]
    for sol in sols, (id, value) in sol
        push!(ids, id)
        push!(vals, value)
    end
    return PrimalSolution(
        getmodel(sols[1]), ids, vals, sum(getvalue.(sols)), getstatus(sols[1])
    )
end

############################################################################################
# Dual Solution
############################################################################################

# Indicate whether the active bound of a variable is the lower or the upper one.
@enum ActiveBound LOWER UPPER

struct DualSolution{M} <: AbstractSolution
    solution::Solution{M,ConstrId,Float64}
    var_redcosts::Dict{VarId, Tuple{Float64,ActiveBound}}
    custom_data::Union{Nothing, BlockDecomposition.AbstractCustomData}
end

"""
    DualSolution(
        form::AbstractFormulation,
        constrids::Vector{ConstrId},
        constrvals::Vector{Float64},
        varids::Vector{VarId},
        varvals::Vector{Float64},
        varactivebounds::Vector{ActiveBound},
        cost::Float64,
        status::SolutionStatus;
        custom_data::Union{Nothing, BlockDecomposition.AbstractColumnData} = nothing
    )

Create a dual solution to the formulation `form` of cost `cost` and status `status`.
It contains `constrids` the set of ids of the constraints and `constrvals` the values
of the constraints (`constrvals[i]` is dual value of `constrids[i]`). 
It also contains `varvals[i]` the dual values of the bound constraint `varactivebounds[i]` of the variables `varids`
(also known as the reduced cost).

The user can attach to the dual solution a customized representation 
`custom_data`.
"""
function DualSolution(
    form::M, constrids, constrvals, varids, varvals, varactivebounds, cost, status;
    custom_data = nothing
) where {M<:AbstractFormulation}
    @assert length(constrids) == length(constrvals)
    @assert length(varids) == length(varvals) == length(varactivebounds)
    var_redcosts = Dict{VarId, Tuple{Float64,ActiveBound}}()
    for i in 1:length(varids)
        var_redcosts[varids[i]] = (varvals[i],varactivebounds[i])
    end
    sol = Solution{M,ConstrId,Float64}(form, constrids, constrvals, cost, status)
    return DualSolution{M}(sol, var_redcosts, custom_data)
end

function Base.:(==)(a::DualSolution, b::DualSolution)
    return a.solution == b.solution && a.var_redcosts == b.var_redcosts && 
        a.custom_data == b.custom_data
end

Base.copy(s::D) where {D<:DualSolution} = D(copy(s.solution), copy(s.var_redcosts), copy(s.custom_data))

get_var_redcosts(s::DualSolution) = s.var_redcosts

function Base.isless(s1::DualSolution, s2::DualSolution)
    getobjsense(getmodel(s1)) == MinSense && return s1.solution.bound < s2.solution.bound
    return s1.solution.bound > s2.solution.bound
end

function Base.show(io::IO, solution::DualSolution{M}) where {M}
    println(io, "Dual solution")
    for (constrid, value) in solution
        println(io, "| ", getname(getmodel(solution), constrid), " = ", value)
    end
    for (varid, redcost) in solution.var_redcosts
        println(io, "| ", getname(getmodel(solution), varid), " = ", redcost[1], " (", redcost[2], ")")
    end
    Printf.@printf(io, "└ value = %.2f \n", getvalue(solution))
end

function Base.show(io::IO, solution::PrimalSolution{M}) where {M}
    println(io, "Primal solution")
    for (varid, value) in solution
        println(io, "| ", getname(getmodel(solution), varid), " = ", value)
    end
    Printf.@printf(io, "└ value = %.2f \n", getvalue(solution))
end

############################################################################################
# Linear Algebra
############################################################################################

# op(::S, ::S) has return type `S` for op ∈ (:+, :-) and S <: AbstractSolution 

_math_op_constructor(::Type{S}, form::F, varids, varvals, cost) where {S<:PrimalSolution,F} =
    PrimalSolution(form, varids, varvals, cost, ClB.UNKNOWN_SOLUTION_STATUS)

_math_op_constructor(::Type{<:S}, form::F, constrids, constrvals, cost) where {S<:DualSolution,F} = 
    DualSolution(form, constrids, constrvals, [], [], [], cost, ClB.UNKNOWN_SOLUTION_STATUS)

_math_op_cost(::Type{<:S}, form, varids, varvals) where {S<:PrimalSolution} = 
    mapreduce(((id,val),) -> getcurcost(form, id) * val, +, Iterators.zip(varids, varvals); init = 0.0)

_math_op_cost(::Type{<:S}, form, constrids, constrvals) where {S<:DualSolution} =
    mapreduce(((id, val),) -> getcurrhs(form, id) * val, +, Iterators.zip(constrids, constrvals); init = 0.0)

function Base.:(*)(a::Real, s::S) where {S<:AbstractSolution}
    ids, vals = findnz(a * s.solution.sol)
    cost = _math_op_cost(S, getmodel(s), ids, vals)
    return _math_op_constructor(S, getmodel(s), ids, vals, cost)
end

for op in (:+, :-)
    @eval begin
        function Base.$op(s1::S, s2::S) where {S<:AbstractSolution}
            @assert getmodel(s1) == getmodel(s2)
            ids, vals = findnz(ColunaBase._sol_custom_binarymap($op, s1.solution, s2.solution))
            cost = _math_op_cost(S, getmodel(s1), ids, vals)
            return _math_op_constructor(S, getmodel(s1), ids, vals, cost)
        end
    end
end

# transpose
struct Transposed{S<:AbstractSolution}
    sol::S
end

Base.transpose(s::AbstractSolution) = Transposed(s)

Base.:(*)(s1::Transposed{S}, s2::S) where {S<:AbstractSolution} =
    transpose(s1.sol.solution.sol) * s2.solution.sol

function Base.:(*)(s::Transposed{<:AbstractSolution}, vec::SparseVector)
    # We multiply two sparse vectors that may have different sizes.
    sol_vec = s.sol.solution.sol
    len = Coluna.MAX_NB_ELEMS
    vec1 = sparsevec(findnz(sol_vec)..., len)
    vec2 = sparsevec(findnz(vec)..., len)
    return transpose(vec1) * vec2
end

# *(::M, ::S) has return type `SparseVector` for:
#  - M <: DynamicSparseMatrix
#  - S <: AbstractSolution

# We don't support operation with classic sparse matrix because row and col ids
# must be of the same type. 
# In Coluna, we use VarId to index the cols and 
# ConstrId to index the rows.

Base.:(*)(m::DynamicSparseMatrix, s::AbstractSolution) = m * s.solution.sol
Base.:(*)(m::DynamicSparseArrays.Transposed{<:DynamicSparseMatrix}, s::AbstractSolution) = m * s.solution.sol

LinearAlgebra.norm(s::AbstractSolution) = norm(s.solution.sol)
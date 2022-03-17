# MathProg > Solutions
# Representations of the primal & dual solutions to a MILP formulation

abstract type AbstractSolution end

# Primal Solution
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

# Dual Solution

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

get_var_redcosts(s::DualSolution) = s.var_redcosts

# Redefine methods from ColunaBase to access the formulation, the value, the
# status of a Solution, and other specific information
ColunaBase.getmodel(s::AbstractSolution) = getmodel(s.solution)
ColunaBase.getvalue(s::AbstractSolution) = getvalue(s.solution)
ColunaBase.getbound(s::AbstractSolution) = getbound(s.solution)
ColunaBase.getstatus(s::AbstractSolution) = getstatus(s.solution)
Base.length(s::AbstractSolution) = length(s.solution)
Base.get(s::AbstractSolution, id, default) = Base.get(s.solution, id, default)
Base.getindex(s::AbstractSolution, id) = Base.getindex(s.solution, id)
Base.setindex!(s::AbstractSolution, val, id) = Base.setindex!(s.solution, val, id)

# Iterating over a PrimalSolution or a DualSolution is similar to iterating over
# ColunaBase.Solution
Base.iterate(s::AbstractSolution) = iterate(s.solution)
Base.iterate(s::AbstractSolution, state) = iterate(s.solution, state)

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

function Base.isless(s1::DualSolution, s2::DualSolution)
    getobjsense(getmodel(s1)) == MinSense && return s1.solution.bound < s2.solution.bound
    return s1.solution.bound > s2.solution.bound
end

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

function Base.print(io::IO, form::AbstractFormulation, sol::Solution)
    println(io, "Solution")
    for (id, val) in sol
        println(io, getname(form, id), " = ", val)
    end
    return
end

function Base.show(io::IO, solution::DualSolution{M}) where {M}
    println(io, "Dual solution")
    for (constrid, value) in solution
        println(io, "| ", getname(getmodel(solution), constrid), " = ", value)
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

# Following methods are needed by Benders
# TODO : check if we can remove them during refactoring of Benders
# not performant
Base.haskey(s::AbstractSolution, key) = haskey(s.solution, key)
# we can't filter the constraints, the variables, and the custom data.
function Base.filter(f::Function, s::DualSolution)
    return DualSolution(
        filter(f, s.solution), s.var_redcosts, s.custom_data
    )
end
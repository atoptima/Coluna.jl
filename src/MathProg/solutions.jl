# new structures for solutions

# Constructors for Primal & Dual Solutions
const PrimalSolution{M} = Solution{M, VarId, Float64}
const DualSolution{M} = Solution{M, ConstrId, Float64}

function PrimalSolution(form::M) where {M}
    return Coluna.Containers.Solution{M,VarId,Float64}(form)
end

function PrimalSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64
) where {M<:AbstractFormulation,De,Va}
    return Coluna.Containers.Solution{M,De,Va}(form, decisions, vals, val)
end

function DualSolution(form::M) where {M}
    return Coluna.Containers.Solution{M,ConstrId,Float64}(form)
end

function DualSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64
) where {M<:AbstractFormulation,De,Va}
    return Coluna.Containers.Solution{M,De,Va}(form, decisions, vals, val)
end

function Base.isinteger(sol::Coluna.Containers.Solution)
    for (vc_id, val) in sol
        #if getperenekind(sol.model, vc_id) != Continuous
            !isinteger(val) && return false
        #end
    end
    return true
end

isfractional(sol::Coluna.Containers.Solution) = !Base.isinteger(sol)

function contains(sol::PrimalSolution, f::Function)
    for (varid, val) in sol
        f(varid) && return true
    end
    return false
end

function contains(sol::DualSolution, f::Function)
    for (constrid, val) in sol
        f(constrid) && return true
    end
    return false
end

function Base.print(io::IO, form::AbstractFormulation, sol::Coluna.Containers.Solution)
    println(io, "Solution")
    for (id, val) in sol
        println(io, getname(form, id), " = ", val)
    end
    return
end
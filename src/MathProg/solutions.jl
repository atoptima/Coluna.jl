# new structures for solutions

# Constructors for Primal & Dual Solutions
const PrimalSolution{M} = Solution{M, VarId, Float64}
const DualSolution{M} = Solution{M, ConstrId, Float64}
const PrimalBound{S} = Bound{Primal, S}
const DualBound{S} = Bound{Dual, S}

function PrimalBound(form::AbstractFormulation)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Primal,Se}()
end

function PrimalBound(form::AbstractFormulation, val::Float64)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Primal,Se}(val)
end

function PrimalSolution(form::M) where {M}
    return Coluna.Containers.Solution{M,VarId,Float64}(form)
end

function PrimalSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64
) where {M<:AbstractFormulation,De,Va}
    return Coluna.Containers.Solution{M,De,Va}(form, decisions, vals, val)
end

function DualBound(form::AbstractFormulation)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Dual,Se}()
end

function DualBound(form::AbstractFormulation, val::Float64)
    Se = getobjsense(form)
    return Coluna.Containers.Bound{Dual,Se}(val)
end

function DualSolution(form::M) where {M}
    return Coluna.Containers.Solution{M,ConstrId,Float64}(form)
end

function DualSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64
) where {M<:AbstractFormulation,De,Va}
    return Coluna.Containers.Solution{M,De,Va}(form, decisions, vals, val)
end

valueinminsense(b::PrimalBound{MinSense}) = b.value
valueinminsense(b::DualBound{MinSense}) = b.value
valueinminsense(b::PrimalBound{MaxSense}) = -b.value
valueinminsense(b::DualBound{MaxSense}) = -b.value

function Base.print(io::IO, form::AbstractFormulation, sol::Coluna.Containers.Solution)
    println(io, "Solution")
    for (id, val) in sol
        println(io, getname(form, id), " = ", val)
    end
    return
end
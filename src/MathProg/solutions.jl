# new structures for solutions

# Constructors for Primal & Dual Solutions
const PrimalSolution{M} = Solution{M, VarId, Float64}
const DualSolution{M} = Solution{M, ConstrId, Float64}

function PrimalSolution(form::M) where {M}
    return Solution{M,VarId,Float64}(form)
end

function PrimalSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64, status::SolutionStatus
) where {M<:AbstractFormulation,De,Va}
    return Solution{M,De,Va}(form, decisions, vals, val, status)
end

function DualSolution(form::M) where {M}
    return Solution{M,ConstrId,Float64}(form)
end

function DualSolution(
    form::M, decisions::Vector{De}, vals::Vector{Va}, val::Float64, status::SolutionStatus
) where {M<:AbstractFormulation,De,Va}
    return Solution{M,De,Va}(form, decisions, vals, val, status)
end

function Base.isinteger(sol::Solution)
    for (vc_id, val) in sol
        #if getperenkind(sol.model, vc_id) != Continuous
            !isinteger(val) && return false
        #end
    end
    return true
end

isfractional(sol::Solution) = !Base.isinteger(sol)

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

function concatenate_sols(sola::PrimalSolution{M}, solb::PrimalSolution{M}) where {M}
    length(solb) == 0 && return sola

    ids = Vector{VarId}()
    vals = Vector{Float64}()
    for (varid, value) in sola
        push!(ids, varid)
        push!(vals, value)
    end
    for (varid, value) in solb
        push!(ids, varid)
        push!(vals, value)
    end
    return Solution{M,VarId,Float64}(
        sola.model, ids, vals, getvalue(sola) + getvalue(solb), sola.status
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
        println(io, "| ", getname(solution.model, constrid), " = ", value)
    end
    Printf.@printf(io, "└ value = %.2f \n", getvalue(solution))
end

function Base.show(io::IO, solution::PrimalSolution{M}) where {M}
    println(io, "Primal solution")
    for (varid, value) in solution
        println(io, "| ", getname(solution.model, varid), " = ", value)
    end
    Printf.@printf(io, "└ value = %.2f \n", getvalue(solution))
end

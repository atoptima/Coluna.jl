using BenchmarkTools
using SparseArrays

abstract type AbstractDuty end
struct Original <: AbstractDuty end
struct Pricing <: AbstractDuty end
struct Implicit <: AbstractDuty end
struct Another <: AbstractDuty end
struct LastOne <: AbstractDuty end

struct Variable{T <: AbstractDuty}
    id::Int
    value::Float64
    name::String
    flag::Bool
end

getduty(v::Variable{T}) where {T <: AbstractDuty} = T

function init_structs()
    id = 1
    variables = Variable[]
    for i in 1:10_000_000
        p = rand(0:0.0001:1)
        if p < 0.05
            push!(variables, Variable{Original}(i, rand(0:0.001:10), "var_$i", rand(false:true)))
        elseif 0.05 <= p < 0.09
            push!(variables, Variable{Pricing}(i, rand(0:0.001:10), "var_$i", rand(false:true)))
        elseif 0.09 <= p < 0.1
            push!(variables, Variable{Implicit}(i, rand(0:0.001:10), "var_$i", rand(false:true)))
        elseif 0.1 <= p < 0.14
            push!(variables, Variable{Another}(i, rand(0:0.001:10), "var_$i", rand(false:true)))
        elseif 0.14 <= p < 0.25
            push!(variables, Variable{LastOne}(i, rand(0:0.001:10), "var_$i", rand(false:true)))
        end
    end

    sv = spzeros(Variable, 10_000_000)
    dict = Dict{Int, Variable}()
    for var in variables
        sv[var.id] = var
        dict[var.id] = var
    end
    return sv, dict
end

function benchmarks()
    sv, dict = init_structs()
    f1(var) = (var[2].flag == true)
    f2(var) = (var[2].value <= 2.0)
    f3(var) = (getduty(var[2]) == Another)

    @show length(dict)

    @btime $(d1 = filter(f1, dict))
    @show length(d1)
    @btime $(d2 = filter(f2, dict))
    @show length(d2)
    @btime $(d3 = filter(f3, dict))
    @show length(d3)
    return
end

benchmarks()
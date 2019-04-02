using BenchmarkTools
using SparseArrays

import Base.hash
import Base.isequal


using Coluna

abstract type AbstractDuty end
struct Original <: AbstractDuty end
struct Pricing <: AbstractDuty end
struct Implicit <: AbstractDuty end
struct Another <: AbstractDuty end
struct LastOne <: AbstractDuty end
struct Empty <: AbstractDuty end

mutable struct Variable{T <: AbstractDuty}
    id::Int
    value::Float64
    name::String
    flag::Bool
end

mutable struct VarInfo{T <: AbstractDuty}
    value::Float64
    lb::Float64
    ub::Float64 
    flag::Bool
    status::Int # 0 -> active
end
VarInfo(v::Variable) = VarInfo(v.value, -Inf, Inf, v.flag, 0)
VarInfo(v::Variable{T}, status::Int) = VarInfo{T}(v.value, -Inf, Inf, v.flag, status)
getduty(::VarInfo{T}) = T


struct Id
    uid::Int
    info::VarInfo
end
Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)

struct Manager{T}
    members::Dict{Id,T}
end

zero(::Variable) = Variable{Empty}(g)
getduty(v::Variable{T}) where {T <: AbstractDuty} = T

function init_structs()
    id = 1
    variables = Variable[]
    var_infos = VarInfo[]
    for i in 1:10_000_000
        p = rand(0:0.0001:1)
        if p < 0.05
            v = Variable{Original}(i, rand(0:0.001:10), "var_$i", rand(false:true))
            push!(variables, v)
            push!(var_infos, VarInfo(v))
        elseif 0.05 <= p < 0.09
            v = Variable{Pricing}(i, rand(0:0.001:10), "var_$i", rand(false:true))
            push!(variables, v)
            push!(var_infos, VarInfo(v))
        elseif 0.09 <= p < 0.1
            v = Variable{Implicit}(i, rand(0:0.001:10), "var_$i", rand(false:true))
            push!(variables, v)
            push!(var_infos, VarInfo(v))
        elseif 0.1 <= p < 0.14
            v = Variable{Another}(i, rand(0:0.001:10), "var_$i", rand(false:true))
            push!(variables, v)
            push!(var_infos, VarInfo(v))
        elseif 0.14 <= p < 0.25
            v = Variable{LastOne}(i, rand(0:0.001:10), "var_$i", rand(false:true))
            push!(variables, v)
            push!(var_infos, VarInfo(v))
        end
    end

    sv = spzeros(Variable, 10_000_000)
    int_dict = Dict{Int, Variable}()
    id_dict = Dict{Id, Variable}()
    id_to_float_dict = Dict{Id, Float64}()
    for idx in 1:length(variables)
        var = variables[idx]
        var_info = var_infos[idx]
        sv[var.id] = var
        int_dict[var.id] = var
        id_dict[Id(var.id,var_info)] = var
        id_to_float_dict[Id(var.id,var_info)] = rand()
    end
    return sv, int_dict, id_dict, id_to_float_dict
end

function createfilter(sv, f)
    return Coluna.Filter(f, sv)
end

function benchmarks()
    sv, int_dict, id_dict, id_to_float_dict = init_structs()
    int_f1(var) = (var[2].flag == true)
    int_f2(var) = (var[2].value <= 2.0)
    int_f3(var) = (getduty(var[2]) == Another)
    int_f4(var) = true

    id_f1(var) = (var[1].flag == true)
    id_f2(var) = (var[1].value <= 2.0)
    id_f3(var) = (getduty(var[1]) == Another)
    id_f4(var) = true


    @show length(int_dict)
    @show length(id_dict)

    println("-----> With int as keys")
    @btime $(d1 = filter(int_f1, int_dict))
    @show length(d1)
    @btime $(d2 = filter(int_f2, int_dict))
    @show length(d2)
    @btime $(d3 = filter(int_f3, int_dict))
    @show length(d3)
    @btime $(d4 = filter(int_f4, int_dict))
    @show length(d4)

    println("-----> With Id as keys and values as Variable")
    @btime $(d1 = filter(id_f1, id_dict))
    @show length(d1)
    @btime $(d2 = filter(id_f2, id_dict))
    @show length(d2)
    @btime $(d3 = filter(id_f3, id_dict))
    @show length(d3)
    @btime $(d4 = filter(id_f4, id_dict))
    @show length(d4)

    println("-----> With Id as keys and values as Float64")
    @btime $(d1 = filter(id_f1, id_to_float_dict))
    @show length(d1)
    @btime $(d2 = filter(id_f2, id_to_float_dict))
    @show length(d2)
    @btime $(d3 = filter(id_f3, id_to_float_dict))
    @show length(d3)
    @btime $(d4 = filter(id_f4, id_to_float_dict))
    @show length(d4)


    #@btime $(sv )
    

    #println("------")
    #@btime $(e1 = sv[f1.(sv)])
    #@show typeof(e1)
    return
end

function init_structs2()
    ids = Int[]
    values = Float64[]
    for i in 1:10_000_000
        p = rand(0:0.0001:1)
        if p < 0.5
            push!(ids, i)
            push!(values, rand(0:0.001:10))
        end
    end

    sv = spzeros(Float64, 10_000_000)
    dict = Dict{Int, Float64}()
    for (i, val) in enumerate(values)
        sv[ids[i]] = values[i]
        dict[ids[i]] = values[i]
    end
    return sv, dict
end

function multiplication()
    sv1, dict1 = init_structs2()
    sv2, dict2 = init_structs2()

    @btime $(dict3 = merge(+, dict1, dict2))
    @btime $(val1 = mapreduce(e -> e[2], +, dict3))
    @show val1
    @btime $(sv3 = sv1 .+ sv2)
    @btime $(val2 = sum(sv3))
    @show val2
end

# multiplication()
benchmarks()

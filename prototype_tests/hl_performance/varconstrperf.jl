import Random
using BenchmarkTools

abstract type TestObj end

mutable struct NonParametric <: TestObj
    id1::Int    
    ratio::Float64
    id2::Int
end

mutable struct LightParametric{T} <: TestObj
    id1::Int        
    ratio::Float64
    id2::Int
end

sayhello(::LightParametric{String}) = println("holy")
sayhello(::LightParametric{<:Number}) = println("moly")
alice = LightParametric{String}(1, rand(Float64), 2)
bob = LightParametric{Integer}(1, rand(Float64), 2)
sayhello(alice)
sayhello(bob)

mutable struct Parametric{T} <: TestObj
    id1::T    
    ratio::Float64
    id2::T
end

import Base.+
(+)(a::TestObj, b::TestObj) = a.ratio + b.ratio
(+)(f::Float64, a::TestObj) = f + a.ratio

function sum(vec)
    s = 0.0
    for i in 1:length(vec)
        s += vec[i]
    end
    return s
end

function non_parametric()    
    vec = Vector{NonParametric}()
    for i in 1:1000000
        push!(vec, NonParametric(i, rand(Float64), 2*i))
    end
    return vec    
end

function light_parametric()
    vec = Vector{LightParametric}()
    for i in 1:1000000
        push!(vec, LightParametric{AbstractString}(i, rand(Float64), 2*i))
    end
    return vec
end

function parametric()
    vec = Vector{Parametric}()
    for i in 1:1000000
        push!(vec, Parametric(i, rand(Float64), 2*i))
    end
    return vec
end

function non_concrete_vect()
    vec = Vector{TestObj}()
    for i in 1:1000000
        push!(vec, NonParametric(i, rand(Float64), 2*i))
    end
    return vec
end

println("TEST non parametric")
Random.seed!(777)
vec = non_parametric()
@btime sum(vec)

println("TEST light parametric")
Random.seed!(777)
vec = light_parametric()
@btime sum(vec)

println("TEST parametric")
Random.seed!(777)
vec = parametric()
@btime sum(vec)

println("TEST non concrete vect ")
Random.seed!(777)
vec = non_concrete_vect()
@btime sum(vec)

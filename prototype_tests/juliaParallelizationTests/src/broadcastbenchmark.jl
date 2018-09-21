# import Random
using BenchmarkTools

mutable struct Column
    red_cost::Float64
    solution::Vector{Int}
end

mutable struct Column_bits
    red_cost::Float64
    letter::Char
    id::Int
end

function devec_primitive(red_cost::Vector{Float64}, a::Float64)
    for i in 1:length(red_cost)
        red_cost[i] *= a
    end
end

function vec_primitive(red_cost::Vector{Float64}, a::Float64)
    red_cost .= a .* red_cost
end

function devec_complex(cols::Union{Vector{Column}, Vector{Column_bits}}, a::Float64)
    for i in 1:length(cols)
        cols[i].red_cost *= a
    end
end

function multiply_red_cost(c::Union{Column, Column_bits}, a::Float64)
    c.red_cost *= a
end
function vec_complex(cols::Union{Vector{Column}, Vector{Column_bits}}, a::Float64)
    multiply_red_cost.(cols, a)
end


red_cost = rand(10000)
print("devectorized for primitive types: ")
@btime devec_primitive(red_cost, 2.0)
print("vectorized for primitive types: ")
@btime vec_primitive(red_cost, 2.0)

cols = [Column(red_cost[i], rand(Int, 100)) for i in 1:length(red_cost)]
print("devectorized for complex types: ")
@btime devec_complex(cols, 2.0)
print("vectorized for complex types: ")
@btime vec_complex(cols, 2.0)

cols = [Column(red_cost[i], rand(Int, 10)) for i in 1:length(red_cost)]
print("devectorized for complex types: ")
@btime devec_complex(cols, 2.0)
print("vectorized for complex types: ")
@btime vec_complex(cols, 2.0)

cols = [Column_bits(red_cost[i], 'a', i) for i in 1:length(red_cost)]
print("devectorized for complex bits types: ")
@btime devec_complex(cols, 2.0)
print("vectorized for complex bits types: ")
@btime vec_complex(cols, 2.0)



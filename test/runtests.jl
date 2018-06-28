using Coluna
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

# write your own tests here
@test 1 == 2

workspace()
IntOrString = Union{Int,AbstractString}
type Yolo
    a::IntOrString
end

x = Yolo(1)
    
typeof(x.a)

workspace()
abstract type MyInteger end
type MyInt <: MyInteger
    inner::Int
end

import Base: +
+(a::MyInt, b::MyInt) = MyInt(a.inner + b.inner)

function test2()   
   a = Vector{MyInteger}()
   # a = Vector{Union{BigFloat, Float16, Float32, Float64}}()
   
   for i in 1:3000000
       push!(a, MyInt(i))
   end 
   
   return sum(a)
end

@time test2()


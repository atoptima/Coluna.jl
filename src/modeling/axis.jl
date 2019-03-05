import Base.length
import Base.iterate

struct DecompositionAxis{T}
  vector::Vector{T}
  identical::Bool
end

name(axis::DecompositionAxis) =  axis.name
iterate(axis::DecompositionAxis) = iterate(axis.vector)
iterate(axis::DecompositionAxis) = iterate(axis.vector, state)
length(axis::DecompositionAxis) = length(axis.vector)
identical(axis::DecompositionAxis) = axis.identical

struct DecompositionAxisArray{K, T}
  data::Dict{K, DecompositionAxis{T}}
end

macro axis(args...)
  definition = args[1]
  values = args[2]
  identical = false
  if length(args) == 3 && args[3] == :Identical
    identical = true
  end
  exp = :()
  name = definition
  if typeof(definition) != Symbol
    exp = :(commandline())
    name = definition.args[1]
    for loop in reverse(definition.args[2:end])
      (loop.args[1] != :in) && error("Should be a loop.")
      exp = quote 
        for $(loop.args[2]) = $(loop.args[3])
          $exp
        end 
      end
    end
  end
  @show name
  @show values
  @show identical
  @show exp
end
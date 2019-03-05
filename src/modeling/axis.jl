import Base.length
import Base.iterate
import Base.getindex

struct DecompositionAxis{T}
  vector::Vector{T}
  identical::Bool
end

DecompositionAxis(r::UnitRange, i::Bool) = DecompositionAxis(collect(r), i)

name(axis::DecompositionAxis) =  axis.name
iterate(axis::DecompositionAxis) = iterate(axis.vector)
iterate(axis::DecompositionAxis, state) = iterate(axis.vector, state)
length(axis::DecompositionAxis) = length(axis.vector)
identical(axis::DecompositionAxis) = axis.identical

macro axis(args...)
  definition = args[1]
  values = args[2]
  identical = _axis_identical_(args)
  exp = :()
  name = definition
  if typeof(definition) != Symbol
    exp = _build_axis_array_(definition, values, identical)
  else
    exp = :($name = Coluna.DecompositionAxis($values, $identical))
  end
  return esc(exp)
end

function _axis_identical_(args)
  if length(args) == 3 && args[3] == :Identical
    return true
  end
  return false
end

function _axis_array_indices_(loops)
  indices = "tuple(" * string(loops[1].args[2])
  for loop in loops[2:end]
    indices *=  ", " * string(loop.args[2])
  end
  return Meta.parse(indices * ")")
end

function _build_axis_array_(definition, values, identical)
  nb_loops = length(definition.args) - 1
  start =:(local axes_dict = Dict{NTuple{$nb_loops, Any}, Coluna.DecompositionAxis{eltype($values)}}())
  @show start
  indices = _axis_array_indices_(definition.args[2:end])
  exp_loop = :(get!(axes_dict, $indices, Coluna.DecompositionAxis($values, $identical)))
  name = definition.args[1]
  for loop in reverse(definition.args[2:end])
    (loop.args[1] != :in) && error("Should be a loop.")
    exp_loop = quote 
      for $(loop.args[2]) = $(loop.args[3])
        $exp_loop
      end 
    end
  end
  exp = quote 
    $start
    $exp_loop
    $name = JuMP.Containers.SparseAxisArray(axes_dict)
  end
end
import Base.length
import Base.iterate
import Base.getindex

struct DecompositionAxis{T, V <: AbstractArray{T}}
  name::Symbol # Name of the axis (as declared in the macro)
  id::Tuple    # id of the axis if it has been stored in an SparseAxisArray
  container::V
  identical::Bool
  function DecompositionAxis(n::Symbol, id::Tuple, c::V, i::Bool) where {T, V <: AbstractArray{T}}
    return new{T, V}(n, id, c, i)
  end
end

name(axis::DecompositionAxis) =  axis.name
id(axis::DecompositionAxis) = axis.id
iterate(axis::DecompositionAxis) = iterate(axis.container)
iterate(axis::DecompositionAxis, state) = iterate(axis.container, state)
length(axis::DecompositionAxis) = length(axis.container)
identical(axis::DecompositionAxis) = axis.identical

macro axis(args...)
  definition = args[1]
  container = args[2]
  identical = _axis_identical_(args)
  exp = :()
  if typeof(definition) != Symbol
    exp = _build_axis_array_(definition, container, identical)
  else
    name = definition
    exp = :($name = $(_axis_(name, container, identical)))
  end
  return esc(exp)
end

function _axis_(name, id, container, i::Bool)
  sym_name = Meta.parse("Symbol(\"" * string(name) * "\")")
  return :(Coluna.DecompositionAxis($sym_name, $id, $container, $i))
end
_axis_(name, container, i::Bool) = _axis_(name, :(tuple()), container, i)

function _axis_identical_(args)
  if length(args) == 3
    if args[3] == :Identical
      return true
    else
      error("Third argument must be Identical but it is optional.")
    end
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

function _build_axis_array_(definition, container, identical)
  nb_loops = length(definition.args) - 1
  start =:(local axes_dict = Dict{NTuple{$nb_loops, Any}, Coluna.DecompositionAxis{eltype($container)}}())
  name = definition.args[1]
  indices = _axis_array_indices_(definition.args[2:end])
  exp_loop = :(get!(axes_dict, $indices, $(_axis_(name, indices, container, identical))))
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
  return exp
end
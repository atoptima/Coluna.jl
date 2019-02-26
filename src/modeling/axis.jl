struct Axis{T <: Integer}
  set::UnitRange{T}
  symmetry::Bool
end

macro axis(args...)
  nbargs = length(args)
  if nbargs < 2 || nbargs > 3
    error("Incorrect number of arguments.")
  end
  axisname = args[1]
  range = args[2]
  symmetry = false
  if nbargs == 3
    kwarg = string(args[3])
    m = match(r"^symmetry ?= ?(true|false)$", kwarg)
    if m != nothing
      if m[1] == "true"
        symmetry = true
      end
    else
      error("Third argument has incorrect syntax $kwarg")
    end
  end
  return esc(:($axisname = Coluna.Axis($range, $symmetry)))
end
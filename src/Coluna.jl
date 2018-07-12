module Coluna

import Parameters.@with_kw
import HighLevelTypes.@hl
import HighLevelTypes.tuplejoin
import MathOptInterface
import MathOptInterface.Utilities
import DataStructures

const Float = Float64
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const DS = DataStructures

@MOIU.model ModelForCachingOptimizer (ZeroOne, Integer) (EqualTo, GreaterThan, LessThan, Interval) () () (SingleVariable,) (ScalarAffineFunction,) () ()


include("parameters.jl")
include("utils.jl")
include("varconstr.jl")
include("variables.jl")
include("constraints.jl")
include("solution.jl")
include("mastercolumn.jl")
include("problem.jl")
include("nodealgs/algsetupnode.jl")
include("nodealgs/algpreprocessnode.jl")
include("nodealgs/algevalnode.jl")
include("nodealgs/algprimalheurinnode.jl")
include("nodealgs/alggeneratechildrennodes.jl")
include("node.jl")
include("model.jl")


end # module

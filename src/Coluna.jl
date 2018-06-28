module Coluna

using HighLevelTypes.@hl
using HighLevelTypes.tuplejoin
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
include("constraints.jl")
include("variables.jl")
include("solution.jl")
include("mastercolumn.jl")
include("problem.jl")
include("nodealgs/problemsetup.jl")
include("node.jl")
include("model.jl")


end # module

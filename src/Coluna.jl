module Coluna

import Parameters.@with_kw
import HighLevelTypes.@hl
import HighLevelTypes.tuplejoin
import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
# import Cbc # we should not need to import this here
import GLPK # for debugging only TODO: remove

using Base.CoreLogging

global const Float = Float64
global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const DS = DataStructures

@MOIU.model ModelForCachingOptimizer (ZeroOne, Integer) (EqualTo, GreaterThan, LessThan, Interval) () () (SingleVariable,) (ScalarAffineFunction,) () () # We should not need to import this here


include("parameters.jl")
include("utils.jl")
include("varconstr.jl")
include("variables.jl")
include("constraints.jl")
include("solution.jl")
include("mastercolumn.jl")
include("problem.jl")
include("node.jl")
include("nodealgs/algsetupnode.jl")
include("nodealgs/algpreprocessnode.jl")
include("nodealgs/algevalnode.jl")
include("nodealgs/algprimalheurinnode.jl")
include("nodealgs/alggeneratechildrennodes.jl")
include("model.jl")


##### Wrapper functions
include("MOIWrapper.jl")

end # module

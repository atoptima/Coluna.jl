module Coluna

import Parameters.@with_kw
import HighLevelTypes.@hl
import HighLevelTypes.tuplejoin
import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
import Cbc # we should not need to import this here

const Float = Float64
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const DS = DataStructures

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
# include("wrapperfunctions/MOIWrapper.jl")

end # module

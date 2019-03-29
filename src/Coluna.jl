module Coluna

import Parameters.@with_kw
import HighLevelTypes.@hl
import HighLevelTypes.tuplejoin
import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
import GLPK
import JuMP
import BlockDecomposition

using Base.CoreLogging
using SparseArrays
import TimerOutputs
import TimerOutputs.@timeit

global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const DS = DataStructures
global const BD = BlockDecomposition
global __initial_solve_time = 0.0
global const MAX_SV_ENTRIES = 10_000_000

# Base functions for which we define more methods in Coluna
import Base.isempty

# We should not need to import this here
@MOIU.model(ModelForCachingOptimizer,
        (MOI.ZeroOne, MOI.Integer),
        (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan, MOI.Interval),
        (),
        (),
        (MOI.SingleVariable,),
        (MOI.ScalarAffineFunction,),
        (),
        ())

# include("/Users/vitornesello/.julia/dev/SimpleDebugger/src/SimpleDebugger.jl")

include("types.jl")
include("parameters.jl")
#include("utils.jl")
include("varconstr.jl")
include("constraint.jl")
include("variable.jl")
include("filter.jl")
include("manager.jl")
include("membership.jl")
include("solution.jl")
include("formulation.jl")
include("reformulation.jl")
#include("constraintduties.jl")
#include("variableduties.jl")

#include("solution.jl")
#include("mastersm.column.jl")
#include("problem.jl")

include("model.jl")
include("decomposition.jl")
include("interfaceMoi.jl")

##### Node and algorithms
include("node.jl")
include("bbtree.jl")
#include("nodealgs/solandbounds.jl")
#include("nodealgs/algsetupnode.jl")
#include("nodealgs/algpreprocessnode.jl")
#include("nodealgs/algevalnode.jl")
#include("nodealgs/algprimalheurinnode.jl")
#include("nodealgs/alggeneratechildrennodes.jl")
#include("nodealgs/algtoevalnodebylp.jl")

##### Algorithms draft
include("algorithms/colgen.jl")

##### Wrapper functions
include("MOIWrapper.jl")
#include("decomposition.jl")


end # module

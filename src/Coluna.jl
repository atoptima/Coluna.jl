module Coluna

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
import Base.hash
import Base.isequal
import Base.filter
import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex
import Base.getkey
import Base.haskey
import Base.copy

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
include("counters.jl")
include("constraint.jl")
include("variable.jl")
include("vcids.jl")
include("manager.jl")
include("membership.jl")
include("solution.jl")
include("formulation.jl")
include("reformulation.jl")
#include("constraintduties.jl")
#include("variableduties.jl")

#include("mastersm.column.jl")
#include("problem.jl")

include("problem.jl")
include("decomposition.jl")
include("interfaceMoi.jl")

##### Search tree
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
include("solandbounds.jl")
include("colgen.jl")

##### Wrapper functions
include("MOIWrapper.jl")
#include("decomposition.jl")

include("globals.jl") # Structure that holds values useful in all the procedure

global const _params_ = Params()
global const _globals_ = GlobalValues()

end # module

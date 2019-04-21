module Coluna

import HighLevelTypes.@hl
import HighLevelTypes.tuplejoin
import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
import GLPK
import JuMP
import BlockDecomposition
import Distributed

using Base.CoreLogging
using SparseArrays
using Printf
import TimerOutputs
import TimerOutputs.@timeit

global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const DS = DataStructures
global const BD = BlockDecomposition

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
import Base.delete!
import Base.setindex!
import Base.haskey
import Base.copy
import Base.promote_rule
import Base.convert

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

include("types.jl")
include("parameters.jl")
include("counters.jl")
include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("manager.jl")
include("filters.jl")
include("solsandbounds.jl")
include("incumbents.jl")
include("formulation.jl")
include("clone.jl")
include("reformulation.jl")
include("problem.jl")
include("decomposition.jl")
include("MOIinterface.jl")

###### Solvers & Strategies
include("solvers/solver.jl")
include("strategies/strategy.jl")
include("solvers/colgen.jl")
include("solvers/masteripheur.jl")
# here include solvers
include("solvers/interfaces.jl")
include("strategies/mockstrategy.jl")
# here include strategies

##### Search tree
include("node.jl")
include("bbtree.jl")

##### Wrapper functions
include("MOIwrapper.jl")

include("globals.jl") # Structure that holds values useful in all the procedure

global const _params_ = Params()
global const _globals_ = GlobalValues()

end # module

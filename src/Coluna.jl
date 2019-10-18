module Coluna

import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
import JuMP
import BlockDecomposition
import Distributed
import TimerOutputs

using Logging
using SparseArrays
using Printf

global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const DS = DataStructures
global const BD = BlockDecomposition
global const TO = TimerOutputs

# Base functions for which we define more methods in Coluna
import Base: isempty, hash, isequal, length, iterate, getindex, lastindex,
    getkey, delete!, setindex!, haskey, copy, promote_rule, convert, isinteger,
    push!, filter

include("types.jl")
include("algorithms/algorithm.jl")
include("strategies/strategy.jl")

include("parameters.jl")
include("counters.jl")

include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("varconstr.jl")

include("containers/elements.jl")
include("containers/members.jl")

include("manager.jl")
include("filters.jl")
include("solsandbounds.jl")
include("optimizationresults.jl")
include("incumbents.jl")
include("buffer.jl")
include("formulation.jl")
include("optimizerwrappers.jl")
include("clone.jl")
include("reformulation.jl")
include("projection.jl")
include("problem.jl")
include("node.jl")
include("decomposition.jl")
include("MOIinterface.jl")

# Concrete algorithms & Strategies :

# Here include algorithms
include("algorithms/colgen.jl")
include("algorithms/benders.jl")
include("algorithms/masteripheur.jl")
include("algorithms/masterlp.jl")
include("algorithms/generatechildrennodes.jl") # to remove
include("algorithms/reformulationsolver.jl")
include("algorithms/preprocessing.jl")

# Here include conquer strategies
include("strategies/conquer/simplebnp.jl")
include("strategies/conquer/simplebenders.jl")

# Here include branching algorithms
include("branching/abstractbranching.jl")
include("branching/varbranching.jl")
include("branching/branchinggroup.jl")
include("branching/branchingstrategy.jl")

# Here include divide strategies
include("strategies/divide/simplebranching.jl") # to remove

# Here include explore strategies
include("strategies/explore/simplestrategies.jl")

# Wrapper functions
include("MOIwrapper.jl")

include("globals.jl") # Structure that holds values useful in all the procedure

global const _params_ = Params()
global const _globals_ = GlobalValues()

end # module

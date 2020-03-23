module ColunaBase

using DynamicSparseArrays

import Base
import Primes
import Printf

# interface.jl
export AbstractModel, AbstractProblem, AbstractSense, AbstractMinSense, AbstractMaxSense,
    AbstractSpace, AbstractPrimalSpace, AbstractDualSpace, AbstractAlgorithm, AbstractInput, 
    AbstractOutput, run!           

# nestedenum.jl
export NestedEnum, @nestedenum, @exported_nestedenum

# solsandbounds.jl
export Bound, Solution, getvalue, isbetter, diff, gap, printbounds, getsol

# members.jl
export MembersMatrix

include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")
include("members.jl")

end
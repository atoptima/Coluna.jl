module Containers

using DynamicSparseArrays

import ..Coluna

import Base
import Primes
import Printf

# interface.jl
export AbstractModel, AbstractProblem             

# nestedenum.jl
export NestedEnum, @nestedenum, @exported_nestedenum

# solsandbounds.jl
export Bound, Solution,
       getvalue, isbetter, diff, gap, printbounds, getbound, getsol, setvalue!

# members.jl
export MembersMatrix

include("nestedenum.jl")
include("solsandbounds.jl")
include("members.jl")

end
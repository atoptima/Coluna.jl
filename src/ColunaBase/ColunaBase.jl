module ColunaBase

using DynamicSparseArrays

import Base
import Printf

# interface.jl
export AbstractModel, AbstractProblem, AbstractSense, AbstractMinSense, AbstractMaxSense,
    AbstractSpace, AbstractPrimalSpace, AbstractDualSpace

# nestedenum.jl
export NestedEnum, @nestedenum, @exported_nestedenum

# solsandbounds.jl
export Bound, Solution, getvalue, isbetter, diff, gap, printbounds, getsol, remove_until_last_point

include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")

end

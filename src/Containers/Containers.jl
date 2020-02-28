module Containers

using DynamicSparseArrays

import ..Coluna

import DynamicSparseArrays
import Primes
import Printf
import Base: <=, setindex!, get, getindex, haskey, keys, values, iterate, 
             length, lastindex, filter, show, keys, copy, isapprox

# interface.jl
export AbstractModel, AbstractProblem             

# nestedenum.jl
export NestedEnum, @nestedenum, @exported_nestedenum

# solsandbounds.jl
export Bound, Solution,
       getvalue, isbetter, diff, gap, printbounds, getbound, getsol, setvalue!

export MembersMatrix

# To be deleted :
export ElemDict,
       MembersVector

export getelements, getelement, rows, cols, columns, getrecords

include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")

# Following files will be deleted
include("elements.jl")
include("members.jl")

end
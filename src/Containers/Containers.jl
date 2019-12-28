module Containers

import ..Coluna

import DataStructures
import Primes
import Printf
import Base: <=, setindex!, get, getindex, haskey, keys, values, iterate, 
             length, lastindex, filter, show, keys, copy

export NestedEnum, @nestedenum, @exported_nestedenum,
       ElemDict,
       MembersVector, MembersMatrix

export getelements, getelement, rows, cols, columns, getrecords

include("nestedenum.jl")
include("solsandbounds.jl")

# Following files will be deleted
include("elements.jl")
include("members.jl")

end
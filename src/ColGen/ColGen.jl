"API and high-level implementation of the column generation algorithm in Julia."
module ColGen

using ..MustImplement

abstract type AbstractColGenContext end 

include("phases.jl")
include("pricing.jl")
include("interface.jl")

end
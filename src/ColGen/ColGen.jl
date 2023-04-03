"API and high-level implementation of the column generation algorithm in Julia."
module ColGen

include("../MustImplement/MustImplement.jl")
using .MustImplement

abstract type AbstractColGenContext end 

include("phases.jl")
include("pricing.jl")
include("interface.jl")

end
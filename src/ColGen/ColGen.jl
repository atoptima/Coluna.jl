"API and high-level implementation of the column generation algorithm in Julia."
module ColGen

using ..MustImplement

include("phases.jl")
include("pricing_strategy.jl")

include("interface.jl")

end
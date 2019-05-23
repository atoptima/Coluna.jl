"""
    NoOptimizer <: AbstractOptimizer

Wrapper to indicate that no optimizer is assigned to a `Formulation`
"""
struct NoOptimizer <: AbstractOptimizer end

"""
    UserOptimizer <: AbstractOptimizer

Wrapper that is used when the `optimize!(f::Formulation)` function should call an user-defined callback.
"""
mutable struct UserOptimizer <: AbstractOptimizer
    optimize_function::Function
end

"""
    MoiOptimizer <: AbstractOptimizer

Wrapper that is used when the optimizer of a formulation 
is an `MOI.AbstractOptimizer`, thus inheriting MOI functionalities.
"""
struct MoiOptimizer <: AbstractOptimizer
    inner::MOI.AbstractOptimizer
end

# Fallbacks
optimize!(::S) where {S<:AbstractOptimizer} = error(
    string("Function `optimize!` is not defined for object of type ", S)
)

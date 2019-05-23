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

function create_optimizer(optimize_function::Function)
    return UserOptimizer(optimize_function)
end

"""
    MoiOptimizer <: AbstractOptimizer

Wrapper that is used when the optimizer of a formulation 
is an `MOI.AbstractOptimizer`, thus inheriting MOI functionalities.
"""
struct MoiOptimizer <: AbstractOptimizer
    inner::MOI.AbstractOptimizer
end

getinner(optimizer::MoiOptimizer) = optimizer.inner

function create_optimizer(factory::JuMP.OptimizerFactory,
                          sense::Type{<:AbstractObjSense})
    moi_optimizer = factory()
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(moi_optimizer, MoiObjective(),f)
    optimizer = MoiOptimizer(moi_optimizer)
    set_obj_sense(optimizer, sense)
    return optimizer
end


# Fallbacks
optimize!(::S) where {S<:AbstractOptimizer} = error(
    string("Function `optimize!` is not defined for object of type ", S)
)

create_optimizer(::S) where {S<:AbstractOptimizer} = error(
    string("Function `create_optimizer` is not defined for object of type ", S)
)
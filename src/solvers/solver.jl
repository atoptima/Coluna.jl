abstract type AbstractSolver end
abstract type AbstractSolverRecord end

function setup(T::Type{<:AbstractSolver}, f, n)
    error("setup method not implemented for $T.")
end

function run(T::Type{<:AbstractSolver}, f, n, p)
    error("run method not implemented for $T.")
end

function record_output(T::Type{<:AbstractSolver}, f, n)
    error("record_output not implemented for $T.")
end

# Start node
struct StartNode <: AbstractSolver end
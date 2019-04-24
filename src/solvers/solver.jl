abstract type AbstractSolver end
abstract type AbstractSolverRecord end

# In ordert o correctly implement a solver,
# one should implement these three functions.
# To be documented.
function setup end
function run end
function record_output end

# Fallbaccks
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

function apply(S::Type{<:AbstractSolver}, f, n, r, p)
    interface(getsolver(r), S, f, n)
    setsolver!(r, S)
    return run(S, f, n, p)
end

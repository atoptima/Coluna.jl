"""
    AbstractSolver

A solver is an 'text-book' algorithm applied to a formulation in a node.
"""
abstract type AbstractSolver end

"""
    AbstractSolverRecord

Stores data after the end of a solver execution.
These data can be used to initialize another execution of the same solver or in 
setting the transition to another solver.
"""
abstract type AbstractSolverRecord end

"""
    prepare!(SolverType, formulation, node, strategy_record, parameters)

Prepares the `formulation` in the `node` to be optimized by solver `SolverType`.
"""
function prepare! end

"""
    run!(SolverType, formulation, node, strategy_record, parameters)

Runs the solver `SolverType` on the `formulation` in a `node` with `parameters`.
"""
function run! end


# Fallbacks
function prepare!(T::Type{<:AbstractSolver}, formulation, node, strategy_rec, parameters)
    error("prepare! method not implemented for solver $T.")
end

function run!(T::Type{<:AbstractSolver}, formulation, node, strategy_rec, parameters)
    error("run! method not implemented for solver $T.")
end

"""
    apply!(SolverType, formulation, node, strategy_record, parameters)

Applies the solver `SolverType` on the `formulation` in a `node` with 
`parameters`.
"""
function apply!(S::Type{<:AbstractSolver}, form, node, strategy_rec, 
                params)
    setsolver!(strategy_rec, S)
    TO.@timeit to string(S) begin
        TO.@timeit to "prepare" begin
            prepare!(S, form, node, strategy_rec, params)
        end
        TO.@timeit to "run" begin
            record = run!(S, form, node, strategy_rec, params)
        end
    end
    set_solver_record!(node, S, record)
    return record
end

"""
    StartNode

Fake solver that indicates the start of the node treatment.
"""
struct StartNode <: AbstractSolver end

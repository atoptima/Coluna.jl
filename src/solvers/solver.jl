"""
    AbstractSolver

A solver is an algorithm applied to a formulation in a node.
"""
abstract type AbstractSolver end

"""
    AbstractSolverData

Store data of a solver. The object exists only when the solver is running.
"""
abstract type AbstractSolverData  end

"""
    AbstractSolverOutput

Store data that we want to keep after the end of a solver execution.
"""
abstract type AbstractSolverOutput end

"""
    setup!(SolverType, formulation, node)

Prepare the `formulation` in the `node` to be optimized by solver `SolverType`.
This method should return the `AbstractSolverData` structure that corresponds
to the solver `SolverType`. 
"""
function setup! end

"""
    run!(SolverType, solverdata, formulation, node, parameters)

Run the solver `SolverType` on the `formulation` in a `node` with `parameters`.
"""
function run! end

"""
    output(SolverType, solverdata, formulation, node)

Return the `AbstractSolverOutput` structure that corresponds to the solver 
`SolverType`. This method is executed after `run!`.
"""
function output end

# Fallbacks
function setup!(T::Type{<:AbstractSolver}, formulation, node)
    @error "setup! method not implemented for $T."
end

function run!(T::Type{<:AbstractSolver}, solverdata, formulation, node, parameters)
    @error "run! method not implemented for $T."
end

function output(T::Type{<:AbstractSolver}, solverdata, formulation, node)
    @error "output not implemented for $T."
end

"""
    apply!(SolverType, formulation, node, strategyrecord, parameters)

Apply the solver `SolverType` on the `formulation` in a `node` with 
`parameters`.

"""
function apply!(S::Type{<:AbstractSolver}, formulation, node, strategyrecord, 
                parameters)
    interface!(getsolver(strategyrecord), S, formulation, node)
    setsolver!(strategyrecord, S)
    solver_data = setup!(S, formulation, node)
    run!(S, solver_data, formulation, node, parameters)
    return output(S, solver_data, formulation, node)
end

"""
    interface!(SolverTypeSrc, SolverTypeDest, formulation, node)

Given a `formulation` in a `node` optimized using solver `SolverTypeSrc`, 
this method should prepare the `formulation` in the `node` to be solved using 
solver `SolverTypeDest`.
Defining this method allows the user to apply solver `SolverTypeDest` after the
execution of solver `SolverTypeSrc`.
"""
function interface! end


struct StartNode <: AbstractSolver end
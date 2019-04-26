"""
    AbstractSolver

A solver is an algorithm applied to a formulation in a node.
"""
abstract type AbstractSolver end

"""
    AbstractSolverData

Stores data of a solver. The object exists only when the solver is running.
"""
abstract type AbstractSolverData  end

"""
    AbstractSolverRecord

Stores data that we want to keep after the end of a solver execution.
These data can be used to initialize another execution of the solver.
"""
abstract type AbstractSolverRecord end

"""
    setup!(SolverType, formulation, node)

Prepares the `formulation` in the `node` to be optimized by solver `SolverType`.
This method should return the `AbstractSolverData` structure that corresponds
to the solver `SolverType`. 
"""
function setup! end

"""
    run!(SolverType, solverdata, formulation, node, parameters)

Runs the solver `SolverType` on the `formulation` in a `node` with `parameters`.
Return the  `AbstractSolverRecord` structure that corresponds to the solver 
`SolverType`
"""
function run! end

"""
    setdown!(SolverType, solverrecord, formulation, node)

Updates the `formulation` and the `node` after the execution of the solver
`SolverType`.
This method is executed after `run!`.
"""
function setdown! end

# Fallbacks
function setup!(T::Type{<:AbstractSolver}, formulation, node)
    @error "setup! method not implemented for $T."
end

function run!(T::Type{<:AbstractSolver}, solverdata, formulation, node, parameters)
    @error "run! method not implemented for $T."
end

function setdown!(T::Type{<:AbstractSolver}, solverrecord, formulation, node)
    @error "setdown! not implemented for $T."
end

"""
    apply!(SolverType, formulation, node, strategyrecord, parameters)

Applies the solver `SolverType` on the `formulation` in a `node` with 
`parameters`.
"""
function apply!(S::Type{<:AbstractSolver}, formulation, node, strategyrecord, 
                parameters)
    interface!(getsolver(strategyrecord), S, formulation, node)
    setsolver!(strategyrecord, S)
    solver_data = setup!(S, formulation, node)
    record = run!(S, solver_data, formulation, node, parameters)
    set_solver_record!(node, S, record)
    setdown!(S, record, formulation, node)
    return
end

"""
    interface!(SolverTypeSrc, SolverTypeDest, formulation, node)

Given a `formulation` in a `node` optimized using solver `SolverTypeSrc`, 
this method prepares the `formulation` in the `node` to be solved using 
solver `SolverTypeDest`.
Defining this method allows the user to apply solver `SolverTypeDest` after the
execution of solver `SolverTypeSrc`.
"""
function interface! end


struct StartNode <: AbstractSolver end
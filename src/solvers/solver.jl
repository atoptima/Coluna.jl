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
    setup!(SolverType, formulation, node, parameters)

Prepares the `formulation` in the `node` to be optimized by solver `SolverType`.
"""
function setup! end

"""
    solverdata(SolverType, formulation, node, parameters)

This method should return the `AbstractSolverData` structure that corresponds
to the solver `SolverType`. 
"""
function solverdata end

"""
    run!(SolverType, solverdata, formulation, node, parameters)

Runs the solver `SolverType` on the `formulation` in a `node` with `parameters`.
Return the  `AbstractSolverRecord` structure that corresponds to the solver 
`SolverType`
"""
function run! end

"""
    setdown!(SolverType, formulation, node, parameters)

Updates the `formulation` and the `node` after the execution of the solver
`SolverType`.
This method is executed after `run!`.
"""
function setdown! end

# Fallbacks
function setup!(T::Type{<:AbstractSolver}, formulation, node, parameters)
    @error "setup! method not implemented for solver $T."
end

function solverdata(T::Type{<:AbstractSolver}, formulation, node, parameters)
    @error "solverdata method not implemented for solver $T."
end

function run!(T::Type{<:AbstractSolver}, solverdata, formulation, node, parameters)
    @error "run! method not implemented for solver $T."
end

function setdown!(T::Type{<:AbstractSolver}, formulation, node, parameters)
    @error "setdown! not implemented for solver $T."
end

"""
    apply!(SolverType, formulation, node, strategy_record, parameters)

Applies the solver `SolverType` on the `formulation` in a `node` with 
`parameters`.
"""
function apply!(S::Type{<:AbstractSolver}, form, node, strategy_rec, 
                params)
    solver_data = interface!(getsolver(strategy_rec), S, form, node, params)
    setsolver!(strategy_rec, S)
    solver_data = solverdata(S, form, node, params)
    TO.@timeit to string(S) begin
        record = run!(S, solver_data, form, node, params)
    end
    set_solver_record!(node, S, record)
    return record
end

"""
    interface!(SolverTypeSrc, SolverTypeDest, formulation, node, parameters)

Given a `formulation` in a `node` optimized using solver `SolverTypeSrc`, 
this method prepares the `formulation` in the `node` to be solved using 
solver `SolverTypeDest`.
Defining this method allows the user to apply solver `SolverTypeDest` after the
execution of solver `SolverTypeSrc`.
"""
function interface! end

# Fallback
function interface!(Src::Type{<:AbstractSolver}, Dst::Type{<:AbstractSolver}, 
                    formulation, node, params)
    error("""
        Cannot apply $Dst after a round of $Src. 
        You should write method interface!(::Type{$Src}, ::Type{$Dst}, formulation, node, params)
    """)
end
struct StartNode <: AbstractSolver end
struct EndNode <: AbstractSolver end
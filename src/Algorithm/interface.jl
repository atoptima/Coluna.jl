struct EmptyInput <: AbstractInput end
struct EmptyOutput <: AbstractOutput end #Usefull ?

"""
    getstoragetype(AlgorithmType)::StorageType

    Every algorithm should communicate its storage type. By default, the storage is empty.    
"""
getstoragetype(algotype::Type{<:AbstractAlgorithm})::Type{<:AbstractStorage} = EmptyStorage

"""
    getslavealgorithms!(Algorithm, Formulation, Vector{Tuple{Formulation, AlgorithmType})

    Every algorithm should communicate its slave algorithms together with formulations 
    to which they are applied    
"""
getslavealgorithms!(
    algo::AbstractAlgorithm, form::AbstractFormulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}) = nothing

run!(algo::AbstractAlgorithm, form::AbstractFormulation, input::EmptyInput) = run!(algo, form) # good idea ?

"""
    NewOptimizationInput

Contains Incumbents
"""
struct NewOptimizationInput{F,S} <: AbstractInput
    incumbents::OptimizationState{F,S}
end

getinputresult(input::NewOptimizationInput) =  input.incumbents


"""
    OptimizationOutput

Contain OptimizationState, PrimalSolution (solution to relaxation), and 
DualBound (dual bound value)
"""
struct OptimizationOutput{F,S} <: AbstractOutput
    result::OptimizationState{F,S}    
end

getresult(output::OptimizationOutput)::OptimizationState = output.result


"""
    AbstractOptimizationAlgorithm

    This type of algorithm is used to "bound" a formulation, i.e. to improve primal
    and dual bounds of the formulation. Solving to optimality is a special case of "bounding".
    The input of such algorithm should be of type Incumbents.    
    The output of such algorithm should be of type OptimizationState.    
"""
abstract type AbstractOptimizationAlgorithm <: AbstractAlgorithm end
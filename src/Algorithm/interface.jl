"""
    AbstractInput

    Input of an algorithm.     
"""
abstract type AbstractInput end 

struct EmptyInput <: AbstractInput end

"""
    AbstractOutput

    Output of an algorithm.     
"""
abstract type AbstractOutput end 

struct EmptyOutput <: AbstractOutput end


"""
    AbstractAlgorithm

    An algorithm is a procedure with a known interface (input and output) applied to a formulation.
    An algorithm can use an additional storage to keep its computed data.
    Input of an algorithm is put to its storage before running it.
    The algorithm itself contains only its parameters. 
    Other data used by the algorithm is contained in its storage. 
    The same storage can be used by different algorithms 
    or different copies of the same algorithm (same algorithm with different parameters).
"""
abstract type AbstractAlgorithm end

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

"""
    run!(Algorithm, Formulation)::Output

    Runs the algorithm. The storage of the algorithm can be obtained by asking
    the formulation. Returns algorithm's output.    
"""
function run!(algo::AbstractAlgorithm, form::AbstractFormulation, input::AbstractInput)::AbstractOutput
    return EmptyOutput()
end

run!(algo::AbstractAlgorithm, form::AbstractFormulation, input::EmptyInput) = run!(algo, form)

"""
    OptimizationInput

Contains Incumbents
"""
struct OptimizationInput{S} <: AbstractInput
    incumbents::Incumbents{S}
end

getincumbents(input::OptimizationInput) = input.incumbents

"""
    OptimizationOutput

Contain OptimizationResult, PrimalSolution (solution to relaxation), and 
DualBound (dual bound value)
"""
struct OptimizationOutput{F,S} <: AbstractOutput
    result::OptimizationResult{F,S}    
end

getresult(output::OptimizationOutput)::OptimizationResult = output.result


"""
    AbstractOptimizationAlgorithm

    This type of algorithm is used to "bound" a formulation, i.e. to improve primal
    and dual bounds of the formulation. Solving to optimality is a special case of "bounding".
    The input of such algorithm should be of type Incumbents.    
    The output of such algorithm should be of type OptimizationResult.    
"""
abstract type AbstractOptimizationAlgorithm <: AbstractAlgorithm end

function run!(
    algo::AbstractOptimizationAlgorithm, form::AbstractFormulation, input::OptimizationInput
)::OldOutput
     algotype = typeof(algo)
     error("Method run! which takes formulation and Incumbents as input returns OldOutput
            is not implemented for algorithm $algotype.")
end
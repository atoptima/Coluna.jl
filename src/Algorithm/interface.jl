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
# TO DO : OptimizationOutput shoud be replaced by OptimizationResult which should contain all
mutable struct OptimizationOutput <: AbstractOutput
    result::OptimizationResult
    lp_primal_sol::PrimalSolution
    lp_dual_bound::DualBound
end

function OptimizationOutput(form::M, incumb::Incumbents) where {M<:AbstractFormulation}
    S = getobjsense(form)
    or = OptimizationResult(form)
    or.primal_bound = get_ip_primal_bound(incumb)
    or.dual_bound = get_ip_dual_bound(incumb)
    return OptimizationOutput(or, PrimalSolution(form), DualBound(form))
end

getresult(output::OptimizationOutput)::OptimizationResult = output.result
get_lp_primal_sol(output::OptimizationOutput)::PrimalSolution = output.lp_primal_sol
get_lp_dual_bound(output::OptimizationOutput)::DualBound = output.lp_dual_bound
set_lp_primal_sol(output::OptimizationOutput, ::Nothing) = nothing
set_lp_primal_sol(output::OptimizationOutput, sol::PrimalSolution) = output.lp_primal_sol = sol
set_lp_dual_bound(output::OptimizationOutput, bound::DualBound) = output.lp_dual_bound = bound

setfeasibilitystatus!(output::OptimizationOutput, status::FeasibilityStatus) = setfeasibilitystatus!(output.result, status)
setterminationstatus!(output::OptimizationOutput, status::TerminationStatus) = setterminationstatus!(output.result, status)

add_ip_primal_sol!(output::OptimizationOutput, ::Nothing) = nothing
function add_ip_primal_sol!(output::OptimizationOutput, solution::Solution)
    add_primal_sol!(output.result, solution)
    return
end

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
)::OptimizationOutput
     algotype = typeof(algo)
     error("Method run! which takes formulation and Incumbents as input returns OptimizationOutput
            is not implemented for algorithm $algotype.")
end
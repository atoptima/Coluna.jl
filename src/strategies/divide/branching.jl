"""
    AbstractRelaxationImprovement

    Relaxation imporovement is an algorithm to strengethen the current relaxation of the problem
    Usual types of such algorithms are finding branching candidates and cut separation
    However, other types are possible, for example, increasing ng-neighbourhood in the ng-path relaxation
"""
abstract type AbstractRelaxationImprovement end

"""
    AbstractBranchingRule

    Branching rules are algorithms which find branching candidates
"""
abstract type AbstractBranchingRule <: AbstractRelaxationImprovement end

"""
    AbstractBranchingCandidate

    A branching candidate should contain all information needed to perform branching,
    i.e. to generate branching constraints for every children given the current primal solution. 
    Branching candiates are also used to store the branching history. 
    History of a branching candidate is a collection of statistic records for every time this branching
        candidate was used to generate children nodes 
    Every branching candidate should contain a description, i.e. a string which serves for printing purposed,
    and also to detect the same branching candidates    
"""
abstract type AbstractBranchingCandidate end

"""
    VarBranchingCandidate

    Contains a variable on which we branch
"""
struct VarBranchingCandidate <: AbstractBranchingCandidate 
    description::String
    var_id::VarId
end


"""
    BranchingCandidateWithCurrentInfo

    Contains a branching candidates together with additional information: current id, current left-hand-side, etc.    
"""
struct BranchingCandidateWithCurrentInfo
    candidate::AbstractBranchingCandidate
    id::Int32
    lhs::Float32    
end

"""
    VarBranchingRule 

    Branching on variables
    For the moment, we branch on all integer variables
    In the future, a VarBranchingRule could be defined for a subset of integer variables
    in order to be able to give different priorities to different groups of variables
"""
struct VarBranchingRule <: AbstractDivideStrategy end


@enum SelectionCriterion FirstFoundCriterion MostFractionalCriterion 


"""
    StrongBranchingPhase

    Contains parameters to determing what will be done in a strong branching phase
"""

struct StrongBranchingPhase
    active::Bool
    exact::Bool
    max_nb_candidates::Int32
    max_nb_iterations::Int32
end

non_active_strong_branching_phase() = StrongBranchingPhase(active=false, exact=false, max_nb_candidates=0, max_nb_iterations=0)
exact_strong_branching_phase(candidates_num::Int32) = StrongBranchingPhase(active=true, exact=true, max_nb_candidates=candidates_num, 
                                                                           max_nb_iterations=10000) #TO DO : change to infini
only_restricted_master_strong_branching_phase(candidates_num::Int32) = StrongBranchingPhase(active=true, exact=true, max_nb_candidates=candidates_num, 
                                                                                            max_nb_iterations=0) 
                                                                                            
"""
    BranchingStrategy

    The strategy to perform branching in a branch-and-bound algorithm
"""
Base.@kwdef struct BranchingStrategy <: AbstractDivideStrategy
    # default parameterisation corresponds to simple branching (no strong branching)
    strong_branching_phase_one::StrongBranchingPhase = exact_strong_branching_phase(1)
    strong_branching_phase_two::StrongBranchingPhase = non_active_strong_branching_phase(1)
    strong_branching_phase_three::StrongBranchingPhase = non_active_strong_branching_phase()
    selection_creterion::SelectionCriterion = MostFractionalCriterion
    branching_rules::Dict{Float32,AbstractBranchingRule}
end

function apply!(strategy::BranchingStrategy, reform, node)
    branching_candidates = Vector{BranchingCandidateWithCurrentInfo}()

    needed_nb_candidates::Int32 = strategy.strong_branching_phase_one.max_nb_candidates
    # phase 0 of strong branching : we ask branching rules to generate branching candidates
    # we stop when   
    # - at least one candidate was generated, and its priority rounded down is stricly greater 
    #   than priorities of not yet considered branching rules
    # - all needed candidates were generated and their smallest priority is strictly greater
    #   than priorities of not yet considered branching rules

    min_priority = strategy.branching_rules.

    gcn_rec = apply!(GenerateChildrenNode(), reform, node) 
    return
end

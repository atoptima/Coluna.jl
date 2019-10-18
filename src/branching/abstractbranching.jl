"""
    SelectionCriterion
"""

@enum SelectionCriterion FirstFoundCriterion MostFractionalCriterion 

"""
    AbstractBranchingCandidate

    A branching candidate should contain all information needed to generate node's children    
    Branching candiates are also used to store the branching history. 
    History of a branching candidate is a collection of statistic records for every time this branching
        candidate was used to generate children nodes 
    Every branching candidate should contain a description, i.e. a string which serves for printing purposed,
    and also to detect the same branching candidates    
"""
abstract type AbstractBranchingCandidate end

getdescription(candidate::AbstractBranchingCandidate) = ""
generate_children!(candidate::AbstractBranchingCandidate, lhs::Float64, reform::Reformulation, node::Node) = nothing

"""
    AbstractRelaxationImprovement

    Relaxation imporovement is an algorithm to strengethen the current relaxation of the problem
    Usual types of such algorithms are finding branching candidates and cut separation
    However, other types are possible, for example, increasing ng-neighbourhood in the ng-path relaxation
    Each relaxation improvement should have a root and non-root priority
"""
abstract type AbstractRelaxationImprovement end

getrootpriority(improvement::AbstractRelaxationImprovement) = 1.0
getnonrootpriority(improvement::AbstractRelaxationImprovement) = 1.0
getpriority(improvement::AbstractRelaxationImprovement, rootnode::Bool) = 
    rootnode ? getrootpriority(improvement) : getnonrootpriority(improvement) 

"""
    AbstractBranchingRule

    Branching rules are algorithms which find branching candidates (a vector of BranchingGroup)
"""
abstract type AbstractBranchingRule <: AbstractRelaxationImprovement end

# this function is called once after the formulation is submitted by the user
prepare!(rule::AbstractBranchingRule, reform::Reformulation) = nothing

function gen_candidates_for_ext_sol(
        rule::AbstractBranchingRule, reform::Reformulation, sol::PrimalSolution{Sense}, 
        max_nb_candidates::Int64, local_id::Int64, criterion::SelectionCriterion
    ) where Sense
    return local_id, Vector{BranchingGroup}()
end

function gen_candidates_for_orig_sol(
        rule::AbstractBranchingRule, reform::Reformulation, sol::PrimalSolution{Sense}, 
        max_nb_candidates::Int64, local_id::Int64, criterion::SelectionCriterion
    ) where Sense
    return local_id, Vector{BranchingGroup}()
end

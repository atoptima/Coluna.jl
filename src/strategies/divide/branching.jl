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
    VarBranchingCandidate

    Contains a variable on which we branch
"""
struct VarBranchingCandidate <: AbstractBranchingCandidate 
    description::String
    var_id::VarId
end

getdescription(candidate::VarBranchingCandidate) = candidate.description

function generate_children!(candidate::VarBranchingCandidate, lhs::Float64, reform::Reformulation, node::Node)
    var = getvar(reform.master, candidate.var_id)
    @logmsg LogLevel(-1) string("Chosen branching variable : ", 
                                getname(getvar(reform.master, candidate.var_id)), ". With value ", lhs, ".")
    child1 = Node(node, Branch(var, ceil(lhs), Greater, getdepth(node)))
    child2 = Node(node, Branch(var, floor(lhs), Less, getdepth(node)))
    node.children = [child1, child2]
end


"""
    BranchingCandidateWithLocalInfo

    Contains a branching candidates together with additional information: local id, current left-hand-side, etc.    
"""
struct BranchingCandidateWithLocalInfo
    candidate::AbstractBranchingCandidate
    local_id::Int64
    lhs::Float64    
end

get_lhs_distance_to_integer(info::BranchingCandidateWithLocalInfo) = 
    min(info.lhs - floor(info.lhs), ceil(info.lhs) - info.lhs)

function generate_children!(info::BranchingCandidateWithLocalInfo, reform::Reformulation, node::Node)
    generate_children!(info.candidate, info.lhs, reform, node)
end


@enum SelectionCriterion FirstFoundCriterion MostFractionalCriterion 

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

    Branching rules are algorithms which find branching candidates (a vector of BranchingCandidateWithCurrentInfo)
"""
abstract type AbstractBranchingRule <: AbstractRelaxationImprovement end

# this function is called once after the formulation is submitted by the user
prepare!(rule::AbstractBranchingRule, reform::Reformulation) = nothing

function gen_candidates_for_ext_sol(
        rule::AbstractBranchingRule, reform::Reformulation, sol::PrimalSolution{Sense}, 
        max_nb_candidates::Int64, local_id::Int64, criterion::SelectionCriterion
    ) where Sense
    return local_id, Vector{BranchingCandidateWithLocalInfo}()
end

function gen_candidates_for_orig_sol(
        rule::AbstractBranchingRule, reform::Reformulation, sol::PrimalSolution{Sense}, 
        max_nb_candidates::Int64, local_id::Int64, criterion::SelectionCriterion
    ) where Sense
    return local_id, Vector{BranchingCandidateWithLocalInfo}()
end


"""
    VarBranchingRule 

    Branching on variables
    For the moment, we branch on all integer variables
    In the future, a VarBranchingRule could be defined for a subset of integer variables
    in order to be able to give different priorities to different groups of variables
"""
Base.@kwdef struct VarBranchingRule <: AbstractBranchingRule 
    root_priority::Float64 = 1.0
    nonroot_priority::Float64 = 1.0
end

getrootpriority(rule::VarBranchingRule) = rule.root_priority
getnonrootpriority(rule::VarBranchingRule) = rule.nonroot_priority

function gen_candidates_for_orig_sol(
        rule::VarBranchingRule, reform::Reformulation, sol::PrimalSolution{Sense}, 
        max_nb_candidates::Int64, local_id::Int64, criterion::SelectionCriterion
    ) where Sense
    candidates = Vector{BranchingCandidateWithLocalInfo}()
    for (var_id, val) in sol
        # Do not consider continuous variables as branching candidates
        getperenekind(getelements(getsol(sol))[var_id]) == Continuous && continue
        if !isinteger(val)
            #description string is just the variable name
            candidate = VarBranchingCandidate(getname(getvar(reform.master, var_id)), var_id)
            local_id += 1 
            push!(candidates, BranchingCandidateWithLocalInfo(candidate, local_id, val))
        end
    end

    return local_id, candidates
end


"""
    StrongBranchingPhase

    Contains parameters to determing what will be done in a strong branching phase
"""

struct StrongBranchingPhase
    active::Bool
    exact::Bool
    max_nb_candidates::Int64
    max_nb_iterations::Int64
end

non_active_strong_branching_phase() = StrongBranchingPhase(false, false, 0, 0)
exact_strong_branching_phase(candidates_num::Int64) = 
    StrongBranchingPhase(true, true, candidates_num, 10000) #TO DO : change to infinity
only_restricted_master_strong_branching_phase(candidates_num::Int64) = 
    StrongBranchingPhase(true, true, candidates_num, 0) 
                                                                                            
"""
    BranchingStrategy

    The strategy to perform (strong) branching in a branch-and-bound algorithm
    Contains strong branching parameterisation and selection criterion
    Should be populated by branching rules before branch-and-bound execution
"""
Base.@kwdef struct BranchingStrategy <: AbstractDivideStrategy
    # default parameterisation corresponds to simple branching (no strong branching)
    strong_branching_phase_one::StrongBranchingPhase = exact_strong_branching_phase(1)
    strong_branching_phase_two::StrongBranchingPhase = non_active_strong_branching_phase()
    strong_branching_phase_three::StrongBranchingPhase = non_active_strong_branching_phase()
    selection_criterion::SelectionCriterion = MostFractionalCriterion
    branching_rules::Vector{AbstractBranchingRule} = [VarBranchingRule()]
end

function prepare!(strategy::BranchingStrategy, reform::Reformulation)
    for rule in strategy.branching_rules
        prepare!(rule, reform)
    end
end

function apply!(strategy::BranchingStrategy, reform, node)
    kept_branching_candidates = Vector{BranchingCandidateWithLocalInfo}()
    is_root::Bool = getdepth(node) == 0

    # first we sort branching rules by their root/non-root priority (depending on the node depth)
    if is_root
        sort!(strategy.branching_rules, rev = true, by = x -> getrootpriority(x))
    else  
        sort!(strategy.branching_rules, rev = true, by = x -> getnonrootpriority(x))
    end

    # we obtain the original and extended solutions
    master = getmaster(reform)
    original_solution = PrimalSolution{getobjsense(master)}()
    extended_solution = PrimalSolution{getobjsense(master)}()
    if projection_is_possible(master)
        extended_solution = get_lp_primal_sol(node.incumbents)
        original_solution = proj_cols_on_rep(extended_solution, master)
    else
        original_solution = get_lp_primal_sol(node.incumbents)
    end

    # phase 0 of strong branching : we ask branching rules to generate branching candidates
    # we stop when   
    # - at least one candidate was generated, and its priority rounded down is stricly greater 
    #   than priorities of not yet considered branching rules
    # - all needed candidates were generated and their smallest priority is strictly greater
    #   than priorities of not yet considered branching rules
    nb_candidates_needed::Int64 = strategy.strong_branching_phase_one.max_nb_candidates
    local_id::Int64 = 0
    min_priority::Float64 = getpriority(strategy.branching_rules[1], is_root)
    for rule in strategy.branching_rules
        # decide whether to stop generating candidates or not
        priority::Float64 = getpriority(rule, is_root) 
        nb_candidates_found::Int64 = length(kept_branching_candidates)
        if priority < floor(min_priority) && nb_candidates_found > 0
            break
        elseif priority < min_priority && nb_candidates_found >= nb_candidates_needed
            break
        end
        min_priority = priority

        # generate candidates
        candidates = Vector{BranchingCandidateWithLocalInfo}()
        local_id, candidates = gen_candidates_for_orig_sol(rule, reform, original_solution, nb_candidates_needed, 
                                                           local_id, strategy.selection_criterion)
        nb_candidates_found += length(candidates)
        append!(kept_branching_candidates, candidates)
                                
        if projection_is_possible(master)
            local_id, candidates = gen_candidates_for_ext_sol(rule, reform, extended_solution, nb_candidates_needed, 
                                                              local_id, strategy.selection_criterion)
            nb_candidates_found += length(candidates)
            append!(kept_branching_candidates, candidates)
        end

        # sort branching candidates according to the selection criterion and remove excess ones
        if strategy.selection_criterion == FirstFoundCriterion
            sort!(kept_branching_candidates, by = x -> x.id)
        elseif strategy.selection_criterion == MostFractionalCriterion    
            sort!(kept_branching_candidates, rev = true, by = x -> get_lhs_distance_to_integer(x))
        end
        if length(kept_branching_candidates) > nb_candidates_needed
            resize!(kept_branching_candidates, nb_candidates_needed)
        end
    end


    #in the case of simple branching, it remains to generate the nodes
    if strategy.strong_branching_phase_one.exact && strategy.strong_branching_phase_one.max_nb_candidates == 1 && 
       !strategy.strong_branching_phase_two.exact
        if isempty(kept_branching_candidates)
            @logmsg LogLevel(0) "Did not branching candidates. No children nodes will be generated."
        else 
            generate_children!(kept_branching_candidates[1], reform, node)
        end       
    end

    return
end

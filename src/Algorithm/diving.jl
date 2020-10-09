
"""
    RoundingSelectionCriterion
"""
@enum RoundingSelectionCriterion begin
    FirstFoundRoundDownCriterion = 1
    FirstFoundRoundUpCriterion = 2
    MostFractionalRoundingCriterion = 3
    LeastFractionalRoundingCriterion = 4
    SmallestCostRoundingCriterion = 5 # require access to formulation
    LargestCostRoundingCriterion = 6 # require access to formulation
end

function require_asses_to_formulation(criteria::Vector{RoundingSelectionCriterion})
    for criterion in criteria
        if criterion == SmallestCostRoundingCriterion || 
           criterion == LargestCostRoundingCriterion
            return true
        end
    end
    return false
end

"""
    DiveAlgorithm

    The algorithm to perform diving
    It fixes a partial solution and creates child nodes
    It also supports LDS (limited discrepancy search)
"""
# TO DO : to support strong diving
# TO DO : for the moment, we fix only columns, we need to support fixing pure master variables
@with_kw struct DiveAlgorithm <: AbstractDivideAlgorithm
    # FirstFoundRoundUpCriterion is always used as the last criterion
    rounding_criteria::Vector{RoundingSelectionCriterion} = [LeastFractionalRoundingCriterion] 
    fix_integer_part_before_rounding::Bool = false
    max_depth::Int64 = 0
    max_discrepancy::Int64 = 0    
    int_tol::Float64 = 1e-6
    comp_tol::Float64 = 1e-6
end

# TO DO : add optional parameters (tolerance, LDS parameters, fix integer part)
DefaultDivingHeuristic() = ParameterisedHeuristic(
    TreeSearchAlgorithm(
        conqueralg = ColCutGenConquer(
            run_preprocessing = true,
            preprocess = PreprocessAlgorithm(preprocess_subproblems = false, printing = false)
        ), 
        dividealg = DiveAlgorithm(), 
        skiprootnodeconquer = true, 
        maxnumnodes = 5
    ),
    1.0, 1.0, 1, 1000, "Pure diving"
)    

# DiveAlgorithm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_storages_usage(algo::DiveAlgorithm, reform::Reformulation) 
    master = getmaster(reform)
    storages_usage = Tuple{AbstractModel, StorageTypePair, StorageAccessMode}[]     
    push!(storages_usage, (master, PreprocessingStoragePair, READ_AND_WRITE))
    push!(storages_usage, (master, PartialSolutionStoragePair, READ_AND_WRITE))
    if require_asses_to_formulation(algo.rounding_criteria)
        push!(storages_usage, (master, MasterColumnsStoragePair, READ_ONLY))
    end
    return storages_usage
end

function solution_to_string(form::Formulation, dict::Dict{VarId, Float64})
    str = string()
    put_comma = false
    for (varid, val) in dict
        str = string(str, put_comma ? ", " : "", getname(form, varid), " = ", val)
        put_comma = true
    end
    return str
end

struct RoundingCandidate
    dive_algorithm::DiveAlgorithm
    form::Formulation
    varid::VarId
    value::Float64
    isroundup::Bool
    rnd_value::Float64
end

function compare_candidates(
    first_cand::RoundingCandidate, second_cand::RoundingCandidate, criterion::RoundingSelectionCriterion
)
    algo = first_cand.dive_algorithm
    first_dist_to_round = abs(first_cand.rnd_value - first_cand.value) 
    second_dist_to_round = abs(second_cand.rnd_value - second_cand.value) 
    form = first_cand.form
    if criterion == FirstFoundRoundDownCriterion   
        if first_cand.isroundup == second_cand.isroundup
            return 0
        else 
            return first_cand.isroundup ? -1 : 1
        end
    elseif criterion == FirstFoundRoundUpCriterion
        if first_cand.isroundup == second_cand.isroundup
            return 0
        else 
            return first_cand.isroundup ? 1 : -1
        end
    elseif criterion == MostFractionalRoundingCriterion
        if first_dist_to_round > second_dist_to_round + algo.comp_tol                
            return 1
        elseif first_dist_to_round < second_dist_to_round - algo.comp_tol                
            return -1
        else    
            return 0
        end
    elseif criterion == LeastFractionalRoundingCriterion
        if first_dist_to_round < second_dist_to_round - algo.comp_tol                
            return 1
        elseif first_dist_to_round > second_dist_to_round + algo.comp_tol                
            return -1
        else    
            return 0
        end
    elseif criterion == SmallestCostRoundingCriterion        
        first_cand_cost = getcurcost(form, first_cand.varid)
        second_cand_cost = getcurcost(form, second_cand.varid)
        if first_cand_cost < second_cand_cost - algo.comp_tol                
            return 1
        elseif first_cand_cost > second_cand_cost + algo.comp_tol                
            return -1
        else    
            return 0
        end
    elseif criterion == LargestCostRoundingCriterion        
        first_cand_cost = getcurcost(form, first_cand.varid)
        second_cand_cost = getcurcost(form, second_cand.varid)
        if first_cand_cost > second_cand_cost + algo.comp_tol                
            return 1
        elseif first_cand_cost < second_cand_cost - algo.comp_tol                
            return -1
        else    
            return 0
        end
    else 
        @error string("Unknown rounding criterion ", criterion, " during the dive algorithm")    
    end    
end

function better_candidate(first_cand::RoundingCandidate, second_cand::RoundingCandidate)
    criteria = first_cand.dive_algorithm.rounding_criteria
    for criterion in criteria 
        result = compare_candidates(first_cand, second_cand, criterion)
        if result == 1
            return true
        elseif result == -1
            return false
        end
    end
    return compare_candidates(first_cand, second_cand, FirstFoundRoundUpCriterion) == 1 
end

function run!(algo::DiveAlgorithm, data::ReformData, input::DivideInput)::DivideOutput
    parent = getparent(input)
    masterdata = getmasterdata(data)
    master = getmodel(masterdata)
    optstate = getoptstate(parent)
    solution = get_best_lp_primal_sol(optstate)
    @show solution

    storages_to_restore = StoragesUsageDict(
        (master, PreprocessingStoragePair) => READ_AND_WRITE,
        (master, PartialSolutionStoragePair) => READ_AND_WRITE
    )
    if require_asses_to_formulation(algo.rounding_criteria)
        push!(storages_to_restore, (master, MasterColumnsStoragePair) => READ_ONLY)
    end

    restore_states!(copy_states(parent.stateids), storages_to_restore)    
    preprocess_storage = getstorage(masterdata, PreprocessingStoragePair)
    partsol_storage = getstorage(masterdata, PartialSolutionStoragePair)

    if algo.fix_integer_part_before_rounding
        fixed_solution_is_empty = true
        for (var_id, val) in solution
            !(getduty(var_id) <= MasterCol) && continue            
            if val > 1.0 - algo.int_tol
                value = round(val + algo.int_tol, RoundDown)
                fixed_solution_is_empty = false
                add_to_localpartialsol!(preprocess_storage, var_id, value)
                add_to_solution!(partsol_storage, var_id, value)
            end
        end
        if !fixed_solution_is_empty
            @logmsg LogLevel(0) string(
                "Fixed solution : ", 
                solution_to_string(master, preprocess_storage.localpartialsol)
            )
            child = Node(master, parent, "", store_states!(data))
            return DivideOutput([child], optstate)
        end
    end

    candidates = Vector{RoundingCandidate}()
    for (var_id, val) in solution
        rnd_up_value = round(val - algo.int_tol, RoundUp)
        rnd_down_value = round(val + algo.int_tol, RoundDown)
        if rnd_up_value > algo.int_tol 
            push!(candidates, RoundingCandidate(
                algo, master, var_id, val, true, rnd_up_value
            ))  
        end
        if rnd_down_value > algo.int_tol 
            push!(candidates, RoundingCandidate(
                algo, master, var_id, val, false, rnd_down_value
            ))
        end
    end
    sort!(candidates, lt=better_candidate)
    println()
    # for cand in candidates
    #     println("Candidate ", getname(master, cand.varid), " with value ", cand.value, " round ", cand.isroundup ? "up" : "down")
    # end

    best_cand = candidates[begin]
    add_to_localpartialsol!(preprocess_storage, best_cand.varid, best_cand.rnd_value)
    add_to_solution!(partsol_storage, best_cand.varid, best_cand.rnd_value)

    # TO DO : we need to print also the projected rounded solution
    @logmsg LogLevel(0) string(
        "Rounded solution : ", 
        solution_to_string(master, preprocess_storage.localpartialsol)
    )
    child = Node(master, parent, "", store_states!(data))
    return DivideOutput([child], optstate)
end
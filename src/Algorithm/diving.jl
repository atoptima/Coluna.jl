
"""
    RoundingSelectionCriterion
"""
@enum RoundingSelectionCriterion begin
    FirstFoundRoundDownCriterion = 1
    FirstFoundRoundUpCriterion = 2
    MostFractionalRoundingCriterion = 3
    LeastFractionalRoundingCriterion = 4
    SmallestCostRoudingCriterion = 5
    LargestCostRoudingCriterion = 6
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
    rounding_criterion::Vector{RoundingSelectionCriterion} = 
        [LeastFractionalRoundingCriterion, FirstFoundRoundUpCriterion]
    fix_int_values_before_rounding::Bool = false
    max_depth::Int64 = 0
    max_discrepancy::Int64 = 0    
    int_tol::Float64 = 1e-6
end

# function get_storages_usage!(
#     algo::DiveAlgorithm, reform::Reformulation, storages_usage::StoragesUsageDict
# )
#     add_storage!(storages_usage, getmaster(reform), PartialSolutionStoragePair)
#     add_storage!(storages_usage, getmaster(reform), PreprocessingStoragePair)
# end

# function get_storages_to_restore!(
#     algo::DiveAlgorithm, reform::Reformulation, storages_to_restore::StoragesToRestoreDict
# )
#     # dive algorithm restores all storages itself so we do not require anything here
# end

function run!(algo::DiveAlgorithm, data::ReformData, input::DivideInput)::DivideOutput
    parent = getparent(input)
    optstate = getoptstate(parent)
    extended_solution = get_best_lp_primal_sol(optstate)

    #

    if algo.fix_int_values_before_rounding

    end

end
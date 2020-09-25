
"""
    ConquerInput

    Input of a conquer algorithm used by the tree search algorithm.
    Contains the node in the search tree and the collection of storages to restore 
    before running the conquer algorithm. This collection of storages is passed
    in the input so that it is not obtained each time the conquer algorithm runs. 
"""
struct ConquerInput <: AbstractInput 
    node::Node    
    storages_to_restore::StoragesUsageDict
end

getnode(input::ConquerInput) = input.node

restore_states!(input::ConquerInput) = restore_states!(input.node.stateids, input.storages_to_restore) 

"""
    AbstractConquerAlgorithm

    This algorithm type is used by the tree search algorithm to update the incumbents and the formulation.
    For the moment, a conquer algorithm can be run only on reformulation.     
    A conquer algorithm should restore states of storages using function restore_states!(::ConquerInput)
        - each time it runs in the beginning
        - each time after calling a child manager algorithm
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end

# conquer algorithms are always manager algorithms (they manage storing and restoring storages)
ismanager(algo::AbstractConquerAlgorithm) = true

function run!(algo::AbstractConquerAlgorithm, data::ReformData, input::ConquerInput)
    algotype = typeof(algo)
    error(string("Method run! which takes as parameters ReformData and ConquerInput ", 
                 "is not implemented for algorithm $algotype.")
    )
end    

# this function is needed in strong branching (to have a better screen logging)
isverbose(algo::AbstractConquerAlgorithm) = false

# this function is needed to check whether the best primal solution should be copied to the node optimization state
exploits_primal_solutions(algo::AbstractConquerAlgorithm) = false

# returns the optimization part of the output of the conquer algorithm 
function apply_conquer_alg_to_node!(
    node::Node, algo::AbstractConquerAlgorithm, data::ReformData, storages_to_restore::StoragesUsageDict
)  
    nodestate = getoptstate(node)
    if isverbose(algo)
        @logmsg LogLevel(-1) string("Node IP DB: ", get_ip_dual_bound(nodestate))
        @logmsg LogLevel(-1) string("Tree IP PB: ", get_ip_primal_bound(nodestate))
    end
    if (ip_gap(nodestate) <= 0.0 + 0.00000001)
        isverbose(algo) && @logmsg LogLevel(-1) string(
            "IP Gap is non-positive: ", ip_gap(getincumbents(node)), ". Abort treatment."
        )
    else    
        isverbose(algo) && @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")

        run!(algo, data, ConquerInput(node, storages_to_restore))
        store_states!(data, node.stateids)
    end
    node.conquerwasrun = true
    return
end


####################################################################
#                      BendersConquer
####################################################################

@with_kw struct BendersConquer <: AbstractConquerAlgorithm 
    benders::BendersCutGeneration = BendersCutGeneration()
end

isverbose(strategy::BendersConquer) = true

# BendersConquer does not use any storage for the moment, it just calls 
# BendersCutSeparation algorithm, therefore get_storages_usage() is not defined for it

function get_child_algorithms(algo::BendersConquer, reform::Reformulation) 
    return [(algo.benders, reform)]
end

function run!(algo::BendersConquer, data::ReformData, input::ConquerInput)
    restore_states!(input)
    node = getnode(input)    
    nodestate = getoptstate(node)
    output = run!(algo.benders, data, OptimizationInput(nodestate))
    update!(nodestate, getoptstate(output))
    return 
end

####################################################################
#                      ColCutGenConquer
####################################################################

"""
    Coluna.Algorithm.ColCutGenConquer(
        colgen = ColumnGeneration()
        cutgen = CutCallbacks()
        mastipheur = SolveIpForm()
        preprocess = PreprocessAlgorithm()
        run_mastipheur::Bool = true
        run_preprocessing::Bool = false
    )

    Column-and-cut-generation based algorithm to find primal and dual bounds for a 
    problem decomposed using Dantzig-Wolfe paradigm. It applies `colgen` for the column 
    generation phase, `cutgen` for the cut generation phase, and `masteripheur` 
to optimize the integer restricted master.
"""
@with_kw struct ColCutGenConquer <: AbstractConquerAlgorithm 
    colgen = ColumnGeneration()
    cutgen = CutCallbacks()
    mastipheur = SolveIpForm(get_dual_bound = false)
    preprocess = PreprocessAlgorithm()
    max_nb_cut_rounds::Int = 3 # TODO : tailing-off ?
    run_mastipheur::Bool = true
    run_preprocessing::Bool = false
end

isverbose(algo::ColCutGenConquer) = algo.colgen.log_print_frequency > 0

# ColCutGenConquer does not use any storage for the moment, therefore 
# get_storages_usage() is not defined for it

function get_child_algorithms(algo::ColCutGenConquer, reform::Reformulation) 
    child_algos = Tuple{AbstractAlgorithm, AbstractModel}[]
    push!(child_algos, (algo.colgen, reform))
    push!(child_algos, (algo.cutgen, getmaster(reform)))
    algo.run_mastipheur && push!(child_algos, (algo.mastipheur, getmaster(reform)))
    algo.run_preprocessing && push!(child_algos, (algo.preprocess, reform))
    return child_algos
end

function run!(algo::ColCutGenConquer, data::ReformData, input::ConquerInput)
    restore_states!(input)
    node = getnode(input)
    nodestate = getoptstate(node)
    reform = getreform(data)
    if algo.run_preprocessing && isinfeasible(run!(algo.preprocess, data, EmptyInput()))
        setfeasibilitystatus!(nodestate, INFEASIBLE)
        return 
    end

    nb_tightening_rounds = 0
    colgen_output = run!(algo.colgen, data, OptimizationInput(nodestate))
    update!(nodestate, getoptstate(colgen_output))

    while !to_be_pruned(node) && nb_tightening_rounds < algo.max_nb_cut_rounds
        sol = get_best_lp_primal_sol(getoptstate(colgen_output))
        if sol !== nothing
            cutcb_input = CutCallbacksInput(sol)
            cutcb_output = run!(CutCallbacks(), getmasterdata(data), cutcb_input)
            cutcb_output.nb_cuts_added == 0 && break
        else
            @warn "Skip cut generation because no best primal solution."
            break
        end

        set_ip_dual_bound!(nodestate, DualBound(reform))
        set_lp_dual_bound!(nodestate, DualBound(reform))
        colgen_output = run!(algo.colgen, data, OptimizationInput(nodestate))
        update!(nodestate, getoptstate(colgen_output))

        nb_tightening_rounds += 1
    end

    if !to_be_pruned(node) && algo.run_mastipheur 
        @logmsg LogLevel(0) "Run IP restricted master heuristic."
        TO.@timeit Coluna._to "RestMasterHeur" begin
            heur_output = run!(
                algo.mastipheur, getmasterdata(data), OptimizationInput(nodestate)
            )
            update_all_ip_primal_solutions!(nodestate, getoptstate(heur_output))
        end
    end 
    return
end

####################################################################
#                      RestrMasterLPConquer
####################################################################

@with_kw struct RestrMasterLPConquer <: AbstractConquerAlgorithm 
    masterlpalgo::SolveLpForm = SolveLpForm()
end

# RestrMasterLPConquer does not use any storage, therefore get_storages_usage() is not defined for it

function get_child_algorithms(algo::RestrMasterLPConquer, reform::Reformulation) 
    return [(algo.masterlpalgo, getmaster(reform))]
end

# function get_storages_usage!(
#     algo::RestrMasterLPConquer, reform::Reformulation, storages_usage::StoragesUsageDict
# )
#     get_storages_usage!(algo.masterlpalgo, getmaster(reform), storages_usage)
# end

# function get_storages_to_restore!(
#     algo::RestrMasterLPConquer, reform::Reformulation, storages_to_restore::StoragesToRestoreDict
# ) 
#     get_storages_to_restore!(algo.masterlpalgo, getmaster(reform), storages_to_restore)
# end

function run!(algo::RestrMasterLPConquer, data::ReformData, input::ConquerInput)
    restore_states!(input)
    node = getnode(input)
    nodestate = getoptstate(node)
    output = run!(algo.masterlpalgo, getmasterdata(data), OptimizationInput(nodestate))
    update!(nodestate, getoptstate(output))
end


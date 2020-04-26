
"""
    ConquerInput

    Input of a conquer algorithm used by the tree search algorithm.
    Contains the node in the search tree.
"""
struct ConquerInput <: AbstractInput 
    node::Node    
end

getnode(input::ConquerInput) = input.node


"""
    AbstractConquerAlgorithm

    This algorithm type is used by the tree search algorithm to update the incumbents and the formulation.
    For the moment, a conquer algorithm can be run only on reformulation.     
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end

function run!(algo::AbstractConquerAlgorithm, data::ReformData, input::ConquerInput)::ConquerOutput
    algotype = typeof(algo)
    error("Method run! which takes  as parameters and returns AbstractConquerOutput 
           is not implemented for algorithm $algotype.")
end    

# this function is needed in strong branching (to have a better screen logging)
isverbose(algo::AbstractConquerAlgorithm) = false

# this function is needed to check whether the best primal solution should be copied to the node optimization state
exploits_primal_solutions(algo::AbstractConquerAlgorithm) = false

# returns the optimization part of the output of the conquer algorithm 
function apply_conquer_alg_to_node!(
    node::Node, algo::AbstractConquerAlgorithm, data::ReformData
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
        # node.conquerrecord = nothing
        return 
    end
    isverbose(algo) && @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")

    # # TO DO : get rid of Branch 
    # apply_branch!(getreform(data), getbranch(node))

    run!(algo, data, ConquerInput(node))
    node.conquerwasrun = true
end


####################################################################
#                      BendersConquer
####################################################################

Base.@kwdef struct BendersConquer <: AbstractConquerAlgorithm 
    benders::BendersCutGeneration = BendersCutGeneration()
end

isverbose(strategy::BendersConquer) = true

function getslavealgorithms!(
    algo::BendersConquer, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, AbstractAlgorithm}}
)
    push!(slaves, (reform, algo.benders))
    getslavealgorithms!(algo.benders, reform, slaves)
end

function run!(algo::BendersConquer, reform::Reformulation, input::ConquerInput)
    node = getnode(input)
    nodestate = getoptstate(node)
    output = run!(algo.benders, reform, OptimizationInput(nodestate))

    update!(nodestate, getoptstate(output))
    node.conquerrecord = record!(reform)
    return 
end

####################################################################
#                      ColGenConquer
####################################################################

Base.@kwdef struct ColGenConquer <: AbstractConquerAlgorithm 
    colgen::ColumnGeneration = ColumnGeneration()
    mastipheur::SolveIpForm = SolveIpForm()
    preprocess::PreprocessAlgorithm = PreprocessAlgorithm()
    run_mastipheur::Bool = true
    run_preprocessing::Bool = false
end

isverbose(algo::ColGenConquer) = algo.colgen.log_print_frequency > 0

function getslavealgorithms!(
    algo::ColGenConquer, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, AbstractAlgorithm}}
)
    push!(slaves, (reform, algo.colgen))
    getslavealgorithms!(algo.colgen, reform, slaves)

    if (algo.run_mastipheur)
        push!(slaves, (reform, algo.mastipheur))
        getslavealgorithms!(algo.mastipheur, reform, slaves)
    end 

    if (algo.run_preprocessing)
        push!(slaves, (reform, algo.preprocess))
        getslavealgorithms!(algo.preprocess, reform, slaves)
    end 

end

function run!(algo::ColGenConquer, reform::Reformulation, input::ConquerInput)

    node = getnode(input)
    nodestate = getoptstate(node)
    if algo.run_preprocessing && isinfeasible(run!(algo.preprocess, reform))
        setfeasibilitystatus!(nodestate, INFEASIBLE)
        return 
    end

    colgen_output = run!(algo.colgen, reform, OptimizationInput(nodestate))
    update!(nodestate, getoptstate(colgen_output))

    if (!to_be_pruned(node))
        node.conquerrecord = record!(reform)
        if algo.run_mastipheur 
            heur_output = run!(
                algo.mastipheur, getmaster(reform), OptimizationInput(nodestate)
            )
            update_all_ip_primal_solutions!(nodestate, getoptstate(heur_output))
        end
    end 

end

####################################################################
#                      RestrMasterLPConquer
####################################################################

Base.@kwdef struct RestrMasterLPConquer <: AbstractConquerAlgorithm 
    masterlpalgo::SolveLpForm = SolveLpForm()
end

function getslavealgorithms!(
    algo::RestrMasterLPConquer, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, AbstractAlgorithm}}
)
    push!(slaves, (reform, algo.masterlpalgo))
    getslavealgorithms!(algo.masterlpalgo, reform, slaves)
end

function run!(algo::RestrMasterLPConquer, reform::Reformulation, input::ConquerInput)
    node = getnode(input)
    nodestate = getoptstate(node)
    output = run!(algo.masterlpalgo, getmaster(reform), OptimizationInput(nodestate))
    update!(nodestate, getoptstate(output))
    node.conquerrecord = record!(reform)
end


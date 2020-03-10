"""
    ConquerRecord

    Record of a conquer algorithm used by the tree search algorithm.
    Contain ReformulationRecord and records for all storages used by 
    reformulation algorithms.
"""
# TO DO : add records for storages and record id
struct ConquerRecord <: AbstractRecord 
    # id::Int64
    reformrecord::ReformulationRecord
    # storagerecords::Dict{Tuple{AbstractFormulation, Type{<:AbstractStorage}}, AbstractRecord}    
end

function record!(reform::Reformulation)::ConquerRecord
    @logmsg LogLevel(0) "Recording reformulation state."
    reformrecord = ReformulationRecord()
    add_to_recorded!(reform, reformrecord)
    return ConquerRecord(reformrecord)
end

prepare!(reform::Reformulation, ::Nothing) = nothing

function prepare!(reform::Reformulation, record::ConquerRecord)
    @logmsg LogLevel(0) "Preparing reformulation according to node record"
    @logmsg LogLevel(0) "Preparing reformulation master"
    prepare!(getmaster(reform), record.reformrecord)
    for (spuid, spform) in get_dw_pricing_sps(reform)
        @logmsg LogLevel(0) string("Resetting sp ", spuid, " state.")
        prepare!(spform, record.reformrecord)
    end
    return
end

"""
    ConquerInput

    Input of a conquer algorithm used by the tree search algorithm.
    Contains current incumbents and the root node flag.
"""
struct ConquerInput <: AbstractInput 
    incumb::Incumbents
    rootnodeflag::Bool
end

getincumbents(input::ConquerInput)::Incumbents = input.incumb

"""
    ConquerOutput

    Output of a conquer algorithm used by the tree search algorithm.
    Contain current incumbents, infeasibility status, and the record of its storage.
"""
# TO DO : replace OptimizationOutput by OptimizationResult
struct ConquerOutput <: AbstractOutput 
    optoutput::OptimizationOutput
    record::ConquerRecord
end

getrecord(output::ConquerOutput) = output.record
getoptoutput(output::ConquerOutput) = output.optoutput


"""
    AbstractConquerAlgorithm

    This algorithm type is used by the tree search algorithm to update the incumbents and the formulation.
    For the moment, a conquer algorithm can be run only on reformulation.     
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end

function run!(algo::AbstractConquerAlgorithm, reform::Reformulation, input::ConquerInput)::ConquerOutput
    algotype = typeof(algo)
    error("Method run! which takes Reformulation and Incumbents as parameters and returns AbstractConquerOutput 
           is not implemented for algorithm $algotype.")
end    

# this function is needed in strong branching (to have a better screen logging)
isverbose(strategy::AbstractConquerAlgorithm) = false


####################################################################
#                      BendersConquer
####################################################################

Base.@kwdef struct BendersConquer <: AbstractConquerAlgorithm 
    benders::BendersCutGeneration = BendersCutGeneration()
end

isverbose(strategy::BendersConquer) = true

function getslavealgorithms!(
    algo::BendersConquer, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}
)
    push!(slaves, (reform, typeof(algo.benders)))
    getslavealgorithms!(algo.benders, reform, slaves)
end

function run!(algo::BendersConquer, reform::Reformulation, input::ConquerInput)::ConquerOutput
    optoutput = run!(algo.benders, reform, OptimizationInput(getincumbents(input)))
    return ConquerOutput(optoutput, ConquerRecord(record!(reform)))
end

####################################################################
#                      ColGenConquer
####################################################################

Base.@kwdef struct ColGenConquer <: AbstractConquerAlgorithm 
    colgen::ColumnGeneration = ColumnGeneration()
    mastipheur::IpForm = IpForm()
    preprocess::PreprocessAlgorithm = PreprocessAlgorithm()
    run_mastipheur::Bool = true
    run_preprocessing::Bool = false
end

isverbose(algo::ColGenConquer) = algo.colgen.log_print_frequency > 0

function getslavealgorithms!(
    algo::ColGenConquer, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}
)
    push!(slaves, (reform, typeof(algo.colgen)))
    getslavealgorithms!(algo.colgen, reform, slaves)

    if (algo.run_mastipheur)
        push!(slaves, (reform, typeof(algo.mastipheur)))
        getslavealgorithms!(algo.mastipheur, reform, slaves)
    end 

    if (algo.run_preprocessing)
        push!(slaves, (reform, typeof(algo.preprocess)))
        getslavealgorithms!(algo.preprocess, reform, slaves)
    end 

end

function run!(algo::ColGenConquer, reform::Reformulation, input::ConquerInput)::ConquerOutput

    if algo.run_preprocessing && isinfeasible(run!(algo.preprocess, reform))
        optoutput = OptimizationOutput(incumb)
        setfeasibilitystatus!(optoutput, INFEASIBLE)
        return ConquerOutput(optoutput, ConquerRecord(record!(reform)))
    end

    incumb = getincumbents(input)
    optoutput = run!(algo.colgen, reform, OptimizationInput(incumb))
    record = record!(reform)

    gap_is_positive = gap(getresult(optoutput)) >= 0.00001 # TO DO : make a parameter
    if algo.run_mastipheur && isfeasible(getresult(optoutput)) && gap_is_positive
        # TO DO : update incumb with col.gen. output
        heuroutput = run!(algo.mastipheur, reform, OptimizationInput(incumb))
        heuroutputres = getresult(heuroutput)
        if nb_ip_primal_sols(heuroutputres) > 0
            add_ip_primal_sol!(getresult(optoutput), get_best_ip_primal_sol(heuroutputres))
            #for sol in get_ip_primal_sols(heuroutputres)
            #    add_ip_primal_sol!(getresult(optoutput), sol)
            #end
        end
    end 

    return ConquerOutput(optoutput, record)
end

####################################################################
#                      RestrMasterLPConquer
####################################################################

Base.@kwdef struct RestrMasterLPConquer <: AbstractConquerAlgorithm 
    masterlpalgo::LpForm = LpForm()
end

function getslavealgorithms!(
    algo::RestrMasterLPConquer, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}
)
    push!(slaves, (reform, typeof(algo.masterlpalgo)))
    getslavealgorithms!(algo.masterlpalgo, reform, slaves)
end

function run!(algo::RestrMasterLPConquer, reform::Reformulation, input::ConquerInput)::ConquerOutput
    return ConquerOutput(
        run!(algo.masterlpalgo, getmaster(reform), LpFormInput()), record!(reform)
    )
end


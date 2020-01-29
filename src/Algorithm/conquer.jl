using ..Coluna # to remove when merging to the master branch


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

"""
    ConquerOutput

    Output of a conquer algorithm used by the tree search algorithm.
    Contain current incumbents, infeasibility status, and the record of its storage.
"""
struct ConquerOutput <: AbstractOutput 
    incumb::Incumbents
    record::ConquerRecord
    infeasibleflag::Bool
end

getincumbents(output::ConquerOutput) = output.incumb
getrecord(output::ConquerOutput) = output.record
getinfeasibleflag(output::ConquerOutput) = output.infeasibleflag


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


####################################################################
#                      Node
####################################################################

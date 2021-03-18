@enum(RecordAccessMode, READ_AND_WRITE, READ_ONLY, NOT_USED)

"""
    About records
    --------------

    Records keep user data (a model) and computed data between different runs 
    of an algorithm or between runs of different algorithms. 
    Models are records themselves. Each record is associated with a
    model. Thus a record adds computed data to a model.  

    Record states are useful to store states of records at some point 
    of the calculation flow so that we can later return to this point and 
    restore the records. For example, the calculation flow may return to
    some saved node in the search tree.

    Some records can have different parts which are stored in different 
    record states. Thus, we operate with triples (model, record, record state).
    For every model there may be only one record for each couple 
    (record type, record state type). 
    
    To store all records of a data, we use functions 
    "store_states!(::AbstractData)::RecordStatesVector" or
    "copy_states(::RecordStatesVector)::RecordStatesVector"
  
    Every stored state should be removed or restored using functions 
    "restore_states!(::RecordStatesVector,::RecordsUsageDict)" 
    and "remove_states!(::RecordStatesVector)"
  
    After storing current states, if we write to some record, we should restore 
    it for writing using "restore_states!(...)" 
    After storing current states, if we read from a record, 
    no particular precautions should be taken.   
"""

"""
    AbstractRecord 

A record contains information about a model or the execution of an algorithm.

For every record a constructor should be defined which
takes a model as a parameter. This constructor is 
called when the formulation is completely known so the data
can be safely computed.
"""
abstract type AbstractRecord end

"""
    AbstractRecordState

A record state is the particular condition that a record is in at a specific time
of the execution of Coluna.
    
For each record state, a constructor should be defined which
takes a model and a record as parameters. This constructor
is called during storing a record. 
"""
abstract type AbstractRecordState end

"""
    restorefromstate!(model, record, record_state)

This method should be defined for every triple (model type, record type, record state type)
used by an algorithm.     
"""
restorefromstate!(model::AbstractModel, record::AbstractRecord, state::AbstractRecordState) =
    error(string(
        "restorefromstate! not defined for model type $(typeof(model)), ",
        "record type $(typeof(record)), and record state type $(typeof(state))"
    ))    


"""
    EmptyRecordState

If a record is not changed after initialization, then 
the empty record state should be used with it.
"""

struct EmptyRecordState <: AbstractRecordState end

EmptyRecordState(model::AbstractModel, record::AbstractRecord) = nothing

restorefromstate!(::AbstractModel, ::AbstractRecord, ::EmptyRecordState) = nothing

# RecordTypePair = Pair{Type{<:AbstractRecord}, Type{<:AbstractRecordState}}.
# see https://github.com/atoptima/Coluna.jl/pull/323#discussion_r418972805
const RecordTypePair = Pair{DataType, DataType}

# TO DO : replace with the set of RecordTypePair, should only contain records which should 
#         be restored for writing (all other records are restored anyway but just for reading)
const RecordsUsageDict = Dict{Tuple{AbstractModel, RecordTypePair}, RecordAccessMode}

function Base.show(io::IO, usagedict::RecordsUsageDict)
    print(io, "record usage dict [")
    for usage in usagedict
        print(io, " (", typeof(usage[1][1]), ", ", usage[1][2], ") => ", usage[2])
    end
    print(io, " ]")
end

"""
    add_record_pair_usage!(::RecordsUsageDict, ::AbstractModel, ::RecordTypePair, ::RecordAccessMode)

An auxiliary function to be used when adding record usage to a RecordUsageDict
"""
function add_record_pair_usage!(
    dict::RecordsUsageDict, model::AbstractModel, pair::RecordTypePair, mode::RecordAccessMode
)
    current_mode = get(dict, (model, pair), NOT_USED) 
    if current_mode == NOT_USED && mode != NOT_USED
        dict[(model, pair)] = mode
    else
        if mode == READ_AND_WRITE && current_mode == READ_ONLY
            dict[(model, pair)] = READ_AND_WRITE
        end    
    end
end

"""
    RecordStateContainer

This container keeps additional record state information needed for 
keeping the number of times the state has been stored. When 
this number drops to zero, the state can be deleted. 
"""

const StateId = Int

mutable struct RecordStateContainer{SS<:AbstractRecordState}
    id::StateId
    participation::Int
    state::Union{Nothing, SS}
end

RecordStateContainer{SS}(stateid::StateId, participation::Int) where {SS<:AbstractRecordState} =
    RecordStateContainer{SS}(stateid, participation, nothing)

getstateid(ssc::RecordStateContainer) = ssc.id
stateisempty(ssc::RecordStateContainer) = ssc.state === nothing
getparticipation(ssc::RecordStateContainer) = ssc.participation
getstate(ssc::RecordStateContainer) = ssc.state
increaseparticipation!(ssc::RecordStateContainer) = ssc.participation += 1
decreaseparticipation!(ssc::RecordStateContainer) = ssc.participation -= 1

function setstate!(ssc::RecordStateContainer{SS}, state_to_set::SS) where {SS<:AbstractRecordState}
    ssc.state = state_to_set
end

function Base.show(io::IO, statecont::RecordStateContainer{SS}) where {SS<:AbstractRecordState}
    print(io, "state ", remove_until_last_point(string(SS)))
    print(io, " with id=", getstateid(statecont), " part=", getparticipation(statecont))
    if getstate(statecont) === nothing
        print(io, " empty")
    else
        print(io, " ", getstate(statecont))
    end
end

"""
    EmptyRecordStateContainer
"""

const EmptyRecordStateContainer = RecordStateContainer{EmptyRecordState}

EmptyRecordStateContainer(stateid::StateId, participation::Int) =
    EmptyRecordStateContainer(1, 0)

getstateid(essc::EmptyRecordStateContainer) = 1
stateisempty(essc::EmptyRecordStateContainer) = true 
getparticipation(essc::EmptyRecordStateContainer) = 0
increaseparticipation!(essc::EmptyRecordStateContainer) = nothing
decreaseparticipation!(essc::EmptyRecordStateContainer) = nothing

"""
    StorageContainer

This container keeps records and all states which have been 
stored. It implements storing and restoring states in an 
efficient way. 
"""

mutable struct StorageContainer{M<:AbstractModel, S<:AbstractRecord, SS<:AbstractRecordState}
    model::M
    curstatecont::RecordStateContainer{SS}
    maxstateid::StateId
    record::S
    typepair::RecordTypePair
    statesdict::Dict{StateId, RecordStateContainer{SS}}
end 

const RecordStatesVector = Vector{Pair{StorageContainer, StateId}}

const StorageDict = Dict{RecordTypePair, StorageContainer}

function StorageContainer{M,S,SS}(model::M) where {M,S,SS}
    return StorageContainer{M,S,SS}(
        model, RecordStateContainer{SS}(1, 0), 1, S(model), 
        S => SS, Dict{StateId, RecordStateContainer{SS}}()
    )
end    

getmodel(sc::StorageContainer) = sc.model
getcurstatecont(sc::StorageContainer) = sc.curstatecont
getmaxstateid(sc::StorageContainer) = sc.maxstateid
getstatesdict(sc::StorageContainer) = sc.statesdict
getrecord(sc::StorageContainer) = sc.record
gettypepair(sc::StorageContainer) = sc.typepair

function Base.show(io::IO, storagecont::StorageContainer)
    print(io, "record (")
    print(IOContext(io, :compact => true), getmodel(storagecont))
    (RecordType, RecordStateType) = gettypepair(storagecont)    
    print(io, ", ", remove_until_last_point(string(RecordType)))    
    print(io, ", ", remove_until_last_point(string(RecordStateType)), ")")        
end

function setcurstate!(
    storagecont::StorageContainer{M,S,SS}, statecont::RecordStateContainer{SS}
) where {M,S,SS} 
    # we delete the current state container from the dictionary if necessary
    curstatecont = getcurstatecont(storagecont)
    if !stateisempty(curstatecont) && getparticipation(curstatecont) == 0
        delete!(getstatesdict(storagecont), getstateid(curstatecont))
        @logmsg LogLevel(-2) string("Removed state with id ", getstateid(curstatecont), " for ", storagecont)
    end
    storagecont.curstatecont = statecont
    if getmaxstateid(storagecont) < getstateid(statecont) 
        storagecont.maxstateid = getstateid(statecont)
    end
end

function increaseparticipation!(storagecont::StorageContainer, stateid::StateId)
    statecont = getcurstatecont(storagecont)
    if (getstateid(statecont) == stateid)
        increaseparticipation!(statecont)
    else
        statesdict = getstatesdict(storagecont)
        if !haskey(statesdict, stateid) 
            error(string("State with id $stateid does not exist for ", storagecont))
        end
        increaseparticipation!(statesdict[stateid])
    end
end

function retrieve_from_statesdict(storagecont::StorageContainer, stateid::StateId)
    statesdict = getstatesdict(storagecont)
    if !haskey(statesdict, stateid)
        error(string("State with id $stateid does not exist for ", storagecont))
    end
    statecont = statesdict[stateid]
    decreaseparticipation!(statecont)
    if getparticipation(statecont) < 0
        error(string("Participation is below zero for state with id $stateid of ", storagecont))
    end
    return statecont
end

function save_to_statesdict!(
    storagecont::StorageContainer{M,S,SS}, statecont::RecordStateContainer{SS}
) where {M,S,SS}
    if getparticipation(statecont) > 0 && stateisempty(statecont)
        state = SS(getmodel(storagecont), getrecord(storagecont))
        @logmsg LogLevel(-2) string("Created state with id ", getstateid(statecont), " for ", storagecont)
        setstate!(statecont, state)
        statesdict = getstatesdict(storagecont)
        statesdict[getstateid(statecont)] = statecont
    end
end

function storestate!(storagecont::StorageContainer)::StateId 
    statecont = getcurstatecont(storagecont)
    increaseparticipation!(statecont)
    return getstateid(statecont)
end

function restorestate!(
    storagecont::StorageContainer{M,S,SS}, stateid::StateId, mode::RecordAccessMode
) where {M,S,SS}
    statecont = getcurstatecont(storagecont)
    if getstateid(statecont) == stateid 
        decreaseparticipation!(statecont)
        if getparticipation(statecont) < 0
            error(string("Participation is below zero for state with id $stateid of ", getnicename(storagecont)))
        end
        if mode == READ_AND_WRITE 
            save_to_statesdict!(storagecont, statecont)
            statecont = RecordStateContainer{SS}(getmaxstateid(storagecont) + 1, 0)
            setcurstate!(storagecont, statecont)
        end
        return
    elseif mode != NOT_USED
        # we save current state to dictionary if necessary
        save_to_statesdict!(storagecont, statecont)
    end

    statecont = retrieve_from_statesdict(storagecont, stateid)

    if mode == NOT_USED
        if !stateisempty(statecont) && getparticipation(statecont) == 0
            delete!(getstatesdict(storagecont), getstateid(statecont))
            @logmsg LogLevel(-2) string("Removed state with id ", getstateid(statecont), " for ", storagecont)
        end
    else 
        restorefromstate!(getmodel(storagecont), getrecord(storagecont), getstate(statecont))
        @logmsg LogLevel(-2) string("Restored state with id ", getstateid(statecont), " for ", storagecont)
        if mode == READ_AND_WRITE 
            statecont = RecordStateContainer{SS}(getmaxstateid(storagecont) + 1, 0)
        end 
        setcurstate!(storagecont, statecont)
    end
end

"""
    Record functions used by Coluna
"""

# this is a "lighter" alternative to restore_states!() function below
# not used for the moment as it has impact on the code readability
# we keep this function for a while for the case when function restore_states!()
# happens to be a bottleneck
# function reserve_for_writing!(storagecont::StorageContainer{M,S,SS}) where {M,S,SS}
#     statecont = getcurstatecont(storagecont)
#     save_to_statesdict!(storagecont, statecont)
#     statecont = RecordStateContainer{SS}(getmaxstateid(storagecont) + 1, 0)
#     setcurstate!(storagecont, statecont)
# end

function restore_states!(ssvector::RecordStatesVector, records_to_restore::RecordsUsageDict)
    TO.@timeit Coluna._to "Restore/remove states" begin
        for (storagecont, stateid) in ssvector
            mode = get(
                records_to_restore, 
                (getmodel(storagecont), gettypepair(storagecont)), 
                READ_ONLY
            )
            restorestate!(storagecont, stateid, mode)
        end
    end    
    empty!(ssvector) # vector of states should be emptied 
end

function remove_states!(ssvector::RecordStatesVector)
    TO.@timeit Coluna._to "Restore/remove states" begin
        for (storagecont, stateid) in ssvector
            restorestate!(storagecont, stateid, NOT_USED)
        end
    end
    empty!(ssvector) # vector of states should be emptied 
end

function copy_states(states::RecordStatesVector)::RecordStatesVector
    statescopy = RecordStatesVector()
    for (storagecont, stateid) in states
        push!(statescopy, storagecont => stateid)
        increaseparticipation!(storagecont, stateid)
    end
    return statescopy
end

function check_record_states_participation(storagecont::StorageContainer)
    curstatecont = getcurstatecont(storagecont)
    if getparticipation(curstatecont) > 0
        @warn string("Positive participation of state ", curstatecont)
    end
    statesdict = getstatesdict(storagecont)
    for (stateid, statecont) in statesdict
        if getparticipation(statecont) > 0
            @warn string("Positive participation of state ", statecont)
        end
    end
end

"""
    IMPORTANT!

    Every stored or copied state should be either restored or removed so that it's 
    participation is correctly computed and memory correctly controlled
"""



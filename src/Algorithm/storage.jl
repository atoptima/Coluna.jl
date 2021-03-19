@enum(UnitAccessMode, READ_AND_WRITE, READ_ONLY, NOT_USED)

"""
    About storage units
    -------------------

    Storage units keep user data (a model) and computed data between different runs 
    of an algorithm or between runs of different algorithms. 
    Models are storage units themselves. Each unit is associated with a
    model. Thus a unit adds computed data to a model.  

    Records are useful to store states of storage units at some point 
    of the calculation flow so that we can later return to this point and 
    restore the units. For example, the calculation flow may return to
    some saved node in the search tree.

    Some units can have different parts which are stored in different 
    records. Thus, we operate with triples (model, unit, record).
    For every model there may be only one unit for each couple 
    (unit type, record type). 
    
    To store all storage units of a data, we use functions 
    "store_records!(::AbstractData)::RecordsVector" or
    "copy_records(::RecordsVector)::RecordsVector"
  
    Every stored record should be removed or restored using functions 
    "restore_records!(::RecordsVector,::UnitsUsageDict)" 
    and "remove_records!(::RecordsVector)"
  
    After recording current states, if we write to some storage unit, we should restore 
    it for writing using "restore_records!(...)" 
    After recording current states, if we read from a storage unit, 
    no particular precautions should be taken.   
"""

"""
    AbstractStorageUnit 

A storage unit contains information about a model or the execution of an algorithm.

For every unit a constructor should be defined which
takes a model as a parameter. This constructor is 
called when the formulation is completely known so the data
can be safely computed.
"""
abstract type AbstractStorageUnit end

"""
    AbstractRecord

A record is the particular condition that a storage unit is in at a specific time
of the execution of Coluna.
    
For each record, a constructor should be defined which
takes a model and a unit as parameters. This constructor
is called during storing a unit. 
"""
abstract type AbstractRecord end

"""
    restore_from_record!(model, unit, record_state)

This method should be defined for every triple (model type, unit type, record type)
used by an algorithm.     
"""
restore_from_record!(model::AbstractModel, unit::AbstractStorageUnit, state::AbstractRecord) =
    error(string(
        "restore_from_record! not defined for model type $(typeof(model)), ",
        "unit type $(typeof(unit)), and record type $(typeof(state))"
    ))    


"""
    EmptyRecord

If a storage unit is not changed after initialization, then 
the empty record should be used with it.
"""

struct EmptyRecord <: AbstractRecord end

EmptyRecord(model::AbstractModel, unit::AbstractStorageUnit) = nothing

restore_from_record!(::AbstractModel, ::AbstractStorageUnit, ::EmptyRecord) = nothing

# UnitTypePair = Pair{Type{<:AbstractStorageUnit}, Type{<:AbstractRecord}}.
# see https://github.com/atoptima/Coluna.jl/pull/323#discussion_r418972805
const UnitTypePair = Pair{DataType, DataType}

# TO DO : replace with the set of UnitTypePair, should only contain records which should 
#         be restored for writing (all other records are restored anyway but just for reading)
const UnitsUsageDict = Dict{Tuple{AbstractModel, UnitTypePair}, UnitAccessMode}

function Base.show(io::IO, usagedict::UnitsUsageDict)
    print(io, "storage units usage dict [")
    for usage in usagedict
        print(io, " (", typeof(usage[1][1]), ", ", usage[1][2], ") => ", usage[2])
    end
    print(io, " ]")
end

"""
    add_unit_pair_usage!(::UnitsUsageDict, ::AbstractModel, ::UnitTypePair, ::UnitAccessMode)

An auxiliary function to be used when adding unit usage to a UnitUsageDict
"""
function add_unit_pair_usage!(
    dict::UnitsUsageDict, model::AbstractModel, pair::UnitTypePair, mode::UnitAccessMode
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
    RecordContainer

This container keeps additional record information needed for 
keeping the number of times the state has been stored. When 
this number drops to zero, the state can be deleted. 
"""

const RecordId = Int

mutable struct RecordContainer{SS<:AbstractRecord}
    id::RecordId
    participation::Int
    state::Union{Nothing, SS}
end

RecordContainer{SS}(recordid::RecordId, participation::Int) where {SS<:AbstractRecord} =
    RecordContainer{SS}(recordid, participation, nothing)

getrecordid(ssc::RecordContainer) = ssc.id
stateisempty(ssc::RecordContainer) = ssc.state === nothing
getparticipation(ssc::RecordContainer) = ssc.participation
getstate(ssc::RecordContainer) = ssc.state
increaseparticipation!(ssc::RecordContainer) = ssc.participation += 1
decreaseparticipation!(ssc::RecordContainer) = ssc.participation -= 1

function setstate!(ssc::RecordContainer{SS}, state_to_set::SS) where {SS<:AbstractRecord}
    ssc.state = state_to_set
end

function Base.show(io::IO, statecont::RecordContainer{SS}) where {SS<:AbstractRecord}
    print(io, "state ", remove_until_last_point(string(SS)))
    print(io, " with id=", getrecordid(statecont), " part=", getparticipation(statecont))
    if getstate(statecont) === nothing
        print(io, " empty")
    else
        print(io, " ", getstate(statecont))
    end
end

"""
    EmptyRecordContainer
"""

const EmptyRecordContainer = RecordContainer{EmptyRecord}

EmptyRecordContainer(recordid::RecordId, participation::Int) =
    EmptyRecordContainer(1, 0)

getrecordid(essc::EmptyRecordContainer) = 1
stateisempty(essc::EmptyRecordContainer) = true 
getparticipation(essc::EmptyRecordContainer) = 0
increaseparticipation!(essc::EmptyRecordContainer) = nothing
decreaseparticipation!(essc::EmptyRecordContainer) = nothing

"""
    StorageContainer

This container keeps storage units and all records which have been 
stored. It implements storing and restoring records of units in an 
efficient way. 
"""

mutable struct StorageContainer{M<:AbstractModel, S<:AbstractStorageUnit, SS<:AbstractRecord}
    model::M
    curstatecont::RecordContainer{SS}
    maxrecordid::RecordId
    storage_unit::S
    typepair::UnitTypePair
    recordsdict::Dict{RecordId, RecordContainer{SS}}
end 

const RecordsVector = Vector{Pair{StorageContainer, RecordId}}

const StorageDict = Dict{UnitTypePair, StorageContainer}

function StorageContainer{M,S,SS}(model::M) where {M,S,SS}
    return StorageContainer{M,S,SS}(
        model, RecordContainer{SS}(1, 0), 1, S(model), 
        S => SS, Dict{RecordId, RecordContainer{SS}}()
    )
end    

getmodel(sc::StorageContainer) = sc.model
getcurstatecont(sc::StorageContainer) = sc.curstatecont
getmaxrecordid(sc::StorageContainer) = sc.maxrecordid
getrecordsdict(sc::StorageContainer) = sc.recordsdict
getunit(sc::StorageContainer) = sc.storage_unit
gettypepair(sc::StorageContainer) = sc.typepair

function Base.show(io::IO, storagecont::StorageContainer)
    print(io, "unit (")
    print(IOContext(io, :compact => true), getmodel(storagecont))
    (StorageUnitType, RecordType) = gettypepair(storagecont)    
    print(io, ", ", remove_until_last_point(string(StorageUnitType)))    
    print(io, ", ", remove_until_last_point(string(RecordType)), ")")        
end

function setcurstate!(
    storagecont::StorageContainer{M,S,SS}, statecont::RecordContainer{SS}
) where {M,S,SS} 
    # we delete the current state container from the dictionary if necessary
    curstatecont = getcurstatecont(storagecont)
    if !stateisempty(curstatecont) && getparticipation(curstatecont) == 0
        delete!(getrecordsdict(storagecont), getrecordid(curstatecont))
        @logmsg LogLevel(-2) string("Removed state with id ", getrecordid(curstatecont), " for ", storagecont)
    end
    storagecont.curstatecont = statecont
    if getmaxrecordid(storagecont) < getrecordid(statecont) 
        storagecont.maxrecordid = getrecordid(statecont)
    end
end

function increaseparticipation!(storagecont::StorageContainer, recordid::RecordId)
    statecont = getcurstatecont(storagecont)
    if (getrecordid(statecont) == recordid)
        increaseparticipation!(statecont)
    else
        recordsdict = getrecordsdict(storagecont)
        if !haskey(recordsdict, recordid) 
            error(string("State with id $recordid does not exist for ", storagecont))
        end
        increaseparticipation!(recordsdict[recordid])
    end
end

function retrieve_from_recordsdict(storagecont::StorageContainer, recordid::RecordId)
    recordsdict = getrecordsdict(storagecont)
    if !haskey(recordsdict, recordid)
        error(string("State with id $recordid does not exist for ", storagecont))
    end
    statecont = recordsdict[recordid]
    decreaseparticipation!(statecont)
    if getparticipation(statecont) < 0
        error(string("Participation is below zero for state with id $recordid of ", storagecont))
    end
    return statecont
end

function save_to_recordsdict!(
    storagecont::StorageContainer{M,S,SS}, statecont::RecordContainer{SS}
) where {M,S,SS}
    if getparticipation(statecont) > 0 && stateisempty(statecont)
        state = SS(getmodel(storagecont), getunit(storagecont))
        @logmsg LogLevel(-2) string("Created state with id ", getrecordid(statecont), " for ", storagecont)
        setstate!(statecont, state)
        recordsdict = getrecordsdict(storagecont)
        recordsdict[getrecordid(statecont)] = statecont
    end
end

function store_record!(storagecont::StorageContainer)::RecordId 
    statecont = getcurstatecont(storagecont)
    increaseparticipation!(statecont)
    return getrecordid(statecont)
end

function restore_record!(
    storagecont::StorageContainer{M,S,SS}, recordid::RecordId, mode::UnitAccessMode
) where {M,S,SS}
    statecont = getcurstatecont(storagecont)
    if getrecordid(statecont) == recordid 
        decreaseparticipation!(statecont)
        if getparticipation(statecont) < 0
            error(string("Participation is below zero for state with id $recordid of ", getnicename(storagecont)))
        end
        if mode == READ_AND_WRITE 
            save_to_recordsdict!(storagecont, statecont)
            statecont = RecordContainer{SS}(getmaxrecordid(storagecont) + 1, 0)
            setcurstate!(storagecont, statecont)
        end
        return
    elseif mode != NOT_USED
        # we save current state to dictionary if necessary
        save_to_recordsdict!(storagecont, statecont)
    end

    statecont = retrieve_from_recordsdict(storagecont, recordid)

    if mode == NOT_USED
        if !stateisempty(statecont) && getparticipation(statecont) == 0
            delete!(getrecordsdict(storagecont), getrecordid(statecont))
            @logmsg LogLevel(-2) string("Removed state with id ", getrecordid(statecont), " for ", storagecont)
        end
    else 
        restore_from_record!(getmodel(storagecont), getunit(storagecont), getstate(statecont))
        @logmsg LogLevel(-2) string("Restored state with id ", getrecordid(statecont), " for ", storagecont)
        if mode == READ_AND_WRITE 
            statecont = RecordContainer{SS}(getmaxrecordid(storagecont) + 1, 0)
        end 
        setcurstate!(storagecont, statecont)
    end
end

"""
    Storage unit functions used by Coluna
"""

# this is a "lighter" alternative to restore_records!() function below
# not used for the moment as it has impact on the code readability
# we keep this function for a while for the case when function restore_records!()
# happens to be a bottleneck
# function reserve_for_writing!(storagecont::StorageContainer{M,S,SS}) where {M,S,SS}
#     statecont = getcurstatecont(storagecont)
#     save_to_recordsdict!(storagecont, statecont)
#     statecont = RecordContainer{SS}(getmaxrecordid(storagecont) + 1, 0)
#     setcurstate!(storagecont, statecont)
# end

function restore_records!(records::RecordsVector, units_to_restore::UnitsUsageDict)
    TO.@timeit Coluna._to "Restore/remove records" begin
        for (storagecont, recordid) in records
            mode = get(
                units_to_restore, 
                (getmodel(storagecont), gettypepair(storagecont)), 
                READ_ONLY
            )
            restore_record!(storagecont, recordid, mode)
        end
    end    
    empty!(records) # vector of records should be emptied 
end

function remove_records!(records::RecordsVector)
    TO.@timeit Coluna._to "Restore/remove records" begin
        for (storagecont, recordid) in records
            restore_record!(storagecont, recordid, NOT_USED)
        end
    end
    empty!(records) # vector of records should be emptied 
end

function copy_records(records::RecordsVector)::RecordsVector
    recordscopy = RecordsVector()
    for (storagecont, recordid) in records
        push!(recordscopy, storagecont => recordid)
        increaseparticipation!(storagecont, recordid)
    end
    return recordscopy
end

function check_records_participation(storagecont::StorageContainer)
    curstatecont = getcurstatecont(storagecont)
    if getparticipation(curstatecont) > 0
        @warn string("Positive participation of state ", curstatecont)
    end
    recordsdict = getrecordsdict(storagecont)
    for (recordid, statecont) in recordsdict
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



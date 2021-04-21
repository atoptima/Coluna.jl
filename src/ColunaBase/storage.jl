@enum(UnitAccessMode, READ_AND_WRITE, READ_ONLY, NOT_USED)

"""
About storage units
-------------------

Storage units keep user data (a model) and computed data between different runs 
of an algorithm or between runs of different algorithms. 
Models are storage units themselves. Each unit is associated with a
model. Thus a unit adds computed data to a model.  

Records are useful to store records of storage units at some point 
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
"restore_from_records!(::RecordsVector,::UnitsUsageDict)" 
and "remove_records!(::RecordsVector)"

After recording current records, if we write to some storage unit, we should restore 
it for writing using "restore_from_records!(...)" 
After recording current records, if we read from a storage unit, 
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
    restore_from_record!(model, unit, record)

This method should be defined for every triple (model type, unit type, record type)
used by an algorithm.     
"""
restore_from_record!(model::AbstractModel, unit::AbstractStorageUnit, record::AbstractRecord) =
    error(string(
        "restore_from_record! not defined for model type $(typeof(model)), ",
        "unit type $(typeof(unit)), and record type $(typeof(record))"
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
const UnitTypePair = Pair{DataType,DataType}

# TO DO : replace with the set of UnitTypePair, should only contain records which should 
#         be restored for writing (all other records are restored anyway but just for reading)
const UnitsUsageDict = Dict{Tuple{AbstractModel,UnitTypePair},UnitAccessMode}

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
    RecordWrapper

It wraps and contains additional information about a record.
The participation is equal to the number of times the record has been stored.
When the participation drops to zero, the record can be deleted. 
"""

const RecordId = Int

mutable struct RecordWrapper{R <: AbstractRecord}
    id::RecordId
    participation::Int
    record::Union{R,Nothing}
end

RecordWrapper{R}(recordid::RecordId, participation::Int) where {R <: AbstractRecord} =
    RecordWrapper{R}(recordid, participation, nothing)

getrecordid(rw::RecordWrapper) = rw.id
recordisempty(rw::RecordWrapper) = rw.record === nothing
getparticipation(rw::RecordWrapper) = rw.participation
getrecord(rw::RecordWrapper) = rw.record
increaseparticipation!(rw::RecordWrapper) = rw.participation += 1
decreaseparticipation!(rw::RecordWrapper) = rw.participation -= 1

function setrecord!(rw::RecordWrapper{R}, record_to_set::R) where {R <: AbstractRecord}
    rw.record = record_to_set
end

function Base.show(io::IO, rw::RecordWrapper{R}) where {R <: AbstractRecord}
    print(io, "record ", remove_until_last_point(string(R)))
    print(io, " with id=", getrecordid(rw), " part=", getparticipation(rw))
    if getrecord(rw) === nothing
        print(io, " empty")
    else
        print(io, " ", getrecord(rw))
    end
end

"""
    EmptyRecordWrapper
"""

const EmptyRecordWrapper = RecordWrapper{EmptyRecord}

EmptyRecordWrapper(recordid::RecordId, participation::Int) =
    EmptyRecordWrapper(1, 0)

getrecordid(erw::EmptyRecordWrapper) = 1
recordisempty(erw::EmptyRecordWrapper) = true 
getparticipation(erw::EmptyRecordWrapper) = 0
increaseparticipation!(erw::EmptyRecordWrapper) = nothing
decreaseparticipation!(erw::EmptyRecordWrapper) = nothing

"""
    StorageUnitWrapper

This container keeps a storage unit and all records which have been 
stored. It implements storing and restoring records of units in an 
efficient way. 
"""

mutable struct StorageUnitWrapper{M <: AbstractModel,SU <: AbstractStorageUnit,R <: AbstractRecord}
    model::M
    cur_record::RecordWrapper{R}
    maxrecordid::RecordId
    storage_unit::SU
    typepair::UnitTypePair
    recordsdict::Dict{RecordId,RecordWrapper{R}}
end

getunit(s::StorageUnitWrapper) = s.storage_unit # needed by Algorithms

const RecordsVector = Vector{Pair{StorageUnitWrapper,RecordId}}

const StorageDict = Dict{UnitTypePair,StorageUnitWrapper}

function StorageUnitWrapper{M,SU,R}(model::M) where {M,SU,R}
    return StorageUnitWrapper{M,SU,R}(
        model, RecordWrapper{R}(1, 0), 1, SU(model), 
        SU => R, Dict{RecordId,RecordWrapper{R}}()
    )
end    

function Base.show(io::IO, storage::StorageUnitWrapper)
    print(io, "unit (")
    print(IOContext(io, :compact => true), storage.model)
    (StorageUnitType, RecordType) = storage.typepair    
    print(io, ", ", remove_until_last_point(string(StorageUnitType)))    
    print(io, ", ", remove_until_last_point(string(RecordType)), ")")        
end

function setcurrecord!(
    storage::StorageUnitWrapper{M,SU,R}, record::RecordWrapper{R}
) where {M,SU,R} 
    # we delete the current record container from the dictionary if necessary
    if !recordisempty(storage.cur_record) && getparticipation(storage.cur_record) == 0
        delete!(storage.recordsdict, getrecordid(storage.cur_record))
        # @logmsg LogLevel(-2) string("Removed record with id ", getrecordid(currecord), " for ", storage)
    end
    storage.cur_record = record
    if storage.maxrecordid < getrecordid(record) 
        storage.maxrecordid = getrecordid(record)
    end
end

function increaseparticipation!(storage::StorageUnitWrapper, recordid::RecordId)
    record = storage.cur_record
    if getrecordid(record) == recordid
        increaseparticipation!(record)
    else
        if !haskey(storage.recordsdict, recordid) 
            error(string("State with id $recordid does not exist for ", storage))
        end
        increaseparticipation!(storage.recordsdict[recordid])
    end
end

function retrieve_from_recordsdict(storage::StorageUnitWrapper, recordid::RecordId)
    if !haskey(storage.recordsdict, recordid)
        error(string("State with id $recordid does not exist for ", storage))
    end
    record = storage.recordsdict[recordid]
    decreaseparticipation!(record)
    if getparticipation(record) < 0
        error(string("Participation is below zero for record with id $recordid of ", storage))
    end
    return record
end

function save_to_recordsdict!(
    storage::StorageUnitWrapper{M,SU,R}, record::RecordWrapper{R}
) where {M,SU,R}
    if getparticipation(record) > 0 && recordisempty(record)
        record_content = R(storage.model, storage.storage_unit)
        # @logmsg LogLevel(-2) string("Created record with id ", getrecordid(record), " for ", storage)
        setrecord!(record, record_content)
        storage.recordsdict[getrecordid(record)] = record
    end
end

function store_record!(storage::StorageUnitWrapper)::RecordId 
    increaseparticipation!(storage.cur_record)
    return getrecordid(storage.cur_record)
end

function restore_from_record!(
    storage::StorageUnitWrapper{M,SU,R}, recordid::RecordId, mode::UnitAccessMode
) where {M,SU,R}
    record = storage.cur_record
    if getrecordid(record) == recordid 
        decreaseparticipation!(record)
        if getparticipation(record) < 0
            error(string("Participation is below zero for record with id $recordid of ", getnicename(storage)))
        end
        if mode == READ_AND_WRITE 
            save_to_recordsdict!(storage, record)
            record = RecordWrapper{R}(storage.maxrecordid + 1, 0)
            setcurrecord!(storage, record)
        end
        return
    elseif mode != NOT_USED
        # we save current record to dictionary if necessary
        save_to_recordsdict!(storage, record)
    end
    
    record = retrieve_from_recordsdict(storage, recordid)
    
    if mode == NOT_USED
        if !recordisempty(record) && getparticipation(record) == 0
            delete!(storage.recordsdict, getrecordid(record))
            # @logmsg LogLevel(-2) string("Removed record with id ", getrecordid(record), " for ", storage)
        end
    else 
        restore_from_record!(storage.model, storage.storage_unit, getrecord(record))
        # @logmsg LogLevel(-2) string("Restored record with id ", getrecordid(record), " for ", storage)
        if mode == READ_AND_WRITE 
            record = RecordWrapper{R}(storage.maxrecordid + 1, 0)
        end 
        setcurrecord!(storage, record)
    end
end

function check_records_participation(storage::StorageUnitWrapper)
    if getparticipation(storage.cur_record) > 0
        @warn string("Positive participation of record ", storage.cur_record)
    end
    for (recordid, record) in storage.recordsdict
        if getparticipation(record) > 0
            @warn string("Positive participation of record ", record)
        end
    end
end


"""
    Storage unit functions used by Coluna
"""

# this is a "lighter" alternative to `restore_from_records!` below
# not used for the moment as it has impact on the code readability
# we keep this function for a while for the case when `restore_from_records!`
# happens to be a bottleneck
# function reserve_for_writing!(storage::StorageUnitWrapper{M,SU,R}) where {M,SU,R}
#     save_to_recordsdict!(storage, storage.cur_record)
#     storage.cur_record = RecordWrapper{R}(storage.maxrecordid + 1, 0)
#     setcurrecord!(storage, storage.cur_record)
# end

function restore_from_records!(units_to_restore::UnitsUsageDict, records::RecordsVector)
    TO.@timeit Coluna._to "Restore/remove records" begin
        for (storage, recordid) in records
            mode = get(
                units_to_restore, 
                (storage.model, storage.typepair), 
                READ_ONLY
            )
            restore_from_record!(storage, recordid, mode)
        end
    end    
    empty!(records) # vector of records should be emptied 
end

function remove_records!(records::RecordsVector)
    TO.@timeit Coluna._to "Restore/remove records" begin
        for (storage, recordid) in records
            restore_from_record!(storage, recordid, NOT_USED)
        end
    end
    empty!(records) # vector of records should be emptied 
end

function copy_records(records::RecordsVector)::RecordsVector
    recordscopy = RecordsVector()
    for (storage, recordid) in records
        push!(recordscopy, storage => recordid)
        increaseparticipation!(storage, recordid)
    end
    return recordscopy
end

# store_records is missing.


"""
    IMPORTANT!

    Every stored or copied record should be either restored or removed so that it's 
    participation is correctly computed and memory correctly controlled
"""



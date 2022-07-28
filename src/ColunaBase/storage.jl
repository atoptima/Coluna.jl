@enum(UnitPermission, NOT_USED, READ_ONLY, READ_AND_WRITE)

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

After recording current records, if we write to some stora^ge unit, we should restore 
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

# this is the type of record associated to the storage unit
record_type(::Type{SU}) where {SU<:AbstractStorageUnit} = 
    error("Type of record contained by storage unit $(SU) not defined.")

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


# """
#     EmptyRecord

# If a storage unit is not changed after initialization, then 
# the empty record should be used with it.
# """

# struct EmptyRecord <: AbstractRecord end

# EmptyRecord(model::AbstractModel, unit::AbstractStorageUnit) = nothing

# restore_from_record!(::AbstractModel, ::AbstractStorageUnit, ::EmptyRecord) = nothing

# UnitType = Pair{Type{<:AbstractStorageUnit}, Type{<:AbstractRecord}}.
# see https://github.com/atoptima/Coluna.jl/pull/323#discussion_r418972805
const UnitType = DataType #Type{<:AbstractStorageUnit}

# TO DO : replace with the set of UnitType, should only contain records which should 
#         be restored for writing (all other records are restored anyway but just for reading)
#const UnitsUsageDict = Dict{Tuple{AbstractModel,UnitType},UnitPermission}

# TODO :
# function Base.show(io::IO, usagedict::UnitsUsageDict)
#     print(io, "storage units usage dict [")
#     for usage in usagedict
#         print(io, " (", typeof(usage[1][1]), ", ", usage[1][2], ") => ", usage[2])
#     end
#     print(io, " ]")
# end


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

# """
#     EmptyRecordWrapper
# """

# const EmptyRecordWrapper = RecordWrapper{EmptyRecord}

# EmptyRecordWrapper(recordid::RecordId, participation::Int) =
#     EmptyRecordWrapper(1, 0)

# getrecordid(erw::EmptyRecordWrapper) = 1
# recordisempty(erw::EmptyRecordWrapper) = true 
# getparticipation(erw::EmptyRecordWrapper) = 0
# increaseparticipation!(erw::EmptyRecordWrapper) = nothing
# decreaseparticipation!(erw::EmptyRecordWrapper) = nothing

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
    typepair::UnitType
    recordsdict::Dict{RecordId,RecordWrapper{R}}
end

function StorageUnitWrapper{M,SU,R}(model::M) where {M,SU,R}
    return StorageUnitWrapper{M,SU,R}(
        model, RecordWrapper{R}(1, 0), 1, SU(model), 
        SU, Dict{RecordId,RecordWrapper{R}}()
    )
end

const RecordsVector = Vector{Pair{StorageUnitWrapper,RecordId}}
struct Storage
    units::Dict{UnitType, StorageUnitWrapper}
end

Storage() = Storage(Dict{UnitType, StorageUnitWrapper}())

# TODO
# function Base.show(io::IO, storage::StorageUnitWrapper)
#     println(io, "todo.")
#     # print(io, "unit (")
#     # print(IOContext(io, :compact => true), storage.model)
#     # (StorageUnitType, RecordType) = storage.typepair    
#     # print(io, ", ", remove_until_last_point(string(StorageUnitType)))    
#     # print(io, ", ", remove_until_last_point(string(RecordType)), ")")        
# end

function setcurrecord!(
    storage::StorageUnitWrapper{M,SU,R}, record::RecordWrapper{R}
) where {M,SU,R} 
    # we delete the current record container from the dictionary if necessary
    if !recordisempty(storage.cur_record) && getparticipation(storage.cur_record) == 0
        delete!(storage.recordsdict, getrecordid(storage.cur_record))
    end
    storage.cur_record = record
    if storage.maxrecordid < getrecordid(record) 
        storage.maxrecordid = getrecordid(record)
    end
end

function _increaseparticipation!(storage::StorageUnitWrapper, recordid::RecordId)
    record = if getrecordid(storage.cur_record) === recordid
        storage.cur_record
    else
        get(storage.recordsdict, recordid, nothing)
    end

    if record === nothing
        error(string("Record with id $recordid does not exist for ", storage))
    end

    increaseparticipation!(record)
    return
end

# TODO : review
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

# TODO : review / refactor
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

# TODO : refactor
function store_record!(storage::StorageUnitWrapper)::RecordId 
    increaseparticipation!(storage.cur_record)
    return getrecordid(storage.cur_record)
end

# TODO: refactor
function restore_from_record!(
    storage::StorageUnitWrapper{M,SU,R}, recordid::RecordId, mode::UnitPermission
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
    for (_, record) in storage.recordsdict
        if getparticipation(record) > 0
            @warn string("Positive participation of record ", record)
        end
    end
end

#######

"""
    UnitsUsage()

Stores the access rights to some storage units.
"""
struct UnitsUsage
    permissions::Dict{StorageUnitWrapper,UnitPermission}
end

UnitsUsage() = UnitsUsage(Dict{StorageUnitWrapper,UnitPermission}())

"""
    set_permission!(units_usage, storage_unit, access_right)

Set the permission to a storage unit.
"""
function set_permission!(usages::UnitsUsage, unit::StorageUnitWrapper, mode::UnitPermission)
    current_mode = get(usages.permissions, unit, NOT_USED)
    new_mode = max(current_mode, mode)
    usages.permissions[unit] = new_mode
    return new_mode
end

"""
    get_permission(units_usage, storage_unit, default)

Return the permission to a storage unit or `default` if the storage unit has
no permission entered in `units_usage`.
"""
function get_permission(usages::UnitsUsage, unit::StorageUnitWrapper, default)
    return get(usages.permissions, unit, default)
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

function restore_from_records!(units_to_restore::UnitsUsage, records::RecordsVector)
    for (storage, recordid) in records
        mode = get_permission(units_to_restore, storage, READ_ONLY)
        restore_from_record!(storage, recordid, mode)
    end
    empty!(records)
    return
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
        _increaseparticipation!(storage, recordid)
    end
    return recordscopy
end

# store_records is missing.


"""
    IMPORTANT!

    Every stored or copied record should be either restored or removed so that it's 
    participation is correctly computed and memory correctly controlled
"""


#####

function getstorageunit(m::AbstractModel, SU::Type{<:AbstractStorageUnit})
    return getstoragewrapper(m, SU).storage_unit
end

function getstoragewrapper(m::AbstractModel, SU::Type{<:AbstractStorageUnit})
    storagecont = get(getstorage(m).units, SU, nothing)
    storagecont === nothing && error("No storage unit of type $SU in $(typeof(m)) with id $(getuid(m)).")
    return storagecont
end
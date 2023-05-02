
abstract type AbstractRecordUnit end

abstract type AbstractRecord end


# Interface to implement
@mustimplement "Storage" get_id(r::AbstractRecord) = nothing

"Creates a record of information from the model or a storage unit."
@mustimplement "Storage" record(::Type{<:AbstractRecord}, id::Int, model, su::AbstractRecordUnit) = nothing

"Restore information from the model or the storage unit that is recorded in a record."
@mustimplement "Storage" restore_from_record!(model, su::AbstractRecordUnit, r::AbstractRecord) = nothing

"Returns a storage unit from a given type."
@mustimplement "Storage" storage_unit(::Type{<:AbstractRecordUnit}, model) = nothing

mutable struct RecordUnitManager{Model,RecordType<:AbstractRecord,StorageUnitType<:AbstractRecordUnit}
    model::Model
    storage_unit::StorageUnitType
    active_record_id::Int
    function RecordUnitManager(::Type{StorageUnitType}, model::M) where {M,StorageUnitType<:AbstractRecordUnit}
        return new{M,record_type(StorageUnitType),StorageUnitType}(
            model, storage_unit(StorageUnitType, model), 0
        )
    end
end

# Interface
"Returns the type of record stored in a type of storage unit."
@mustimplement "Storage" record_type(::Type{<:AbstractRecordUnit}) = nothing

"Returns the type of storage unit that stores a type of record."
@mustimplement "Storage" storage_unit_type(::Type{<:AbstractRecord}) = nothing

struct Storage{ModelType}
    model::ModelType
    units::Dict{DataType,RecordUnitManager}
    Storage(model::M) where {M} = new{M}(model, Dict{DataType,RecordUnitManager}())
end

function _get_storage_unit_manager!(storage, ::Type{StorageUnitType}) where {StorageUnitType<:AbstractRecordUnit}
    storage_unit_manager = get(storage.units, StorageUnitType, nothing)
    if isnothing(storage_unit_manager)
        storage_unit_manager = RecordUnitManager(StorageUnitType, storage.model)
        storage.units[StorageUnitType] = storage_unit_manager
    end
    return storage_unit_manager
end

# Creates a new record from the current state of the model and the storage unit.
"""
    create_record(storage, storage_unit_type)

Returns a Record that contains a description of the state of the storage unit at the time 
when the method is called.
"""
function create_record(storage, ::Type{StorageUnitType}) where {StorageUnitType<:AbstractRecordUnit}
    storage_unit_manager = _get_storage_unit_manager!(storage, StorageUnitType)
    id = storage_unit_manager.active_record_id += 1
    return record(
        record_type(StorageUnitType),
        id,
        storage.model,
        storage_unit_manager.storage_unit
    )
end


function restore_from_record!(storage::Storage, record::RecordType) where {RecordType} 
    storage_unit_manager = _get_storage_unit_manager!(storage, storage_unit_type(RecordType))
    restore_from_record!(storage.model, storage_unit_manager.storage_unit, record)
    return true
end

# TODO: remove
function restore_from_record!(storage_manager, record::RecordType) where {RecordType}
    restore_from_record!(storage_manager.model, storage_manager.storage_unit, record)
    return true
end

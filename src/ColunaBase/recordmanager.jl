
abstract type AbstractNewStorageUnit end

abstract type AbstractNewRecord end


# Interface to implement
@mustimplement "Storage" get_id(r::AbstractNewRecord) = nothing

"Creates a record of information from the model or a storage unit."
@mustimplement "Storage" new_record(::Type{<:AbstractNewRecord}, id::Int, model, su::AbstractNewStorageUnit) = nothing

"Restore information from the model or the storage unit that is recorded in a record."
@mustimplement "Storage" restore_from_record!(model, su::AbstractNewStorageUnit, r::AbstractNewRecord) = nothing

"Returns a storage unit from a given type."
@mustimplement "Storage" new_storage_unit(::Type{<:AbstractNewStorageUnit}, model) = nothing

mutable struct NewStorageUnitManager{Model,RecordType<:AbstractNewRecord,StorageUnitType<:AbstractNewStorageUnit}
    model::Model
    storage_unit::StorageUnitType
    active_record_id::Int
    function NewStorageUnitManager(::Type{StorageUnitType}, model::M) where {M,StorageUnitType<:AbstractNewStorageUnit}
        return new{M,record_type(StorageUnitType),StorageUnitType}(
            model, new_storage_unit(StorageUnitType, model), 0
        )
    end
end

# Interface
"Returns the type of record stored in a type of storage unit."
@mustimplement "Storage" record_type(::Type{<:AbstractNewStorageUnit}) = nothing

"Returns the type of storage unit that stores a type of record."
@mustimplement "Storage" storage_unit_type(::Type{<:AbstractNewRecord}) = nothing

struct NewStorage{ModelType}
    model::ModelType
    units::Dict{DataType,NewStorageUnitManager}
    NewStorage(model::M) where {M} = new{M}(model, Dict{DataType,NewStorageUnitManager}())
end

function _get_storage_unit_manager!(storage, ::Type{StorageUnitType}) where {StorageUnitType<:AbstractNewStorageUnit}
    storage_unit_manager = get(storage.units, StorageUnitType, nothing)
    if isnothing(storage_unit_manager)
        storage_unit_manager = NewStorageUnitManager(StorageUnitType, storage.model)
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
function create_record(storage, ::Type{StorageUnitType}) where {StorageUnitType<:AbstractNewStorageUnit}
    storage_unit_manager = _get_storage_unit_manager!(storage, StorageUnitType)
    id = storage_unit_manager.active_record_id += 1
    return new_record(
        record_type(StorageUnitType),
        id,
        storage.model,
        storage_unit_manager.storage_unit
    )
end

"""
    restore_from_record!(storage, record)

Restores the state of the storage unit using the record that was previously generated.
"""
function restore_from_record!(storage::NewStorage, record::RecordType) where {RecordType} 
    storage_unit_manager = _get_storage_unit_manager!(storage, storage_unit_type(RecordType))
    restore_from_record!(storage.model, storage_unit_manager.storage_unit, record)
    return true
end

# TODO: remove
function restore_from_record!(storage_manager, record::RecordType) where {RecordType}
    restore_from_record!(storage_manager.model, storage_manager.storage_unit, record)
    return true
end

"""
A storage is a collection of storage units attached to a model.

A storage unit is a type that groups a set of entities for which we want to track the value 
over time. We can distinguish two kinds of storage units. First, storage units that track
entities of the model (e.g. status of branching constraints, lower and upper bounds of variables).
Second, storage units that track additional data (e.g. data of algorithms).

Since the values of the entities grouped in a storage unit vary over time, we want to save
them at specific steps of the calculation flow to restore them later. The storage interface
provides two methods to do both actions: 

- `save_record(storage, StorageUnitType)` returns a Record that contains a description of 
    the state of the storage unit at the time when the method is called
- `restore_from_record!(storage, record)` restores the state of the storage unit using the
    record that was previously generated.

From a developer point of view, there is a one-to-one correspondance between storage unit
types and record types. This correspondance is implemented by methods
`record_type(StorageUnitType)` and `storage_unit_type(RecordType)`.

The developer must also implement methods `new_storage_unit(StorageUnitType)` and
`new_record(RecordType, id, model, storage_unit)` that must call constructors of the custom 
storage unit and the one of its associated records. As you can see, arguments of
`new_record` allow the developer to record the state of entities from both the storage unit 
and the model.

At last, he must implement `restore_from_record(storage_unit, model, record)` to restore the
state of the entities represented by the storage unit. Entities can be in the storage unit,
the model, or in both of them.
"""
abstract type AbstractNewRecord end
abstract type AbstractNewStorageUnit end

# Interface to implement
function get_id(r::AbstractNewRecord)
    @warn "get_id(::$(typeof(r))) not implemented."
    return nothing
end

function new_record(::Type{RecordType}, id::Int, model, su::AbstractNewStorageUnit) where {RecordType}
    @warn "new_record(::Type{$RecordType}, ::$(typeof(id)), ::$(typeof(model)), ::$(typeof(su))) not implemented."
    return nothing
end

function restore_from_record!(model, su::AbstractNewStorageUnit, r::AbstractNewRecord)
    @warn "restore_from_record!(::$(typeof(model)), ::$(typeof(su)), ::$(typeof(r))) not implemented."
    return nothing
end

function new_storage_unit(::Type{StorageUnitType}) where {StorageUnitType}
    @warn "new_storage_unit(::Type{$StorageUnitType}) not implemented."
    return nothing
end

mutable struct NewStorageUnitManager{RecordType<:AbstractNewRecord,StorageUnitType<:AbstractNewStorageUnit}
    storage_unit::StorageUnitType
    active_record_id::Int
    function NewStorageUnitManager(::Type{StorageUnitType}) where {StorageUnitType}
        return new{record_type(StorageUnitType),StorageUnitType}(
            new_storage_unit(StorageUnitType), 0
        )
    end
end

# Interface
function record_type(::Type{StorageUnitType}) where {StorageUnitType}
    @warn "record_type(::Type{$StorageUnitType}) not implemented."
    return nothing
end

function storage_unit_type(::Type{RecordType}) where {RecordType}
    @warn "storage_unit_type(::Type{$RecordType}) not implemented."
    return nothing
end

struct NewStorage{ModelType}
    model::ModelType
    units::Dict{DataType,NewStorageUnitManager}
    NewStorage(model::M) where {M} = new{M}(model, Dict{DataType,NewStorageUnitManager}())
end

function _get_storage_unit_manager!(storage, ::Type{StorageUnitType}) where {StorageUnitType}
    storage_unit_manager = get(storage.units, StorageUnitType, nothing)
    if isnothing(storage_unit_manager)
        storage_unit_manager = NewStorageUnitManager(StorageUnitType)
        storage.units[StorageUnitType] = storage_unit_manager
    end
    return storage_unit_manager
end

# Creates a new record from the current state of the model and the storage unit.
function create_record(storage, ::Type{StorageUnitType}) where {StorageUnitType}
    storage_unit_manager = _get_storage_unit_manager!(storage, StorageUnitType)
    id = storage_unit_manager.active_record_id += 1
    return new_record(
        record_type(StorageUnitType),
        id,
        storage.model,
        storage_unit_manager.storage_unit
    )
end

# Restores the state of the model or the current unit from data contained in a record.
function restore_from_record!(storage, record::RecordType) where {RecordType} 
    storage_unit_manager = _get_storage_unit_manager!(storage, storage_unit_type(RecordType))
    restore_from_record!(storage.model, storage_unit_manager.storage_unit, record)
    return true
end

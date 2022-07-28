abstract type AbstractNewRecord end
abstract type AbstractNewUnitStorage end

# Interface to implement
function get_id(r::AbstractNewRecord)
    @warn "get_id(::$(typeof(r))) not implemented."
    return nothing
end

function new_record(::Type{RecordType}, id::Int, model, su::AbstractNewUnitStorage) where {RecordType}
    @warn "new_record(::Type{$RecordType}, ::$(typeof(id)), ::$(typeof(model)), ::$(typeof(su))) not implemented."
    return nothing
end

function restore_from_record!(model, su::AbstractNewUnitStorage, r::AbstractNewRecord)
    @warn "restore_from_record!(::$(typeof(model)), ::$(typeof(su)), ::$(typeof(r))) not implemented."
    return nothing
end

function new_unit_storage(::Type{UnitStorageType}) where {UnitStorageType}
    @warn "new_unit_storage(::Type{$UnitStorageType}) not implemented."
    return nothing
end

mutable struct NewUnitStorageManager{RecordType<:AbstractNewRecord,UnitStorageType<:AbstractNewUnitStorage}
    active_record::Union{RecordType,Nothing}
    unit_storage::UnitStorageType
    last_record_id::Int
    function NewUnitStorageManager(::Type{UnitStorageType}) where {UnitStorageType}
        return new{record_type(UnitStorageType),UnitStorageType}(
            nothing, new_unit_storage(UnitStorageType), 0
        )
    end
end

# Interface
function record_type(::Type{UnitStorageType}) where {UnitStorageType}
    @warn "record_type(::Type{$UnitStorageType}) not implemented."
    return nothing
end

function unit_storage_type(::Type{RecordType}) where {RecordType}
    @warn "unit_storage_type(::Type{$RecordType}) not implemented."
    return nothing
end

struct NewStorage{ModelType}
    model::ModelType
    units::Dict{DataType,NewUnitStorageManager}
    NewStorage(model::M) where {M} = new{M}(model, Dict{DataType,NewUnitStorageManager}())
end

function _get_unit_storage_manager!(storage, ::Type{UnitStorageType}) where {UnitStorageType}
    unit_storage_manager = get(storage.units, UnitStorageType, nothing)
    if isnothing(unit_storage_manager)
        unit_storage_manager = NewUnitStorageManager(UnitStorageType)
        storage.units[UnitStorageType] = unit_storage_manager
    end
    return unit_storage_manager
end

function set_active_record!(unit_storage_manager, record)
    unit_storage_manager.active_record = record
end

# Creates a new record from the current state of the model and the storage unit.
function create_record(storage, ::Type{UnitStorageType}) where {UnitStorageType}
    unit_storage_manager = _get_unit_storage_manager!(storage, UnitStorageType)
    id = unit_storage_manager.last_record_id += 1
    return new_record(
        record_type(UnitStorageType),
        id,
        storage.model,
        unit_storage_manager.unit_storage
    )
end

# Restores the state of the model or the current unit from data contained in a record.
function restore_from_record!(storage, record::RecordType) where {RecordType} 
    unit_storage_manager = _get_unit_storage_manager!(storage, unit_storage_type(RecordType))
    active_record = unit_storage_manager.active_record
    # if !isnothing(active_record)
    #     record_id = get_id(record)
    #     active_record_id = get_id(unit_storage_manager.active_record)

    #     # If we try to restore the active record.
    #     if record_id == active_record_id
    #         # We do nothing in this case?
    #         return false
    #     end
    # end

    # Otherwise, we try to restore another record.
    restore_from_record!(storage.model, unit_storage_manager.unit_storage, record)
    unit_storage_manager.active_record = record
    return true
end

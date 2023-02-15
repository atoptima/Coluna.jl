# The storage API is easy to use when you have one model.
# However, when you optimize a problem with Coluna, you generally have one reformulation that
# maintains several formulations.
# Each reformulation and formulation has a storage that has storage units.
# It becomes very hard to know which storage a record should restore.
# Therefore, we built this API on top of the storage API.
# It performs the same operations than the storage API but maintain additional information
# when you create records to easily restore the good storage unit.

# For each storage unit of Coluna, you must define a storage unit key.
# In nodes, we don't know the type of record we store.
# We thus use the AbstractStorageUnitKey and following methods for type inference.
abstract type AbstractStorageUnitKey end

key_from_storage_unit_type(T::Type{<:AbstractNewStorageUnit}) =
    error("key_from_storage_unit_type(::Type{$(T)}) not implemented.")
record_type_from_key(k::AbstractStorageUnitKey) =
    error("record_type_from_key(::$(typeof(k))) not implemented.")

############################################################################################
# create_records built on top of ClB.create_record
############################################################################################
struct Records
    records_by_model_id::Dict{Int, Dict{AbstractStorageUnitKey, AbstractNewRecord}}
    Records() = new(Dict{Int, Dict{AbstractStorageUnitKey, AbstractNewRecord}}())
end

function _add_rec!(
    r::Records, model::AbstractModel, storage_unit_type::Type{<:AbstractNewStorageUnit}, record::AbstractNewRecord
)
    model_id = getuid(model)
    if !haskey(r.records_by_model_id, model_id)
        r.records_by_model_id[model_id] = Dict{AbstractStorageUnitKey, AbstractNewRecord}()
    end
    if haskey(r.records_by_model_id[model_id], storage_unit_type)
        @error "Already added record for model $(getuid(model)) and storage unit $(storage_unit_type).
                Going to replace it."
    end
    key = key_from_storage_unit_type(storage_unit_type)
    r.records_by_model_id[getuid(model)][key] = record
    return
end

function _get_rec(r::Records, model::AbstractModel, key::AbstractStorageUnitKey)
    model_id = getuid(model)
    records_of_model = get(r.records_by_model_id, model_id, nothing)
    if !isnothing(records_of_model)
        if haskey(records_of_model, key)
            RT = record_type_from_key(key)
            # Note that the `::RT` in the line below is necessary for type inference.
            return records_of_model[key]::RT
        end
    end
    return nothing
end

function _create_records!(records::Records, model)
    storage = getstorage(model)
    for storage_unit_type in Iterators.keys(storage.units)
        record = create_record(storage, storage_unit_type)
        _add_rec!(records, model, storage_unit_type, record)
    end
    return
end

"""
    create_records(reformulation) -> Records

Methods to create records of all storage units of a reformulation and the formulations
handled by the reformulation.
"""
function create_records(reform::Reformulation)
    records = Records()
    _create_records!(records, reform)
    _create_records!(records, getmaster(reform))
    for form in Iterators.values(get_dw_pricing_sps(reform))
        _create_records!(records, form)
    end
    for form in Iterators.values(get_benders_sep_sps(reform))
        _create_records!(records, form)
    end
    return records
end

############################################################################################
# restore_from_records! built on top of ClB.restore_from_record!
############################################################################################

"""
Store a set of storage unit type associated to the model.
Used to indicate what storage units from what models we want to restore.
"""
struct UnitsUsage
    units_used::Vector{Tuple{AbstractModel,DataType}}
end

UnitsUsage() = UnitsUsage(Vector{Tuple{AbstractModel,DataType}}())

"""
    restore_from_records!(units_used::UnitsUsage, records::Records)

Method to restore storage units from reformulations and formulations given a set of records
stored in an object of type `Records`.
"""
function restore_from_records!(units_usage::UnitsUsage, records::Records)
    for (model, storage_unit_type) in units_usage.units_used
        record = _get_rec(records, model, key_from_storage_unit_type(storage_unit_type))
        if !isnothing(record)
            restore_from_record!(getstorage(model), record)
        end
    end
    return
end

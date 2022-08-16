@enum(UnitPermission, NOT_USED, READ_ONLY, READ_AND_WRITE)

# UnitType = Pair{Type{<:AbstractStorageUnit}, Type{<:AbstractRecord}}.
# see https://github.com/atoptima/Coluna.jl/pull/323#discussion_r418972805
const UnitType = DataType #Type{<:AbstractStorageUnit}

const RecordId = AbstractNewRecord

# Int is the model id.
const RecordsVector = Vector{Pair{Int, Vector{AbstractNewRecord}}}

#######

"""
    UnitsUsage()

Stores the access rights to some storage units.
"""
struct UnitsUsage
    permissions::Vector{Tuple{AbstractModel,DataType}}
end

UnitsUsage() = UnitsUsage(Vector{Tuple{AbstractModel,DataType}}())

### TODO remove set_permission!
"""
    set_permission!(units_usage, storage_unit, access_right)

Set the permission to a storage unit.
"""
function set_permission!(usages::UnitsUsage, unit::NewStorageUnitManager, mode::UnitPermission)
    #current_mode = get(usages.permissions, unit, NOT_USED)
    #new_mode = max(current_mode, mode)
    #usages.permissions[unit] = new_mode
    #return new_mode
end
### end

### TODO: this POC will need improvement.
### Perhaps, we shoud find another way to handle records when there are multiple models.
### Because the problem is that we can have the same store unit type in different model.
### So we must find to which model the record is attached.
function _restore_from_record!(model, store_unit_type, records)
    for (model_id, records_of_model) in Iterators.filter(
        (model_id, records_of_model) -> 
            getuid(model) == model_id &&
            store_unit_type == store_unit_type(eltype(records_of_model)), 
        records
    )
        restore_from_records!(getstorage(model), records_of_model)
    end
    return
end

function restore_from_records!(units_usage::UnitsUsage, records::RecordsVector)
    for (model, store_unit_type) in units_usage.permissions
        _restore_from_record!(model, store_unit_type, records)
    end
    return
end

function copy_records(records::RecordsVector)::RecordsVector
    recordscopy = RecordsVector()
    for record in records
        push!(recordscopy, record)
    end
    return recordscopy
end

"""
    IMPORTANT!

    Every stored or copied record should be either restored or removed so that it's 
    participation is correctly computed and memory correctly controlled
"""

#####

function getstorageunit(m::AbstractModel, SU::Type{<:AbstractNewStorageUnit})
    return getstoragewrapper(m, SU).storage_unit
end

function getstoragewrapper(m::AbstractModel, SU::Type{<:AbstractNewStorageUnit})
    storagecont = get(getstorage(m).units, SU, nothing)
    storagecont === nothing && error("No storage unit of type $SU in $(typeof(m)) with id $(getuid(m)).")
    return storagecont
end
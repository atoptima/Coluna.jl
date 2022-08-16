@enum(UnitPermission, NOT_USED, READ_ONLY, READ_AND_WRITE)

# UnitType = Pair{Type{<:AbstractStorageUnit}, Type{<:AbstractRecord}}.
# see https://github.com/atoptima/Coluna.jl/pull/323#discussion_r418972805
const UnitType = DataType #Type{<:AbstractStorageUnit}


const RecordId = AbstractNewRecord


const RecordsVector = Vector{Pair{NewStorageUnitManager,RecordId}}


function store_record!(storage::NewStorage, unit::NewStorageUnitManager{M,R,SU})::RecordId where {M,R,SU} 
    return create_record(storage, SU)
end


#######

"""
    UnitsUsage()

Stores the access rights to some storage units.
"""
struct UnitsUsage
    permissions::Dict{NewStorageUnitManager,UnitPermission}
end

UnitsUsage() = UnitsUsage(Dict{NewStorageUnitManager,UnitPermission}())

"""
    set_permission!(units_usage, storage_unit, access_right)

Set the permission to a storage unit.
"""
function set_permission!(usages::UnitsUsage, unit::NewStorageUnitManager, mode::UnitPermission)
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
function get_permission(usages::UnitsUsage, unit::NewStorageUnitManager, default)
    return get(usages.permissions, unit, default)
end



function restore_from_records!(units_to_restore::UnitsUsage, records::RecordsVector)
    for (storage, recordid) in records
        mode = get_permission(units_to_restore, storage, READ_ONLY)
        #restore_from_record!(storage.storage_unit, recordid, mode)
        restore_from_record!(storage.model, storage.storage_unit, recordid)
    end
    empty!(records)
    return
end

#####

function getstorageunit(m::AbstractModel, SU::Type{<:AbstractNewStorageUnit})
    return getstoragewrapper(m, SU).storage_unit
end

function getstoragewrapper(m::AbstractModel, SU::Type{<:AbstractNewStorageUnit})
    storagecont = get(getstorage(m).units, SU, nothing)
    storagecont === nothing && error("No storage unit of type $SU in $(typeof(m)) with id $(getuid(m)).")
    return storagecont
end
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


### TODO: this POC will need improvement.
### Perhaps, we shoud find another way to handle records when there are multiple models.
### Because the problem is that we can have the same store unit type in different model.
### So we must find which model the record is attached to.
function _restore_from_record!(model, store_unit_type, records::RecordsVector)
    for (model_id, records_of_model) in records
        if getuid(model) == model_id
            for record in records_of_model
                if store_unit_type == storage_unit_type(typeof(record))
                    restore_from_record!(getstorage(model), record)
                end
            end
        end
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
    # recordscopy = RecordsVector()
    # for record in records
    #     push!(recordscopy, record)
    # end
    # return recordscopy
    return records
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
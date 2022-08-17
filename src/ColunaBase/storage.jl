#######
# TODO: old code below
#######


@enum(UnitPermission, NOT_USED, READ_ONLY, READ_AND_WRITE)

# UnitType = Pair{Type{<:AbstractStorageUnit}, Type{<:AbstractRecord}}.
# see https://github.com/atoptima/Coluna.jl/pull/323#discussion_r418972805
const UnitType = DataType #Type{<:AbstractStorageUnit}



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
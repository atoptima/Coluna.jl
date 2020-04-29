getuid(model::AbstractModel) = 0

"""
    AbstractData

    Data is used by the algorithms. It contains user data, such as models and formulations, 
    as well as computed data stored in storages. 
"""

abstract type AbstractData end

getstoragedict(::AbstractData) = nothing
getmodel(::AbstractData) = nothing 
get_model_storage_dict(::AbstractData, ::AbstractModel) = nothing
store_states!(::AbstractData, ::StorageStatesVector) = nothing

function getnicename(data::AbstractData) 
    model = getmodel(data)
    return string("data associated to model of type $(typeof(model)) with id $(getuid(model))")
end

function get_storage_container(data::AbstractData, pair::StorageTypePair)
    storagedict = getstoragedict(data)
    storagecont = get(storagedict, pair, nothing)
    if storagecont === nothing
        error(string("No storage for pair $pair in $(getnicename(data))"))                        
    end
    return storagecont
end

getstorage(data::AbstractData, pair::StorageTypePair) = 
    getstorage(get_storage_container(data, pair))

reserve_for_writing!(data::AbstractData, pair::StorageTypePair) =
    reserve_for_writing!(get_storage_container(data, pair))   

"""
    EmptyData
"""

struct EmptyData <: AbstractData end

"""
    ModelData

    Data for a single model. 
"""

mutable struct ModelData <: AbstractData
    model::AbstractModel
    storagedict::StorageDict
end

ModelData(model::AbstractModel) = ModelData(model, StorageDict())
ModelData(::Nothing) = EmptyData()

getstoragedict(data::ModelData) = data.storagedict
getmodel(data::ModelData) = data.model
get_dw_pricing_datas(data::ModelData) = Dict{FormId, AbstractData}() 
get_benders_sep_datas(data::ModelData) = Dict{FormId, AbstractData}() 

function get_model_storage_dict(data::ModelData, model::AbstractModel)
    model == getmodel(data) && return getstoragedict(data)
    return nothing
end

function store_states!(data::ModelData, states::StorageStatesVector)
    storagedict = getstoragedict(data)
    for (FullType, storagecont) in storagedict
        stateid = storestate!(storagecont)
        push!(states, storagecont => stateid)
    end
end

"""
    ReformData

    Data for reformulation. 
"""

mutable struct ReformData <: AbstractData
    reform::Reformulation
    storagedict::StorageDict
    masterdata::AbstractData # can be ModelData or EmptyData
    dw_pricing_datas::Dict{FormId, AbstractData} 
    benders_sep_datas::Dict{FormId, AbstractData} 
end

getstoragedict(data::ReformData) = data.storagedict
getmodel(data::ReformData) = data.reform 
getreform(data::ReformData) = data.reform
getmasterdata(data::ReformData) = data.masterdata
get_dw_pricing_datas(data::ReformData) = data.dw_pricing_datas
get_benders_sep_datas(data::ReformData) = data.benders_sep_datas

function ReformData(reform::Reformulation)
    dw_pricing_datas = Dict{FormId, AbstractData}()
    sps = get_dw_pricing_sps(reform)
    for (spuid, spform) in sps
        if typeof(spform) == Reformulation
            dw_pricing_datas[spuid] = ReformData(spform)
        else
            dw_pricing_datas[spuid] = ModelData(spform)
        end
    end    

    benders_sep_datas = Dict{FormId, AbstractData}()
    sps = get_benders_sep_sps(reform)
    for (spuid, spform) in sps
        if typeof(spform) == Reformulation
            benders_sep_datas[spuid] = ReformData(spform)
        else
            benders_sep_datas[spuid] = ModelData(spform)
        end
    end  

    return ReformData(
        reform, StorageDict(), ModelData(getmaster(reform)), dw_pricing_datas, benders_sep_datas
    )
end    

function get_model_storage_dict(data::ReformData, model::AbstractModel)
    if model == getmodel(data) 
        return getstoragedict(data)
    elseif model == getmodel(getmasterdata(data))
        return getstoragedict(getmasterdata(data))
    else
        for (formid, sp_data) in get_dw_pricing_datas(data)
            model = getmodel(sp_data) && getstoragedict(sp_data)
        end
        for (formid, sp_data) in get_benders_sep_datas(data)
            model = getmodel(sp_data) && getstoragedict(sp_data)
        end
    end
    return nothing
end

function store_states!(data::ReformData, states::StorageStatesVector)
    storagedict = getstoragedict(data)
    for (FullType, storagecont) in storagedict
        stateid = storestate!(storagecont)
        push!(states, (storagecont, stateid))
    end
    store_states!(getmasterdata(data), states)
    for (formid, sp_data) in get_dw_pricing_datas(data)
        store_states!(sp_data, states)
    end
    for (formid, sp_data) in get_benders_sep_datas(data)
        store_states!(sp_data, states)
    end 
end

function store_states!(data::ReformData)
    states = StorageStatesVector()
    store_states!(data, states)
    return states
end

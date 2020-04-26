"""
    AbstractData

    Data is used by the algorithms. It contains user data, such as models and formulations, 
    as well as computed data stored in storages. 
"""

abstract type AbstractData end

getstoragedict(data::AbstractData) = nothing
getmodel(data::AbstractData) = nothing 
init_storage!(data::AbstractData, model::AbstractModel, StorageType::Type{<:StorageType}) = false
get_storage(data::AbstractData, model::AbstractModel, StorageType::Type{<:StorageType}) = nothing
store_states!(data::AbstractData, states::StorageStatesVector) = nothing

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

function init_storage!(data::ModelData, model::AbstractModel, StorageType::Type{<:StorageType})::Bool
    if model == getmodel(data)
        storagedict = getstoragedict(data)
        if !haskey(storagedict, StorageType)
            storagedict[StorageType] = StorageType(model)
        end
        return true 
    end
    return false
end

function get_storage(data::ModelData, model::AbstractModel, StorageType::Type{<:StorageType})
    if model == getmodel(data)
        storagedict = getstoragedict(data)
        return get(storagedict, StorageType, nothing)
    end
    return nothing
end

function store_states!(data::ModelData, states::StorageStatesVector)
    storagedict = getstoragedict(data)
    for (StorageType, storage) in storagedict
        stateid = storestate!(storage)
        push!(states, (storage, stateid))
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

# this constructor initializes all the storages
function ReformData(reform::Reformulation, algo::AbstractOptimizationAlgorithm)
    data = ReformData(reform)

    storages = StoragesUsageDict()
    get_all_storages_dict(algo, reform, storages, false) 

    for ((model, StorageType), mode) in storages
        if init_storage!(data, model, StorageType) == false
            error("Model $model does not exist in reformulation $reform.")    
        end
    end

    return data
end

function init_storage!(data::ReformData, model::AbstractModel, StorageType::Type{<:StorageType})::Bool
    if model == getreform(data)
        storagedict = getstoragedict(data)
        if !haskey(storagedict, StorageType)
            storagedict[StorageType] = StorageType(model)
        end
        return true 
    elseif model == getmodel(getmasterdata(data))
        storagedict = getstoragedict(getmasterdata(data))
        if !haskey(storagedict, StorageType)
            storagedict[StorageType] = StorageType(model)
        end
        return true 
    else
        for (formid, sp_data) in get_dw_pricing_datas(data)
            init_storage!(sp_data, model, StorageType) && return true
        end
        for (formid, sp_data) in get_benders_sep_datas(data)
            init_storage!(sp_data, model, StorageType) && return true
        end
    end
    return false
end

function get_storage(data::ReformData, model::AbstractModel, StorageType::Type{<:StorageType})
    if model == getreform(data)
        storagedict = getstoragedict(data)
        return get(storagedict, StorageType, nothing)
    elseif model == getmodel(getmasterdata(data))
        storagedict = getstoragedict(getmasterdata(data))
        return get(storagedict, StorageType, nothing)
    else
        for (formid, sp_data) in get_dw_pricing_datas(data)
            storage = get_storage(sp_data, model, StorageType) 
            storage !== nothing && return storage
        end
        for (formid, sp_data) in get_benders_sep_datas(data)
            storage = get_storage(sp_data, model, StorageType) 
            storage !== nothing && return storage
        end
    end
    return nothing
end

function store_states!(data::ReformData, states::StorageStatesVector)
    storagedict = getstoragedict(data)
    for (StorageType, storage) in storagedict
        stateid = storestate!(storage)
        push!(states, (storage, stateid))
    end
    store_states!(getmasterdata, states)
    for (formid, sp_data) in get_dw_pricing_datas(data)
        store_states!(getmasterdata, sp_data)
    end
    for (formid, sp_data) in get_benders_sep_datas(data)
        store_states!(getmasterdata, sp_data)
    end 
end

function store_states!(data::ReformData)
    states = StorageStatesVector()
    store_states!(data, states)
    return states
end
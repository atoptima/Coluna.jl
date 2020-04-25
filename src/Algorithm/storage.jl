@enum(StorageAccessMode, READ_AND_WRITE, READ_ONLY, NOT_USED)
@enum(StorageClass, CONQUER_STORAGE_CLASS, DIVIDE_STORAGE_CLASS, UNKNOWN_STORAGE_CLASS)

"""
    AbstractStorageState

    Storage state is used to save the current state of a storage and 
    then to restore the storage from the state.
    
    For each storage state, a constructor should be defined which
    takes the state id and participation as parameters and creates 
    the empty state.
    
    Each storage state should know the participation, i.e. the number 
    of times it is used. If participation drops to zero, storage state 
    can be deleted. 
"""
abstract type AbstractStorageState end

const StateId = Int

const StorageStateDict{SS<:AbstractStorageState} = Dict{StateId, SS}

"""
    Functions which should be defined for every storage state
"""

isempty(ss::AbstractStorageState)::Bool = nothing

getparticipation(ss::AbstractStorageState)::Int = nothing

getid(ss::AbstractStorageState)::StateId = nothing

increaseparticipation!(ss::AbstractStorageState) = nothing

decreaseparticipation!(ss::AbstractStorageState) = nothing

"""
    EmptyStorageState

    If a storage is using the empty storage state, 
    storage can be used only for reading 
    (can be changed only in the constructor). 
"""

struct EmptyStorageState <: AbstractStorageState end

EmptyStorageState(stateid::StateId, participation::Int) = EmptyStorageState()

isempty(ss::EmptyStorageState)::Bool = true

getparticipation(ss::AbstractStorageState)::Int = 0

getid(ss::AbstractStorageState)::StateId = 1


"""
    AbstractStorage

    Storage can be useful to keep computed data between different runs 
    of an algorithm or between runs of different algorithms.

    Each storage is attached to a model (user's data) and usually
    contains data computed based on the contents of the model.

    Each storage is parameterized by the storage state type. 
    If storage contents does not change after initialization 
    in the constructor, EmptyStorageState type should be used.     

    For every storage a constructor should be defined which
    takes a model as a parameter. This constructor is 
    called when the formulation is completely known so the data
    can be safely computed.
"""
abstract type AbstractStorage{SS<:AbstractStorageState} end

const StorageDict = Dict{Type{<:AbstractStorage}, AbstractStorage}

const StorageUsageTuple = Tuple{AbstractModel, Type{<:AbstractStorage}, StorageAccessMode}

const StoragesUsageDict = Dict{Tuple{AbstractModel, Type{<:AbstractStorage}}, StorageAccessMode}

const StorageStatesVector = Vector{Tuple{AbstractStorage, StateId}}

"""
    Functions for storages which should be redefined for every storage type
"""

get_storage_class(storage::AbstractStorage)::StorageClass = UNKNOWN_STORAGE_CLASS

function getmodel(storage::AbstractStorage)::AbstractModel 
    stype = typeof(storage)
    error("Method getmodel() is not defined for storage type $stype.")    
end
 
function get_current_state(storage:::AbstractStorage{SS})::SS where {SS <: AbstractStorageState}
    stype = typeof(storage)
    error("Method get_current_state() is not defined for storage type $stype.")    
end

function set_current_state!(storage:::AbstractStorage{SS}, state::SS) where {SS <: AbstractStorageState}
    stype = typeof(storage)
    error("Method set_current_state() is not defined for storage type $stype.")    
end

function get_max_stateid(storage:::AbstractStorage{SS})::StateId where {SS <: AbstractStorageState}
    stype = typeof(storage)
    error("Method get_max_stateid() is not defined for storage type $stype.")    
end

function getstatesdict(storage::AbstractStorage{SS})::StorageStateDict{SS} where {SS <: AbstractStorageState}
    stype = typeof(storage)
    error("Method getstatesdict() is not defined for storage type $stype.")    
end

function recordtostate!(storage::AbstractStorage{SS}, state::SS) where {SS <: AbstractStorageState}
    stype = typeof(storage)
    error("Method recordtostate() is not defined for storage type $stype.")    
end

function restorefromstate!(storage::AbstractStorage{SS}, state::SS) where {SS <: AbstractStorageState}
    stype = typeof(storage)
    error("Method restorefromstate() is not defined for storage type $stype.")    
end

"""
    Redefinition for storages parameterized by EmptyStorageState. Redefinition for getmodel is still needed. 
"""

get_current_state(storage:::AbstractStorage{EmptyStorageState}) = EmptyStorageState()
set_current_state(storage:::AbstractStorage{EmptyStorageState}, state::EmptyStorageState) = nothing
get_max_stateid(storage:::AbstractStorage{EmptyStorageState}) = 0

"""
    Internal functions for storages, should not be redefined
"""

function increaseparticipation!(storage::AbstractStorage{SS}, stateid::StateId)::SS where {SS <: AbstractStorageState}
    state = get_current_state(storage)
    if (getid(state) == stateid)
        increaseparticipation!(state)
    else
        statesdict::StorageStateDict{SS} = getstatesdict(storage)
        if !haskey(statesdict, stateid)
            stype = typeof(storage)
            form = getform(storage)            
            @error "State with id $stateid does not exist for storage of type $stype (formulation $form)"
        end
        increaseparticipation!(statesdict[stateid])
    end
end

function retrieve_from_dict(storage::AbstractStorage{SS}, stateid::StateId)::SS where {SS <: AbstractStorageState}
    statesdict::StorageStateDict{SS} = getstatesdict(storage)
    if !haskey(statesdict, stateid)
        stype = typeof(storage)
        form = getform(storage)            
        @error "State with id $stateid does not exist for storage of type $stype (formulation $form)"
    end
    state = statesdict[stateid]
    decreaseparticipation!(state)
    if getparticipation(state) == 0
        delete!(statesdict, stateid)
    elseif getparticipation(state) < 0
        stype = typeof(storage)
        form = getform(storage)            
        @error "Participation of state with id $stateid of storage of type $stype (formulation $form) is below zero"
    end
    return state
end

function save_state_to_dict!(storage::AbstractStorage{SS}, state::SS) where {SS <: AbstractStorageState}
    if getparticipation(state) > 0 && isempty(state)
        recordtostate!(storage, state)
        statesdict::StorageStateDict{SS} = getstatesdict(storage)
        statesdict[getid(state)] = state
    end
end

"""
    Storage functions used by Coluna, should not be redefined for concrete storage types

"""

function storestate!(storage::AbstractStorage{SS})::StateId where {SS <: AbstractStorageState}
    state = get_current_state(storage)
    increaseparticipation!(state)
    return getid(state)
end

function restorestate!(
    storage::AbstractStorage{SS}, stateid::StateId, mode::StorageAccessMode
) where {SS <: AbstractStorageState}

    state::SS = get_current_state(storage)
    if getid(state) == stateid 
        decreaseparticipation!(state)
        if getparticipation(state) < 0
            stype = typeof(storage)
            form = getform(storage)            
            @error "Participation of the current state of storage of type $stype (formulation $form) is below zero"
        return
        if mode == READ_AND_WRITE 
            save_state_to_dict!(storage, state)
            state = SS(get_max_stateid(storage) + 1, 0)
            set_current_state!(storage, state)
        end
        return
    elseif mode != NOT_USED
        # we save current state to dictionary if necessary
        save_state_to_dict!(storage, state)
    end

    state = retrieve_from_dict(storage, stateid)

    if mode != NOT_USED # otherwise we do nothing, so the state will be deleted if its participation is zero
        restorefromstate!(storage, state)
        if mode == READ_AND_WRITE 
            state = SS(get_max_stateid(storage) + 1, 0)
        end 
        set_current_state!(storage, state)
    end
end
 
function restore_states!(states::StorageStatesVector, usage::StoragesUsageDict)
    for (storage, stateid) in states
        mode = get(usage, (getmodel(storage), typeof(storage)), NOT_USED)
        restorestate!(storage, stateid, mode)
    end
end

remove_states!(states::StorageStatesVector) = restore_states!(states, StoragesUsageDict())

function copy_states(states::StorageStatesVector)::StorageStatesVector
    statescopy = StorageStatesVector()
    for (storage, stateid) in states
        push!(statescopy, (storage, stateid))
        increaseparticipation!(storage, stateid)
    end
    return statescopy
end

"""
    IMPORTANT!

    Every stored or copied state should be either restored or removed so that it's 
    participation is correctly computed and memory correctly controlled
"""

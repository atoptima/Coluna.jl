@enum(StorageAccessMode, READ_AND_WRITE, READ_ONLY, NOT_USED)

"""
    About storages
    --------------

    Storages are used to keep computed data between different runs 
    of an algorithm or between runs of different algorithms.

    Computed data may be contained in a storage itself or in a 
    model (for example formulation) to which the storage is associated. 

    If the data is contained in the associated model, 
    then the storage itself is empty (see EmptyStorage below).

    A storage has the functionality to store its current data to a state, 
    and restore its date from a state. This is useful when the algorithm
    flow should return to some previous state (for example, to return to
    some saved node in the search tree). Thus every storage is also 
    associates to some storage state type.  

    Every algorithm should comminicate:
    - which storages it uses, so that they can be initialized before 
      running the global algorithm; 
    - for which storages the correct state should be restored before 
      the algorithm is run, and the access mode for these storages
      (ready only or read-and-write). 

    Every such storage is determined by the model, storage type, and 
    storage state type. For every model there may be only one storage
    for each couple (storage type, storage state type).      
"""


"""
    AbstractStorage 

    For every storage a constructor should be defined which
    takes a model as a parameter. This constructor is 
    called when the formulation is completely known so the data
    can be safely computed.
"""

abstract type AbstractStorage end

"""
    AbstractStorageState
    
    For each storage state, a constructor should be defined which
    takes a model and a storage as parameters. This constructor
    is called during storing a storage. 
    
"""

abstract type AbstractStorageState end

"""
    function restorefromstate!(model, storage, storage state)
    
    Should be defined for every triple (model type, storage type, storage state type)
    used by an algorithm.     
"""

restorefromstate!(model::AbstractModel, storage::AbstractStorage, state::AbstractStorageState) =
    error(string(
        "Method restorefromstate!() is not defined for model type $(typeof(model)), ",
        "storage type $(typeof(storage)), and storage state type $(typeof(state))"
    ))    

"""
    EmptyStorage

    Empty storage is used to implicitely keep the data which is changed
    inside the model (for example, dynamic variables and constraints
    of a formulaiton) in order to store it to the storage state and 
    restore it afterwards. 
"""

struct EmptyStorage <: AbstractStorage end

EmptyStorage(model::AbstractModel) = EmptyStorage()


"""
    EmptyStorageState

    If a storage is not changed after initialization, then 
    the empty storage state should be used with it.
"""

struct EmptyStorageState <: AbstractStorageState end

EmptyStorageState(model::AbstractModel, storage::AbstractStorage) = nothing

restorefromstate!(::AbstractModel, ::AbstractStorage, ::EmptyStorageState) = nothing

const FullStorageType = Tuple{Type{<:AbstractStorage}, Type{<:AbstractStorageState}}

const StoragesUsageDict = Dict{AbstractModel, Set{FullStorageType}}

const StoragesToRestoreDict = Dict{Tuple{AbstractModel, FullStorageType}, StorageAccessMode}


"""
    function add!(::StoragesUsageDict, ::AbstractModel, ::FullStorageType)

    This is an auxiliary function to be used inside algorithm function
    get_storages_to_restore(::AbstractAlgorithm, ::AbstractModel, ::StoragesUsageDict)    
"""
function add!(dict::StoragesUsageDict, model::AbstractModel, type::FullStorageType)
    if !haskey(dict, model)
        dict[model] = Set{FullStorageType}()
    end
    push!(dict[model], type)
end

"""
    function add!(::StoragesToRestoreDict, ::AbstractModel, ::FullStorageType, ::StorageAccessMode)

    This is an auxiliary function to be used inside algorithm function
    get_storages_to_restore!(::AbstractAlgorithm, ::AbstractModel, ::::StoragesToRestoreDict)    
"""
function add!(dict::StoragesToRestoreDict, model::AbstractModel, type::FullStorageType, mode::StorageAccessMode)
    current_mode = get(dict, (model, type), NOT_USED) 
    if current_mode == NOT_USED && mode != NOT_USED
        dict[(model, type)] = mode
    else
        if mode == READ_AND_WRITE && current_mode == READ_ONLY
            dict[(model, type)] = READ_AND_WRITE
        end    
    end
end

"""
    StorageStateContainer

    This container keeps additional storage state information needed for 
    keeping the number of times the state has been stored. When 
    this number drops to zero, the state can be deleted. 
"""

const StateId = Int

mutable struct StorageStateContainer{SS<:AbstractStorageState}
    id::StateId
    participation::Int
    state::Union{Nothing, SS}
end

StorageStateContainer{SS}(stateid::StateId, participation::Int) where {SS<:AbstractStorageState} =
    StorageStateContainer{SS}(stateid, true, participation, nothing)

getid(ssc::StorageStateContainer) = ssc.id
isempty(ssc::StorageStateContainer) = ssc.state === nothing
getparticipation(ssc::StorageStateContainer) = ssc.participation
getstate(ssc::StorageStateContainer) = ssc.state
increaseparticipation!(ssc::StorageStateContainer) = ssc.participation += 1
decreaseparticipation!(ssc::StorageStateContainer) = ssc.participation -= 1

function setstate!(ssc::StorageStateContainer{SS}, state_to_set::SS) where {SS<:AbstractStorageState}
    state = state_to_set
end

"""
    EmptyStorageStateContainer
"""

const EmptyStorageStateContainer = StorageStateContainer{EmptyStorageState}

EmptyStorageStateContainer(stateid::StateId, participation::Int) =
    EmptyStorageStateContainer(1, 0)

getid(essc::EmptyStorageStateContainer) = 1
isempty(essc::EmptyStorageStateContainer) = true 
getparticipation(essc::EmptyStorageStateContainer) = 0
increaseparticipation!(essc::EmptyStorageStateContainer) = nothing
decreaseparticipation!(essc::EmptyStorageStateContainer) = nothing

"""
    StorageContainer

    This container keeps storages and all states which have been 
    stored. It implements storing and restoring states in an 
    efficient way. 
"""

mutable struct StorageContainer{M<:AbstractModel, S<:AbstractStorage, SS<:AbstractStorageState}
    model::M
    curstatecont::StorageStateContainer{SS}
    maxstateid::StateId
    storage::S
    statetype::DataType
    statesdict::Dict{StateId, StorageStateContainer{SS}}
end 

const StorageStatesVector = Vector{Tuple{StorageContainer, StateId}}

const StorageDict = Dict{FullStorageType, StorageContainer}

function StorageContainer{M,S,SS}(model::M) where {M,S,SS}
    return StorageContainer{M,S,SS}(
        model, StorageStateContainer{SS}(1, 0), 1, S(model), 
        SS, Dict{StateId, StorageStateContainer{SS}}()
    )
end    

getmodel(sc::StorageContainer) = sc.model
getcurstatecont(sc::StorageContainer) = sc.curstatecont
getmaxstateid(sc::StorageContainer) = sc.maxstateid
getstatesdict(sc::StorageContainer) = sc.statedict
getstorage(sc::StorageContainer) = sc.storage
getstoragetype(sc::StorageContainer) = typeof(sc.storage)
getstatetype(sc::StorageContainer) = sc.statetype

function setcurstate!(
    storagecont::StorageContainer{M,S,SS}, statecont::StorageStateContainer{SS}
) where {M,S,SS} 
    storagecont.curstatecont = statecont
    if getmaxstateid(storagecont) < getid(statecont) 
        storagecont.maxstateid = getid(statecont)
    end
end

function getnicename(sc::StorageContainer{M,S,SS}) where {M,S,SS}
    return string(
        "storage of type ", S, " with storage type ", SS, 
        " of formulation of type ", M, " with id = ", getuid(getmodel(sc))  
    )
end

function increaseparticipation!(storagecont::StorageContainer, stateid::StateId)
    statecont = getcurstatecont(storagecont)
    if (getid(statecont) == stateid)
        increaseparticipation!(statecont)
    else
        statesdict = getstatesdict(storagecont)
        if !haskey(statesdict, stateid) 
            error(string("State with id $stateid does not exist for ", getnicename(storagecont)))
        end
        increaseparticipation!(statesdict[stateid])
    end
end

function retrieve_from_statesdict(storagecont::StorageContainer, stateid::StateId)
    statesdict = getstatesdict(storagecont)
    if !haskey(statesdict, stateid)
        error(string("State with id $stateid does not exist for ", getnicename(storagecont)))
    end
    statecont = statesdict[stateid]
    decreaseparticipation!(statecont)
    if getparticipation(statecont) == 0
        delete!(statesdict, stateid)
    elseif getparticipation(statecont) < 0
        error(string("Participation is below zero for state with id $stateid of ", getnicename(storagecont)))
    end
    return statecont
end

function save_to_statesdict!(
    storagecont::StorageContainer{M,S,SS}, statecont::StorageStateContainer{SS}
) where {M,S,SS}
    if getparticipation(statecont) > 0 && isempty(statecont)
        state = SS(getmodel(storagecont), getstorage(storagecont))
        setstate!(statecont, state)
        statesdict = getstatesdict(storagecont)
        statesdict[getid(statecont)] = statecont
    end
end

function storestate!(storagecont::StorageContainer)::StateId 
    statecont = getcurstatecont(storagecont)
    increaseparticipation!(statecont)
    return getid(statecont)
end

function restorestate!(
    storagecont::StorageContainer{M,S,SS}, stateid::StateId, mode::StorageAccessMode
) where {M,S,SS}
    statecont = getcurstatecont(storagecont)
    if getid(statecont) == stateid 
        decreaseparticipation!(statecont)
        if getparticipation(statecont) < 0
            error(string("Participation is below zero for state with id $stateid of ", getnicename(storagecont)))
        return
        if mode == READ_AND_WRITE 
            save_to_statesdict!(storagecont, statecont)
            statecont = StorageStateContainer{SS}(getmaxstateid(storagecont) + 1, 0)
            setcurstate!(storagecont, statecont)
        end
        return
    elseif mode != NOT_USED
        # we save current state to dictionary if necessary
        save_to_statesdict!(storagecont, statecont)
    end

    statecont = retrieve_from_statesdict(storagecont, stateid)

    if mode != NOT_USED # otherwise we do nothing, so the state will be deleted if its participation is zero
        restorefromstate!(getmodel(storagecont), getstorage(storagecont), getstate(statecont))
        if mode == READ_AND_WRITE 
            statecont = StorageStateContainer{SS}(getmaxstateid(storagecont) + 1, 0)
        end 
        setcurstate!(storagecont, statecont)
    end
end

"""
    Storage functions used by Coluna
"""

function reserve_for_writing!(storagecont::StorageContainer{M,S,SS}) where {M,S,SS}
    statecont = getcurstatecont(storagecont)
    save_to_statesdict!(storagecont, statecont)
    statecont = StorageStateContainer{SS}(getmaxstateid(storagecont) + 1, 0)
    setcurstate!(storagecont, statecont)
end

function restore_states!(ssvector::StorageStatesVector, storages_to_restore::StoragesToRestoreDict)
    for (storagecont, stateid) in ssvector
        mode = get(
            storages_to_restore, 
            (getmodel(storagecont), getstoragetype(storagecont), getstatetype(storagecont)), 
            NOT_USED
        )
        restorestate!(storagecont, stateid, mode)
    end    
    empty!(ssvector) # vector of states should be emptied 
end

remove_states!(states::StorageStatesVector) = restore_states!(states, StoragesToRestoreDict())

function copy_states(states::StorageStatesVector)::StorageStatesVector
    statescopy = StorageStatesVector()
    for (storagecont, StorageStateType, stateid) in states
        push!(statescopy, (storagecont, stateid))
        increaseparticipation!(storagecont, stateid)
    end
    return statescopy
end

"""
    IMPORTANT!

    Every stored or copied state should be either restored or removed so that it's 
    participation is correctly computed and memory correctly controlled
"""

# const StorageUsageTuple = Tuple{AbstractModel, Type{<:AbstractStorage}, StorageAccessMode}

# const StorageWriteUsageVector = Vector{Tuple{AbstractModel, Type{<:AbstractStorage}}} 



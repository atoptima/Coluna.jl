############################################################################################
# Algorithm API
############################################################################################

# TODO: remove this method.
# We currently need it because we give to the parent algorithm the responsability of recording
# and restoring the state of a formulation when a child algorithm may divide the calculation
# flow and thus making invalid the formulation for the parent algorithm at the end of the
# child execution.
# If we give the responsability of recording/restoring to the child, we won't need this method
# anymore and we'll get rid of the concept of manager & worker algorithm.
ismanager(algo::AlgoAPI.AbstractAlgorithm) = false


"""
    get_child_algorithms(algo, model) -> Tuple{AbstractAlgorithm, AbstractModel}[]

Every algorithm should communicate its child algorithms and the model to which 
each child algorithm is applied. 
"""
get_child_algorithms(::AlgoAPI.AbstractAlgorithm, ::AbstractModel) = Tuple{AlgoAPI.AbstractAlgorithm, AbstractModel}[]

"""
    get_units_usage(algo, model) -> Tuple{AbstractModel, UnitType, UnitPermission}[]

Every algorithm should communicate the storage units it uses (so that these units 
are created in the beginning) and the usage mode (read only or read-and-write). Usage mode is needed for 
in order to restore units before running a worker algorithm.
"""
get_units_usage(::AlgoAPI.AbstractAlgorithm, ::AbstractModel) = Tuple{AlgoAPI.AbstractModel, UnitType, UnitPermission}[] 

############################################################################################
# Conquer Algorithm API
############################################################################################

"""
AbstractConquerInput

Input of a conquer algorithm used by the tree search algorithm.
Contains the node in the search tree and the collection of units to restore 
before running the conquer algorithm. This collection of units is passed
in the input so that it is not obtained each time the conquer algorithm runs. 
"""
abstract type AbstractConquerInput end

@mustimplement "ConquerInput" get_node(i::AbstractConquerInput) = nothing
@mustimplement "ConquerInput" get_units_to_restore(i::AbstractConquerInput) = nothing
@mustimplement "ConquerInput" run_conquer(i::AbstractConquerInput) = nothing

"""
    AbstractConquerAlgorithm

This algorithm type is used by the tree search algorithm to update the incumbents and the formulation.
For the moment, a conquer algorithm can be run only on reformulation.     
A conquer algorithm should restore records of storage units using `restore_from_records!(conquer_input)`
- each time it runs in the beginning
- each time after calling a child manager algorithm
"""
abstract type AbstractConquerAlgorithm <: AlgoAPI.AbstractAlgorithm end

# conquer algorithms are always manager algorithms (they manage storing and restoring units)
ismanager(algo::AbstractConquerAlgorithm) = true

@mustimplement "ConquerAlgorithm" run!(::AbstractConquerAlgorithm, ::Env, ::Reformulation, ::AbstractConquerInput) = nothing

# this function is needed in strong branching (to have a better screen logging)
isverbose(algo::AbstractConquerAlgorithm) = false




############################################################################################
# Optimization Algorithm API
############################################################################################

"""
    AbstractOptimizationAlgorithm

    This type of algorithm is used to "bound" a model, i.e. to improve primal
    and dual bounds of the model. Solving to optimality is a special case of "bounding".
    The input of such algorithm should be of type Incumbents.    
    The output of such algorithm should be of type OptimizationState.    
"""
abstract type AbstractOptimizationAlgorithm <: AlgoAPI.AbstractAlgorithm end


# this function collects storage units to restore for an algorithm and all its child worker algorithms,
# child manager algorithms are skipped, as their restore units themselves
function _collect_units_to_restore!(
    global_units_usage::UnitsUsage, algo::AlgoAPI.AbstractAlgorithm, model::AbstractModel
)
    for (unit_model, unit_type, unit_usage) in get_units_usage(algo, model)
        push!(global_units_usage.units_used, (unit_model, unit_type))
    end

    for (childalgo, childmodel) in get_child_algorithms(algo, model)
        if !ismanager(childalgo)
            _collect_units_to_restore!(global_units_usage, childalgo, childmodel)
        end
    end
end

function collect_units_to_restore!(algo::AlgoAPI.AbstractAlgorithm, model::AbstractModel)
    global_units_usage = UnitsUsage()
    _collect_units_to_restore!(global_units_usage, algo, model)
    return global_units_usage
end

# this function collects units to create for an algorithm and all its child algorithms
# this function is used only the function initialize_storage_units! below
function collect_units_to_create!(
    units_to_create::Dict{AbstractModel,Set{UnitType}}, algo::AlgoAPI.AbstractAlgorithm, model::AbstractModel
)
    units_usage = get_units_usage(algo, model)
    for (unit_model, unit_pair, _) in units_usage
        if !haskey(units_to_create, unit_model)
            units_to_create[unit_model] = Set{UnitType}()
        end
        push!(units_to_create[unit_model], unit_pair)
    end

    child_algos = get_child_algorithms(algo, model)
    for (childalgo, childmodel) in child_algos
        collect_units_to_create!(units_to_create, childalgo, childmodel)
    end
    return
end

# this function initializes all the storage units
function initialize_storage_units!(reform::Reformulation, algo::AbstractOptimizationAlgorithm)

    units_to_create = Dict{AbstractModel,Set{UnitType}}()
    collect_units_to_create!(units_to_create, algo, reform) 

    for (model, types_of_storage_unit) in units_to_create        
        storagedict = model.storage.units
        if storagedict === nothing
            error(string("Model of type $(typeof(model)) with id $(getuid(model)) ",
                         "is not contained in $(getnicename(data))")                        
            )
        end

        for storage_unit_type in types_of_storage_unit
            storagedict[storage_unit_type] = NewStorageUnitManager(storage_unit_type, model)
        end
    end
end

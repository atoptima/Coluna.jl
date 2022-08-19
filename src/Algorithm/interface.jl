############################################################################################
# Algorithm API
############################################################################################

"Supertype for algorithms parameters."
abstract type AbstractAlgorithm end

"""
    run!(algo::AbstractAlgorithm, env, model, input)
Runs an algorithm. 
"""
function run!(algo::AbstractAlgorithm, env::Env, model::AbstractModel, input)
    error("run!(::$(typeof(algo)), ::$(typeof(env)), ::$(typeof(model)), ::$(typeof(input))) not implemented.")
end

# TODO: remove this method.
# We currently need it because we give to the parent algorithm the responsability of recording
# and restoring the state of a formulation when a child algorithm may divide the calculation
# flow and thus making invalid the formulation for the parent algorithm at the end of the
# child execution.
# If we give the responsability of recording/restoring to the child, we won't need this method
# anymore and we'll get rid of the concept of manager & worker algorithm.
ismanager(algo::AbstractAlgorithm) = false


"""
    get_child_algorithms(algo, model) -> Tuple{AbstractAlgorithm, AbstractModel}[]

Every algorithm should communicate its child algorithms and the model to which 
each child algorithm is applied. 
"""
get_child_algorithms(::AbstractAlgorithm, ::AbstractModel) = Tuple{AbstractAlgorithm, AbstractModel}[]

"""
    get_units_usage(algo, model) -> Tuple{AbstractModel, UnitType, UnitPermission}[]

Every algorithm should communicate the storage units it uses (so that these units 
are created in the beginning) and the usage mode (read only or read-and-write). Usage mode is needed for 
in order to restore units before running a worker algorithm.
"""
get_units_usage(::AbstractAlgorithm, ::AbstractModel) = Tuple{AbstractModel, UnitType, UnitPermission}[] 

############################################################################################
# Conquer Algorithm API
############################################################################################








"""
    AbstractOptimizationAlgorithm

    This type of algorithm is used to "bound" a model, i.e. to improve primal
    and dual bounds of the model. Solving to optimality is a special case of "bounding".
    The input of such algorithm should be of type Incumbents.    
    The output of such algorithm should be of type OptimizationState.    
"""
abstract type AbstractOptimizationAlgorithm <: AbstractAlgorithm end

exploits_primal_solutions(algo::AbstractOptimizationAlgorithm) = false

# this function collects storage units to restore for an algorithm and all its child worker algorithms,
# child manager algorithms are skipped, as their restore units themselves
function _collect_units_to_restore!(
    global_units_usage::UnitsUsage, algo::AbstractAlgorithm, model::AbstractModel
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

function collect_units_to_restore!(algo::AbstractAlgorithm, model::AbstractModel)
    global_units_usage = UnitsUsage()
    _collect_units_to_restore!(global_units_usage, algo, model)
    return global_units_usage
end

# this function collects units to create for an algorithm and all its child algorithms
# this function is used only the function initialize_storage_units! below
function collect_units_to_create!(
    units_to_create::Dict{AbstractModel,Set{UnitType}}, algo::AbstractAlgorithm, model::AbstractModel
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

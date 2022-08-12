# ```@meta
# CurrentModule = Coluna.Algorithm
# DocTestSetup = quote
#     using Coluna.Algorithm
# end
# ```

# # Storage API

# ## Introduction

# A storage is a collection of storage units attached to a model.

# A storage unit is a type that groups a set of entities for which we want to track the value 
# over time. We can distinguish two kinds of storage units. First, storage units that track
# entities of the model (e.g. status of branching constraints, lower and upper bounds of variables).
# Second, storage units that track additional data (e.g. data of algorithms).

# Since the values of the entities grouped in a storage unit vary over time, we want to save
# them at specific steps of the calculation flow to restore them later. The storage interface
# provides two methods to do both actions: 

# ```@docs
#     create_record
#     restore_from_record!
# ```

# ## Example

# Let's see through a simple example how to implement this interface.

# From a developer point of view, there is a one-to-one correspondance between storage unit
# types and record types. This correspondance is implemented by methods
# `record_type(StorageUnitType)` and `storage_unit_type(RecordType)`.

# The developer must also implement methods `new_storage_unit(StorageUnitType)` and
# `new_record(RecordType, id, model, storage_unit)` that must call constructors of the custom 
# storage unit and the one of its associated records. As you can see, arguments of
# `new_record` allow the developer to record the state of entities from both the storage unit 
# and the model.

# At last, he must implement `restore_from_record(storage_unit, model, record)` to restore the
# state of the entities represented by the storage unit. Entities can be in the storage unit,
# the model, or in both of them.

# import deps

using Coluna

const ClB = Coluna.ColunaBase
const ClA = Coluna.Algorithm

# We consider a data structure that maintain a model.
# The model has 3 integer variables: `x1`, `x2`, and `x3`.
# Their costs are `[-1, 1, -0.5]`.
# Their initial bounds are `

struct Formulation <: ClB.AbstractModel
    var_names::Vector{String}
    var_costs::Vector{Float64}
    var_domains::Vector{Tuple{Float64,Float64}}
end

# We create a storage unit for variable domains
struct VarDomainStorageUnit <: ClB.AbstractNewStorageUnit end

ClB.new_storage_unit(::Type{VarDomainStorageUnit}) = VarDomainStorageUnit()

# We create the data structure to store the records of variable domains.

struct VarDomainRecord <: ClB.AbstractNewRecord
    var_domains::Vector{Tuple{Float64,Float64}}
end

# 1-to-1 relation between storage units and records
ClB.record_type(::Type{VarDomainStorageUnit}) = VarDomainRecord
ClB.storage_unit_type(::Type{VarDomainRecord}) = VarDomainStorageUnit

# Dev implements
function ClB.new_record(::Type{VarDomainRecord}, id::Int, form::Formulation, ::VarDomainStorageUnit)
    return VarDomainRecord(copy(form.var_domains))
end

# Dev implements
function ClB.restore_from_record!(form::Formulation, ::VarDomainStorageUnit, record::VarDomainRecord)
    for (var_pos, (lb, ub)) in enumerate(record.var_domains)
        form.var_domains[var_pos] = (lb, ub)
    end
    return
end


names = ["x1", "x2", "x3"]
costs = [-1, 1, -0.5]
initial_bounds = [(0,2), (1,2), (-1,1)]

formulation = Formulation(names, costs, initial_bounds)

"""
We define a tree search algorithm that branch on all feasible integer values of 
x1 at depth 1, x2 at depth 2, and x3 at depth 3.
"""

mutable struct Node <: ClA.AbstractNode
    depth::Int
    id::Int
    parent::Union{Nothing,Node}
    record
    function Node(parent, id, record)
        depth = isnothing(parent) ? 0 : parent.depth + 1
        return new(depth, id, parent, record)
    end
end

ClA.root(node::Node) = isnothing(node.parent) ? node : ClA.root(node.parent)
ClA.parent(node::Node) = node.parent

mutable struct FullExplSearchSpace <: ClA.AbstractSearchSpace
    nb_nodes_generated::Int
    formulation::Formulation
    storage::ClB.NewStorage{Formulation}
    record_ids_per_node::Dict{Int, Any}
    function FullExplSearchSpace(form::Formulation)
        return new(0, form, ClB.NewStorage(form), Dict{Int,Any}())
    end
end

function ClA.new_root(space::FullExplSearchSpace, _)
    space.nb_nodes_generated += 1
    return Node(nothing, 0, nothing)
end

function ClA.children(space::FullExplSearchSpace, current, env, untreated_nodes)
    # Here we may do some operations on the formulation (such as adding variables)
    if !isnothing(current.record) # root node has no records before evaluation
        ClB.restore_from_record!(space.storage, current.record)
    end

    @show space.formulation.var_domains

    current.record = ClB.create_record(space.storage, VarDomainStorageUnit)

    var_pos = current.depth + 1
    var_domain = get(space.formulation.var_domains, var_pos, (0,-1))

    return map(range(first(var_domain), last(var_domain))) do rhs
        println("fix variable $var_pos to $rhs")
        space.nb_nodes_generated += 1
        node_id = space.nb_nodes_generated

        # Change the formulation
        space.formulation.var_domains[var_pos] = (rhs, rhs)
        rec = ClB.create_record(space.storage, VarDomainStorageUnit)
        space.record_ids_per_node[node_id] = rec

        # Restore
        ClB.restore_from_record!(space.storage, current.record)

        return Node(current, node_id, rec)
    end
end

ClA.stop(::FullExplSearchSpace) = false

ClA.tree_search_output(space::FullExplSearchSpace, _) = space.record_ids_per_node 


search_space = FullExplSearchSpace(formulation)
ClA.tree_search(ClA.DepthFirstStrategy(), search_space, nothing, nothing)



# ## API


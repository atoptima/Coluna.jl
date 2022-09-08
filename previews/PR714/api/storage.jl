# ```@meta
# CurrentModule = Coluna.Algorithm
# DocTestSetup = quote
#     using Coluna.Algorithm, Coluna.ColunaBase
# end
# ```

# # Storage API

# !!! warning
#    Missing intro, missing finding best solution.

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

# In this example, we want to find the best solution by enumerating all the possible
# solutions using a tree search.

# ### Formulation

# First, we import the dependencies

using Coluna;

# and we define some shortcuts for the sake of brievety.

const ClB = Coluna.ColunaBase;
const ClA = Coluna.Algorithm;

# We consider a data structure that maintain a model.

struct Formulation <: ClB.AbstractModel
    var_names::Vector{String}
    var_costs::Vector{Float64}
    var_domains::Vector{Tuple{Float64,Float64}}
end

# The model has 3 integer variables.
# The following arrays contain theirs names, costs, and initial bounds.

names = ["x1", "x2", "x3"];
costs = [-1, 1, -0.5];
initial_bounds = [(0,2), (0.9,2), (-1,0.5)];

# We instanciate the model.
formulation = Formulation(names, costs, initial_bounds);

# ### Storage

# The tree search algorithm will branch on all feasible integer values of 
# x1 at depth 1, x2 at depth 2, and x3 at depth 3.


# Each time, the tree search algorithm will evaluate a node, it will need to know the state
# of the formulation (e.g. domains of variables) at this node.
# To this purpose, we will use the storage.

# We create a storage unit for variable domains
struct VarDomainStorageUnit <: ClB.AbstractNewStorageUnit end

# and its constructor.
ClB.new_storage_unit(::Type{VarDomainStorageUnit}, _) = VarDomainStorageUnit()

# The state of the variables' domains at a given node is called a record. 
# The record is defined by the following data structure:
struct VarDomainRecord <: ClB.AbstractNewRecord
    var_domains::Vector{Tuple{Float64,Float64}}
end


# There is a one-to-one correspondance between storage unit types and record types. 
# This correspondance is implemented by the two following methods:
ClB.record_type(::Type{VarDomainStorageUnit}) = VarDomainRecord
ClB.storage_unit_type(::Type{VarDomainRecord}) = VarDomainStorageUnit

# We implement the method that creates a record of the variables' domains.
function ClB.new_record(::Type{VarDomainRecord}, id::Int, form::Formulation, ::VarDomainStorageUnit)
    return VarDomainRecord(copy(form.var_domains))
end

# We implement the method that restore the variables' domains of the formulation from a 
# given record.
function ClB.restore_from_record!(form::Formulation, ::VarDomainStorageUnit, record::VarDomainRecord)
    for (var_pos, (lb, ub)) in enumerate(record.var_domains)
        form.var_domains[var_pos] = (lb, ub)
    end
    return
end

# ### Tree search algorithm

# There is a tutorial about the tree search interface.

# We define the node data structure.
mutable struct Node <: ClA.AbstractNode
    depth::Int
    id::Int
    branch_description::String
    parent::Union{Nothing,Node}
    record
    function Node(parent, id, branch, record)
        depth = isnothing(parent) ? 0 : parent.depth + 1
        return new(depth, id, branch, parent, record)
    end
end

ClA.get_root(node::Node) = isnothing(node.parent) ? node : ClA.root(node.parent)
ClA.get_parent(node::Node) = node.parent

# We define the search space data structure.
# Note that we keep the storage in the search space because we have access to this
# data structure throughout the whole tree search execution.
mutable struct FullExplSearchSpace <: ClA.AbstractSearchSpace
    nb_nodes_generated::Int
    formulation::Formulation
    storage::ClB.NewStorage{Formulation}
    record_ids_per_node::Dict{Int, Any}
    function FullExplSearchSpace(form::Formulation)
        return new(0, form, ClB.NewStorage(form), Dict{Int,Any}())
    end
end

# We implement the method that returns the root node.
function ClA.new_root(space::FullExplSearchSpace, _)
    space.nb_nodes_generated += 1
    return Node(nothing, 1, "", nothing)
end

# We define a method that prints node information and the state of the formulation together.
function print_form(form, current)
    t = repeat("   ", current.depth)
    node = string("Node ", current.id, " ")
    branch = isempty(current.branch_description) ? "" : string("- Branch ", current.branch_description, " ")
    domains = mapreduce(*, enumerate(form.var_domains); init = "|| ") do e
        var_pos = first(e)
        lb, ub = last(e) 
        rhs = lb == ub ? string(" == ", lb) : string(" ∈ [", lb, ", ", ub, "] ")
        return string("x", var_pos, rhs, "  ")
    end
    println(t, node, branch, domains)
end;

# Let's now talk about how we will store and restore the state of the formulation in our
# tree search algorithm.

# The algorithm starts by creating and evaluating the root node.
# At this node the formulation is at its initial state, so it is ready to be evaluated.
# After node evaluation, the tree search branches, thus changing the formulation.
# Consequently, before branching, we generate a record of the state of the formulation 
# at the root node to be able to restore it later if needed.
# Otherwise, we will no longer know what the original formulation state was.
# Then, each time we generate a child, we restore the state of the formulation at the parent
# node, we create the branching constraint, we generate a record of the state of the 
# modified formulation in the child node, and we restore the state of the formulation at
# the current node.

# We could optimize the number of record/restore operations for this specific example but
# that is beyond the scope of this tutorial.

# We group operations that evaluate the current node in the following method.
function evaluate_current_node(space::FullExplSearchSpace, current)
    ## The root node does not have any record when its evaluation begins.
    if !isnothing(current.record)
         ## We restore the state of the formulation using the record stored in the current node.
        ClB.restore_from_record!(space.storage, current.record)
    end

    ## Print the current formulation
    print_form(space.formulation, current)

    ## Record current state of the formulation and keep the record in the current node.
    ## This is not necessary here but the formulation often changes during evaluation.
    current.record = ClB.create_record(space.storage, VarDomainStorageUnit)
end;

# We group operations that generate the children of the current node in the following 
# method.
function create_children(space::FullExplSearchSpace, current)
    ## Variable on which we branch.
    var_pos = current.depth + 1
    var_domain = get(space.formulation.var_domains, var_pos, (0,-1))

    return map(range(ceil(first(var_domain)), floor(last(var_domain)))) do rhs
        space.nb_nodes_generated += 1
        node_id = space.nb_nodes_generated

        ## Add branching constraint - change formulation.
        space.formulation.var_domains[var_pos] = (rhs, rhs)

        ## Record the state of the formulation with the branching constraint
        ## and keep it in the child node.
        rec = ClB.create_record(space.storage, VarDomainStorageUnit)
        space.record_ids_per_node[node_id] = rec

        ## Restore the state of the formulation at the current node.
        ClB.restore_from_record!(space.storage, current.record)

        branch = string("x", var_pos, " == ", rhs)
        return Node(current, node_id, branch, rec)
    end
end;

# We define the method `children` of the tree search API.
# It evaluates the current node and then generates its children.
function ClA.children(space::FullExplSearchSpace, current, _, _)
    evaluate_current_node(space, current)
    return create_children(space, current)
end

# We don't define specific stopping criterion.
ClA.stop(::FullExplSearchSpace) = false

# We return the node id where we found the best solution and the record at each node
# to make sure the example worked.
ClA.tree_search_output(space::FullExplSearchSpace, _) = space.record_ids_per_node 

# We run the example.
search_space = FullExplSearchSpace(formulation)
ClA.tree_search(ClA.DepthFirstStrategy(), search_space, nothing, nothing)


# ## API

# To summarize from a developer point of view, there is a one-to-one correspondance between
# storage unit types and record types. 
# this correspondance is implemented by methods 
# `record_type(StorageUnitType)` and `storage_unit_type(RecordType)`.

# The developer must also implement methods `new_storage_unit(StorageUnitType)` and
# `new_record(RecordType, id, model, storage_unit)` that must call constructors of the custom 
# storage unit and the one of its associated records. 
# Arguments of `new_record` allow the developer to record the state of entities from 
# both the storage unit and the model.

# At last, he must implement `restore_from_record!(storage_unit, model, record)` to restore the
# state of the entities represented by the storage unit.
# Entities can be in the storage unit, the model, or in both of them.

# ```@docs
#     record_type
#     storage_unit_type
#     new_storage_unit
#     new_record
#     restore_from_record!
# ```
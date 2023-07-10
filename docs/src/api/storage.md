```@meta
EditURL = "<unknown>/src/api/storage.jl"
```

# Storage API

```@meta
      CurrentModule = Coluna
```

!!! warning
   Missing intro, missing finding best solution.

## Introduction

A storage is a collection of storage units attached to a model.

A storage unit is a type that groups a set of entities for which we want to track the value
over time. We can distinguish two kinds of storage units. First, storage units that track
entities of the model (e.g. status of branching constraints, lower and upper bounds of variables).
Second, storage units that track additional data (e.g. data of algorithms).

Since the values of the entities grouped in a storage unit vary over time, we want to save
them at specific steps of the calculation flow to restore them later. The storage interface
provides two methods to do both actions:

```@docs
    ColunaBase.create_record
    ColunaBase.restore_from_record!
```

## Example

Let's see through a simple example how to implement this interface.

In this example, we want to find the best solution by enumerating all the possible
solutions using a tree search.

### Formulation

First, we import the dependencies

````@example storage
using Coluna;
nothing #hide
````

and we define some shortcuts for the sake of brievety.

````@example storage
const ClB = Coluna.ColunaBase;
const ClA = Coluna.Algorithm;
nothing #hide
````

We consider a data structure that maintain a model.

````@example storage
struct Formulation <: ClB.AbstractModel
    var_names::Vector{String}
    var_costs::Vector{Float64}
    var_domains::Vector{Tuple{Float64,Float64}}
end
````

The model has 3 integer variables.
The following arrays contain theirs names, costs, and initial bounds.

````@example storage
names = ["x1", "x2", "x3"];
costs = [-1, 1, -0.5];
initial_bounds = [(0,2), (0.9,2), (-1,0.5)];
nothing #hide
````

We instanciate the model.

````@example storage
formulation = Formulation(names, costs, initial_bounds);
nothing #hide
````

### Storage

The tree search algorithm will branch on all feasible integer values of
x1 at depth 1, x2 at depth 2, and x3 at depth 3.

Each time, the tree search algorithm will evaluate a node, it will need to know the state
of the formulation (e.g. domains of variables) at this node.
To this purpose, we will use the storage.

We create a storage unit for variable domains

````@example storage
struct VarDomainStorageUnit <: ClB.AbstractRecordUnit end
````

and its constructor.

````@example storage
ClB.storage_unit(::Type{VarDomainStorageUnit}, _) = VarDomainStorageUnit()
````

The state of the variables' domains at a given node is called a record.
The record is defined by the following data structure:

````@example storage
struct VarDomainRecord <: ClB.AbstractRecord
    var_domains::Vector{Tuple{Float64,Float64}}
end
````

There is a one-to-one correspondance between storage unit types and record types.
This correspondance is implemented by the two following methods:

````@example storage
ClB.record_type(::Type{VarDomainStorageUnit}) = VarDomainRecord
ClB.storage_unit_type(::Type{VarDomainRecord}) = VarDomainStorageUnit
````

We implement the method that creates a record of the variables' domains.

````@example storage
function ClB.record(::Type{VarDomainRecord}, id::Int, form::Formulation, ::VarDomainStorageUnit)
    return VarDomainRecord(copy(form.var_domains))
end
````

We implement the method that restore the variables' domains of the formulation from a
given record.

````@example storage
function ClB.restore_from_record!(form::Formulation, ::VarDomainStorageUnit, record::VarDomainRecord)
    for (var_pos, (lb, ub)) in enumerate(record.var_domains)
        form.var_domains[var_pos] = (lb, ub)
    end
    return
end
````

### Tree search algorithm

There is a tutorial about the tree search interface.

We define the node data structure.

````@example storage
mutable struct Node <: Coluna.TreeSearch.AbstractNode
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

Coluna.TreeSearch.get_root(node::Node) = isnothing(node.parent) ? node : Coluna.Treesearch.root(node.parent)
Coluna.TreeSearch.get_parent(node::Node) = node.parent
````

We define the search space data structure.
Note that we keep the storage in the search space because we have access to this
data structure throughout the whole tree search execution.

````@example storage
mutable struct FullExplSearchSpace <: Coluna.TreeSearch.AbstractSearchSpace
    nb_nodes_generated::Int
    formulation::Formulation
    solution::Tuple{Vector{Float64},Float64}
    storage::ClB.Storage{Formulation}
    record_ids_per_node::Dict{Int, Any}
    function FullExplSearchSpace(form::Formulation)
        return new(0, form, ([],Inf), ClB.Storage(form), Dict{Int,Any}())
    end
end
````

We implement the method that returns the root node.

````@example storage
function Coluna.TreeSearch.new_root(space::FullExplSearchSpace, _)
    space.nb_nodes_generated += 1
    return Node(nothing, 1, "", nothing)
end
````

We define a method that prints node information and the state of the formulation together.

````@example storage
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
nothing #hide
````

We write a function to calculate the solution at the current formulation of a node.

````@example storage
function compute_sol(space::FullExplSearchSpace, current)
    model = space.formulation
    sol = Float64[]
    sol_cost = 0.0
    for (cost, (ub, lb)) in Iterators.zip(model.var_costs, model.var_domains)
        var_val = (ub + lb) / 2.0
        sol_cost += var_val * cost
        push!(sol, var_val)
    end
    return sol, sol_cost
end
````

We write a method that updates the best-found solution when the node solution is better.

````@example storage
function update_best_sol!(space::FullExplSearchSpace, solution::Tuple{Vector{Float64},Float64})
    if last(solution) < last(space.solution)
        space.solution = solution
    end
end
````

Let's now talk about how we will store and restore the state of the formulation in our
tree search algorithm.

The algorithm starts by creating and evaluating the root node.
At this node the formulation is at its initial state, so it is ready to be evaluated.
After node evaluation, the tree search branches, thus changing the formulation.
Consequently, before branching, we generate a record of the state of the formulation
at the root node to be able to restore it later if needed.
Otherwise, we will no longer know what the original formulation state was.
Then, each time we generate a child, we restore the state of the formulation at the parent
node, we create the branching constraint, we generate a record of the state of the
modified formulation in the child node, and we restore the state of the formulation at
the current node.

We could optimize the number of record/restore operations for this specific example but
that is beyond the scope of this tutorial.

We group operations that evaluate the current node in the following method.

````@example storage
function evaluate_current_node(space::FullExplSearchSpace, current)
    # The root node does not have any record when its evaluation begins.
    if !isnothing(current.record)
         # We restore the state of the formulation using the record stored in the current node.
        ClB.restore_from_record!(space.storage, current.record)
    end

    # Print the current formulation
    print_form(space.formulation, current)

    # Compute solution
    sol = compute_sol(space, current)

    # Update best solution
    update_best_sol!(space, sol)

    # Record current state of the formulation and keep the record in the current node.
    # This is not necessary here but the formulation often changes during evaluation.
    current.record = ClB.create_record(space.storage, VarDomainStorageUnit)
end;
nothing #hide
````

We group operations that generate the children of the current node in the following
method.

````@example storage
function create_children(space::FullExplSearchSpace, current)
    # Variable on which we branch.
    var_pos = current.depth + 1
    var_domain = get(space.formulation.var_domains, var_pos, (0,-1))

    return map(range(ceil(first(var_domain)), floor(last(var_domain)))) do rhs
        space.nb_nodes_generated += 1
        node_id = space.nb_nodes_generated

        # Add branching constraint - change formulation.
        space.formulation.var_domains[var_pos] = (rhs, rhs)

        # Record the state of the formulation with the branching constraint
        # and keep it in the child node.
        rec = ClB.create_record(space.storage, VarDomainStorageUnit)
        space.record_ids_per_node[node_id] = rec

        # Restore the state of the formulation at the current node.
        ClB.restore_from_record!(space.storage, current.record)

        branch = string("x", var_pos, " == ", rhs)
        return Node(current, node_id, branch, rec)
    end
end;
nothing #hide
````

We define the method `children` of the tree search API.
It evaluates the current node and then generates its children.

````@example storage
function Coluna.TreeSearch.children(space::FullExplSearchSpace, current, _, _)
    evaluate_current_node(space, current)
    return create_children(space, current)
end
````

We don't define specific stopping criterion.

````@example storage
Coluna.TreeSearch.stop(::FullExplSearchSpace, _) = false
````

We return the best solution and the record at each node to make sure the example worked.

````@example storage
Coluna.TreeSearch.tree_search_output(space::FullExplSearchSpace, _) = space.record_ids_per_node, space.solution
````

We run the example.

````@example storage
search_space = FullExplSearchSpace(formulation)
Coluna.TreeSearch.tree_search(Coluna.TreeSearch.DepthFirstStrategy(), search_space, nothing, nothing)
````

## API

To summarize from a developer point of view, there is a one-to-one correspondance between
storage unit types and record types.
this correspondance is implemented by methods
`record_type(StorageUnitType)` and `storage_unit_type(RecordType)`.

The developer must also implement methods `storage_unit(StorageUnitType)` and
`record(RecordType, id, model, storage_unit)` that must call constructors of the custom
storage unit and the one of its associated records.
Arguments of `record` allow the developer to record the state of entities from
both the storage unit and the model.

At last, he must implement `restore_from_record!(storage_unit, model, record)` to restore the
state of the entities represented by the storage unit.
Entities can be in the storage unit, the model, or in both of them.

```@docs
    ColunaBase.record_type
    ColunaBase.storage_unit_type
    ColunaBase.storage_unit
    ColunaBase.record
    ColunaBase.restore_from_record!
```

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*


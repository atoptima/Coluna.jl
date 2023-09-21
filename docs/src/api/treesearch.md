# Tree search API


!!! danger
    Update needed.

Now, we define the two concepts we'll use in the tree search algorithms:
the *node* and the *search space*.
The third concept is the *explore strategy* and implemented in Coluna.


Every tree search algorithm must be associated to a search space.

## Implementing tree search interface

First, we indicate the type of search space used by our algorithms.
Note that the type of the search space can depends on the configuration of the algorithm.
So there is a 1-to-n relation between tree search algorithm configurations and search space.
because one search space can be used by several tree search algorithms configuration.

Now, we implement the method that calls the constructor of a search space.
The type of the search space is known from above method.
A search space may receive information from the tree-search algorithm.
The `model`, and `input` arguments are the same than those received by the tree search algorithm.

We implement the method that returns the root node.
The definition of the root node depends on the search space.

Then, we implement the method that converts the branching rules into nodes for the tree
search algorithm.

We implement the `node_change` method to update the search space called by the tree search
algorithm just after it finishes to evaluate a node and chooses the next one.
Be careful, this method is not called after the evaluation of a node when there is no
more unevaluated nodes (i.e. tree exploration is finished).

There are two ways to store the state of a formulation at a given node.
We can distribute information across the nodes or store the whole state at each node.
We follow the second way (so we don't need `previous`).

Method `after_conquer` is a callback to do some operations after the conquer of a node
and before the divide.
Here, we update the best solution found after the conquer algorithm.
We implement one method for each search space.

We implement getters to retrieve the input from the search space and the node.
The input is passed to the conquer and the divide algorithms.

At last, we implement methods that will return the output of the tree search algorithms.
We return the cost of the best solution found.
We write one method for each search space.

## API

### Search space

```@docs
Coluna.TreeSearch.AbstractSearchSpace
Coluna.TreeSearch.search_space_type
Coluna.TreeSearch.new_space
```

### Node

```@docs
Coluna.TreeSearch.AbstractNode
Coluna.TreeSearch.new_root
Coluna.TreeSearch.get_parent
Coluna.TreeSearch.get_priority
```
Additional methods needed for Coluna's algorithms:
```@docs
Coluna.TreeSearch.get_opt_state
Coluna.TreeSearch.get_records
Coluna.TreeSearch.get_branch_description
Coluna.TreeSearch.isroot
```

### Tree search algorithm

```@docs
Coluna.TreeSearch.AbstractExploreStrategy
Coluna.TreeSearch.tree_search
Coluna.TreeSearch.children
Coluna.TreeSearch.stop
Coluna.TreeSearch.tree_search_output
```

### Tree search algorithm for Coluna

```@docs
Coluna.Algorithm.AbstractColunaSearchSpace
```

The `children` method has a specific implementation for `AbstractColunaSearchSpace``
that involves following methods:

```@docs
Coluna.Algorithm.get_previous
Coluna.Algorithm.set_previous!
Coluna.Algorithm.node_change!
Coluna.Algorithm.get_divide
Coluna.Algorithm.get_reformulation
Coluna.Algorithm.get_input
Coluna.Algorithm.after_conquer!
Coluna.Algorithm.new_children
```

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*


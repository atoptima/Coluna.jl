# Algorithms and Strategies

Modern branch-and-cut-and-price frameworks combine several algorithms. Conquering a node may involve column generation, cut generation, a heuristic to find feasible solutions...  Generating children may involve simple algorithms (e.g. select more fractional variable) as well as more advanced methods that combine algorithms (e.g. strong branching).

`Coluna` proposes an environment that allows the user to easily combine algorithms to build advanced methods. A combination of algorithms is called a **Strategy**.

```julia
abstract type AbstractStrategy end
```

`Coluna` applies three different types of strategies in the course of solution. 

```julia
abstract type AbstractConquerStrategy <: AbstractStrategy end # To 'solve' the node
abstract type AbstractDivideStrategy <: AbstractStrategy end # To branch
abstract type AbstractTreeSearchStrategy <: AbstractStrategy end # To choose the node
```

The role of a strategy is to implement some of the sub-routines of the whole algorithm. Its use is linked to the part of the algorithm which it was designed for. For example, a strategy inheriting from `AbstractConquerStrategy` defines how a node of the branch-and-bound tree is going to be solved.

A combination of these three types of strategy is a `GlobalStrategy`. It defines the behavior of `Coluna` to solve the decomposed problem.

```julia
struct GlobalStrategy <: AbstractStrategy
	conquer_strategy::AbstractConquerStrategy
	divide_strateg::AbstractDivideStrategy
	tree_search_strategy::AbstractTreeSearchStrategy
end
```



## Algorithms as atomic sub-routines

Coluna provides several algorithms. For instance :

```julia
abstract type AbstractAlgorithm end
struct ColumnGeneration <: AbstractAlgorithm end
struct RestrictedMasterIpHeuristic <: AbstractAlgorithm end
struct BendersCutGeneration <: AbstractAlgorithm end
```

Each algorithm is defined by

```@docs
AbstractAlgorithmRecord
```

```@docs
prepare!
```

```@docs
run!
```

The user can create his algorithm outside Coluna. He must overload the data structures and methods introduced above.


```@meta
CurrentModule = Coluna
```

# Built-in algorithms for Branch-and-Bound

Branch-and-Bound algorithm aims to find an optimal solution of a MIP by successive divisions of the search space. An introduction to the Branch-and-Bound algorithm can be found here https://en.wikipedia.org/wiki/Branch_and_bound. 

Coluna provides a generic Branch-and-Bound algorithm whose three main elements can be easily modified::
- the conquer strategy: evaluation of the problem at a node of the branch-and-bound tree
- the branching strategy: ...
- the explore strategy: the evaluation order of your nodes 

The main loop used for the implementation of such algorithms is implemented by ```Algorithm.TreeSearchAlgorithm```. It is highly customizable so that the user can specify its own strategy to optimize each node (conquer) and to explore the tree:

```@docs
Algorithm.TreeSearchAlgorithm
```

In the following sections, we present the global setup of ```Algorithm.TreeSearchAlgorithm```. First, we describe the construction and the exploration of the search tree. Then, we "zoom" on the tree to describe the setup of Cut and Column Generation at each node.


## Manage the branching phase

When generating branches in the Branch-and-Bound process, two questions arise:
- which fractional variable to branch on ?
- which branch to explore first ? 
The two next sections describe the parameters that can be used to setup the branching phase. 

### Select the variable to branch on

```@docs
Branching.AbstractSelectionCriterion
Algorithm.FirstFoundCriterion
Algorithm.MostFractionalCriterion
```

```@docs
Algorithm.SingleVarBranchingRule
```


### Division of the search space

```@docs
Algorithm.NoBranching
Algorithm.ClassicBranching
Algorithm.StrongBranching
```

## Optimize each node by Column and/or Cut Generation

TODO: add precisions to indicate to the user what is used with DW or Benders respectively

```@docs
Algorithm.ColCutGenConquer
```

```@docs
Algorithm.ColumnGeneration
```

## Basic algorithms

### Optimize a linear program

```@docs
Algorithm.SolveLpForm
```


### Optimize an mixed-integer program / solve a combinatorial problem

```@docs
Algorithm.SolveIpForm
Algorithm.MoiOptimize
Algorithm.UserOptimize
Algorithm.CustomOptimize
```
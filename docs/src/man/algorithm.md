```@meta
CurrentModule = Coluna
```

# Built-in algorithms for Branch-and-Bound

Branch-and-Bound algorithm aims to find an optimal solution of a MIP by successive divisions of the search space. An introduction to the Branch-and-Bound algorithm can be found [here](https://en.wikipedia.org/wiki/Branch_and_bound). 

Coluna provides a generic Branch-and-Bound algorithm whose three main elements can be easily modified:

- the branching strategy: how to create new branches i.e. how to divise the search space
- the explore strategy: the evaluation order of your nodes 
- the conquer strategy: evaluation of the problem at a node of the Branch-and-Bound tree. Depending on the type of decomposition used ahead of the Branch-and-Bound, you can use either Column Generation (if your problem is decomposed following Dantzig-Wolfe transformation) and/or Cut Generation (for Dantzig-Wolfe and Benders decompositions). 

The main loop of the Branch-and-Bound tree is implemented by ```Algorithm.TreeSearchAlgorithm```:

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
Algorithm.Branching.AbstractSelectionCriterion
```
```@docs
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
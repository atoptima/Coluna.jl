```@meta
CurrentModule = Coluna
```

# Algorithms

TODO : Description of how algorithms work.

## Tree search algorithm (branch-and-bound)

```@docs
Algorithm.TreeSearchAlgorithm
```

## Conquer algorithm

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



## Divide algorithms

```@docs
Algorithm.NoBranching
Algorithm.ClassicBranching
Algorithm.StrongBranching
```
### Selection criteria

```@docs
Branching.AbstractSelectionCriterion
Algorithm.FirstFoundCriterion
Algorithm.MostFractionalCriterion
```

### Branching rules

```@docs
Algorithm.SingleVarBranchingRule
```

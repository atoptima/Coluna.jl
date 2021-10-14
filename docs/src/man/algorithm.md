```@meta
CurrentModule = Coluna.Algorithm
DocTestSetup = quote
    using Coluna.Algorithm
end
```
# Algorithms

TODO : Description of how algorithms work.

## Tree search algorithm (branch-and-bound)

```@docs
TreeSearchAlgorithm
```

## Conquer algorithm

```@docs
ColCutGenConquer
```

```@docs
ColumnGeneration
```

## Basic algorithms

### Optimize a linear program

```@docs
SolveLpForm
```

### Optimize an mixed-integer program / solve a combinatorial problem

```@docs
SolveIpForm
MoiOptimize
UserOptimize
CustomOptimize
```

```@meta
CurrentModule = nothing
DocTestSetup = nothing
```

## Divide algorithms

```@docs
NoBranching
SimpleBranching
StrongBranching
```
### Selection criteria

```@docs
AbstractSelectionCriterion
FirstFoundCriterion
MostFractionalCriterion
```

### Branching rules

```@docs
SingleVarBranchingRule
```

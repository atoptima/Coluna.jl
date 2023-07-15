# Setup decomposition with BlockDecomposition

BlockDecomposition allows the user to perform two types of decomposition using
[`BlockDecomposition.@dantzig_wolfe_decomposition`](@ref) and [`BlockDecomposition.@benders_decomposition`](@ref).

For both decompositions, the index-set of the subproblems is declared through an [`BlockDecomposition.@axis`](@ref). 
It returns an array.
Each value of the array is a subproblem index wrapped into a `BlockDecomposition.AxisId`.
Each time BlockDecomposition finds an `AxisId` in the indices of a variable
and a constraint, it knows to which subproblem the variable or the constraint belongs.


The macro creates a decomposition tree where the root is the master and the depth
is the number of nested decompositions. A classic Dantzig-Wolfe or Benders
decomposition produces a decomposition tree of depth 1.
At the moment, nested decomposition is not supported.

You can get the subproblem membership of all variables and constraints
using the method [`BlockDecomposition.annotation`](@ref).

BlockDecomposition does not change the JuMP model.
It decorates the model with additional information.
All this information is stored in the `ext` field of the JuMP model.

```@meta
CurrentModule = BlockDecomposition
```

## Errors and warnings

```@docs
MasterVarInDwSp
VarsOfSameDwSpInMaster
```

## References

```@docs
BlockModel
```

These are the methods to decompose a JuMP model :
```@docs
@axis
@benders_decomposition
@dantzig_wolfe_decomposition
```

These are the methods to set additional information to the decomposition (multiplicity and optimizers) :

```@docs
getmaster
getsubproblems
specify!
```

This method helps you to check your decomposition :

```@docs
annotation
```

```@meta
CurrentModule = nothing
```
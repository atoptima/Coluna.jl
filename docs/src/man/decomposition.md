# Decomposition

Coluna is a framework to optimizate mixed-integer programs that you can decompose.
In other words, if you remove the linking constraints or linking variables from you
program, you'll get sets of constraints (blocks) that you can solve independently.

## Types of decomposition

### Dantzig-Wolfe decomposition

Let's consider the following coefficient matrix that has a block diagonal structure
in gray and some linking constraints in blue :

![Dantzig-Wolfe decomposition](../static/dwdec.png)

You penalize the violation of the linking constraints in the
objective function. You can then solve the blocks independently.

The Dantzig-Wolfe reformulation gives raise to a master problem with an
exponential number of variables. Coluna dynamically generates these variables by
solving the subproblems. It's the column generation algorithm.

### Benders decomposition

Let's consider the following coefficient matrix that has a block diagonal structure
in gray and some linking variables in blue :

![Benders decomposition](../static/bdec.png)

You fix the complicated variables, then you can solve the blocks
independently.


## BlockDecomposition

The index-set of the subproblems is declared through an [`BlockDecomposition.@axis`](@ref). 
It returns an array.
Each value of the array is a subproblem index wrapped into a `BlockDecomposition.AxisId`.
Each time BlockDecomposition finds an `AxisId` in the indices of a variable
and a constraint, it knows to which subproblem the variable or the constraint belongs.

BlockDecomposition allows the user to perform two types of decomposition using
[`BlockDecomposition.@dantzig_wolfe_decomposition`](@ref) and [`BlockDecomposition.@benders_decomposition`](@ref).

The macro creates a decomposition tree where the root is the master and the depth
is the number of nested decomposition. A classic Dantzig-Wolfe or Benders
decomposition produces a decomposition tree of depth 1.
At the moment, nested decomposition is not supported.

You can get the subproblem membership of all variables and constraints
using the method [`BlockDecomposition.annotation`](@ref).

BlockDecomposition does not change the JuMP model.
It decorates the model with additional information.
All these information are stored in the `ext` field of the JuMP model.


### References

```@meta
DocTestSetup = quote using BlockDecomposition end
```

```@docs
BlockDecomposition.annotation
BlockDecomposition.@axis
BlockDecomposition.@bender_decomposition
BlockDecomposition.@dantzig_wolfe_decomposition
```

```@meta
DocTestSetup = nothing
```


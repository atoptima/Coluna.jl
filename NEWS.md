# Coluna 0.6.6

- DynamicSparseArrays 0.7 main features are tested against JET.

# Coluna 0.6.5

This is a minor update that provides documentation together with tests and several bug fixes for the tree search
algorithm.

Stabilization for the column generation algorithm is now in beta version.

# Coluna 0.6.4

This is a minor update that provides documentation and a bug fix in the integration of the column generation algorithm with the branch-and-bound.
 
# Coluna 0.6.3

This is a minor update that provides:
- improvements in column generation interface and generic functions
- bugfix in column generation (wrong calculation of the lagrangian dual bound when identical subproblems)
- column generation stabilization (alpha version)

# Coluna 0.6.2

This is a minor update that provides fixes in the Benders cut generation algorithm and documentation for the Benders API.

# Coluna 0.6.1

This is a minor update but some changes may affect the integration of external algorithms 
with Coluna.

Fixes:
- Workflow of Benders algorithms is now fixed. More documentation will be available soon.

Changes:
- `ColunaBase.Bound{Space, Sense}` is now `ColunaBase.Bound`. The two parameters are now flags in the struct. All mathematical operations are not supported anymore, we need to convert the `Bound` to a `<:Real`.
- `Algorithm.OptimizationState{F,S}` does not depend on the objective sense anymore and is now `Algorithm.OptimizationState{F}`
- Improve Benders implementation & starting writing documentation


# Coluna 0.6.0

This release is a major update of the algorithms as it implements the architectural choices of 0.5.0 in column generation and benders.

About the algorithms:
- We separated the generic codes and the interfaces from the implementation (doc will be available soon). The default implementation of algorithms is in the `Algorithm` module. Four new submodules `TreeSearch`, `Branching`, `ColGen`, and `Benders` contain generic code and interface. They are independent.
- Refactoring of column generation
- Refactoring and draft of benders cut generation
- Tests and documentation
- Various bug fixes
- Some regressions as indicated in the Readme.

# Coluna 0.5.0

This release is a major update of the algorithms.
From now on, we will release new versions more frequently.

In the `Algorithm` submodule:

- Interface & generic implementation for the tree search algorithm; default implementation of a branch & bound; documentation
- Simplified interface for storages; documentation
- Interface & generic implementation for the branching algorithm; interface & default implementation for the strong branching; documentation
- Preparation of the conquer algorithm refactoring 
- Preparation of the column generation algorithm refactoring 
- Preparation of the refactoring of the algorithms calling the subsolver
- End of development of the Preprocessing algorithm (no unit tests and had bugs); it will be replaced by the Presolve algorithm that does not work
- Increase of the reduced cost tolerance in the column generation algorithm
- Separation of algorithm and printing logic
- Various bug fixes


In the `MathProg` submodule:

- `VarIds` & `ConstrIds` are subtype of Integer so we can use them as indices of sparse vectors and arrays
- Solution are stored in sparse array from `SparseArrays` (not a packed memory array from `DynamicSparseArray` anymore because the solution is static)


Other:

- Documentation of dynamic sparse arrays
- Support of expressions in BlockDecomposition

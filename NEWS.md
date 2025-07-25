# Coluna 0.8.2

This is a minor update which serves to support the latest versions of `BlockDecomposition` and `MathOptInterface`.


# Coluna 0.8.1

This is a minor update 

Features:
- A new parameter whether to presolve the DW reformulation or not
- A new parameter whether to do strong integrality check in column generation

Fixed bugs:
- A bug in the presolve algorithm when the partial solution to fix contains deactivated variables

# Coluna 0.8.0

This is a major update which implements the presolve algorithm. 

Other features:
- Possibility for the user to get the custom data of a column (i.e., SP solution) in the global solution. 
- Print the master and DW subproblem with only user-defined variables and constraints.
- One can now specify the branching priority of columns, either through branching priority of DW sub-problems, 
  or directly in the CustomData of the SP solution 

It also resolves some bugs:
- Correction in dual price smoothing stabilization
- Correction in integrality check inside column generation. 
- Correction in calculating initial (global) bounds of the master representative (implicit) variables.
- Corrected the "Sleeping bug" related to the Id type promotion, which appeared in Julia 1.10
- Removed superfluous Heuristics module.
- Global dual bound printer is corrected
- Strong branching printer is corrected. 

# Coluna 0.7.0

This is minor update with two breaking changes:
- Bounds of the representative variables in the master are now global (multiplicity of subproblem * bound)
- DivideOutput has only one argument now
- Generating child nodes from branching candidates is moved from select!() to advanced_select!(). This allows us to simplify the interface of branching candidates (we remove nodes from them). This simplification also serves to prepare the diving implementation. (PR 1072)
- SbNode and Node definitions have been changed.

# Coluna 0.6.6

- DynamicSparseArrays 0.7 main features are tested against JET.
- Bug with the integer tolerance of projected solutions fixed
- Improvements about the construction of the reformulation
- Strong branching was not returning ip solution found when evaluating candidates

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

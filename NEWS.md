# Coluna 0.6.0 Release notes

This release is a major update of the algorithms as it implements the architectural choices of 0.5.0 in column generation and benders.

About the algorithms:
- We separated the generic codes and the interfaces from the implementation (doc will be available soon). The default implementation of algorithms is in the `Algorithm` module. Four new submodules `TreeSearch`, `Branching`, `ColGen`, and `Benders` contain generic code and interface. They are independant.
- Refactoring of column generation
- Refactoring and draft of benders cut generation
- Tests and documentation
- Various bug fixes
- Some regressions as indicated in the Readme.

# Coluna 0.5.0 Release notes

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

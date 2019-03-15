# Installation Guide

Coluna requires Julia, JuMP and GLPK as the default underlying MOI Optimizer
for the master and the subproblems.

## Getting Coluna.jl

Coluna.jl can be installed using the package manager of Julia. To install
it:

1. Go the Pkg-REPL-mode. The Pkg REPL-mode is entered
   from the Julia REPL using the key ].

2. Then run the following command
   ```
   pkg> add https://github.com/atoptima/Coluna.jl.git
   ```

This command will install Coluna.jl and its dependencies.

To start using Coluna.jl, it should be imported into the local scope.

```julia
using Coluna
```

## Developer installation

Install Coluna
```
pkg> dev https://github.com/atoptima/Coluna.jl.git
```
Each time you work on Coluna, do :
```
shell> cd ~/.julia/dev/
pkg> activate Coluna
pkg> update
pkg> test
julia> # work with Coluna
```


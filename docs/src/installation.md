# Installation Guide

Coluna requires Julia, MOI and GLPK as the default underlying MOI Optimizer
for the master and the subproblems.

## Getting Coluna.jl

Coluna.jl can be installed using the package manager of Julia. To install
it, run

    julia> Pkg.clone("git@github.com:ResourceMind/Coluna.jl.git")

This command will, recursively, install Coluna.jl and its dependencies.

To start using Coluna.jl, it should be imported into the local scope.

```julia
using Coluna
```

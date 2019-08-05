# Installation

Coluna is a package for [Julia 1.0+](https://julialang.org/). 

It requires `JuMP` to model the problem, `BlockDecomposition` to define the decomposition, and `GLPK` as the default underlying MOI Optimizer
for the master and the subproblems.

## Getting Coluna.jl

Coluna.jl can be installed using the package manager of Julia. 
Go to the Pkg-REPL-mode. 
The Pkg REPL-mode is entered from the Julia REPL using the key `]`. 
Then, run the following command :

```
pkg> add https://github.com/atoptima/Coluna.jl.git
```

This command will install Coluna.jl and its dependencies.

You can start using Coluna by doing :

```julia
using Coluna
```


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
   (1.0) pkg> add https://github.com/atoptima/Coluna.jl.git
   ```

This command will, recursively, install Coluna.jl and its dependencies.

To start using Coluna.jl, it should be imported into the local scope.

```julia
using Coluna
```

## Developer installation

1. Create a `dev` directory in the julia folder
```
cd .julia
mkdir dev
```

2. Clone Coluna in `dev`
```
git clone https://github.com/atoptima/Coluna.jl.git
```

3. Go the Pkg-REPL-mode. The Pkg REPL-mode is entered
   from the Julia REPL using the key ].

4. Run the following command
```julia
activate Coluna.jl
```

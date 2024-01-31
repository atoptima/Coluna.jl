# Coluna.jl

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://atoptima.github.io/Coluna.jl/stable)
![CI](https://github.com/atoptima/Coluna.jl/workflows/CI/badge.svg?branch=master)
[![codecov](https://codecov.io/gh/atoptima/Coluna.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/atoptima/Coluna.jl)
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)


Coluna is a branch-and-price-and-cut framework written in Julia.
You write an original MIP that models your problem using the
[JuMP](https://github.com/jump-dev/JuMP.jl) modeling language and our specific extension
[BlockDecomposition](https://github.com/atoptima/BlockDecomposition.jl) offers a syntax
to specify the problem decomposition. Then, Coluna reformulates the original MIP and
optimizes the reformulation using the algorithms you choose.
Coluna aims to be very modular and tweakable so that you can define the behavior of
your customized branch-and-price-and-cut algorithm.

## Installation

Coluna is a [Julia Language](https://julialang.org/) package.

You can install Coluna through the Julia package manager.
Open Julia's interactive session (REPL) and type:

```
   ] add Coluna
```

The documentation provides examples to run advanced branch-cut-and-price. Improvements in documentation are expected in the future. 
You can browse the [stable documentation](https://atoptima.github.io/Coluna.jl/stable) if you work with the latest release
or the [dev documentation](https://atoptima.github.io/Coluna.jl/latest) if you work with the master version of Coluna.

## Features

We aim to integrate into Coluna the state-of-the-art techniques used for
branch-and-cut-and-price algorithms.

- ![Stable](https://img.shields.io/badge/-stable-brightgreen) Features which are well-tested (but performance may still be improved).  
  - Dantzig-Wolfe decomposition
  - Branch-and-bound algorithm (with branching in master)
  - Column generation (MILP pricing solver/pricing callback)
- ![Beta](https://img.shields.io/badge/-beta-green) Features that work well but need more tests/usage and performance review before being stable:
  - Strong branching (with branching in master)
  - Stabilization for column generation 
  - Cut generation (robust and non-robust)
  - Benders decomposition
  - Preprocessing (presolve) of formulations and reformulations
- ![Alpha](https://img.shields.io/badge/-alpha-yellow) Features that should work. Structural work is done but these features may have bugs:
  - Benders cut generation
- ![Dev](https://img.shields.io/badge/-dev-orange) Features in development.
  - Clean-up of the master formulation (removal of unpromising columns and cuts) 
  - Saving/restoring LP basis when changing a node in branch-and-bound

## Contributing

If you encounter a bug or something unexpected happens while using Coluna,
please open an issue via the GitHub issues tracker.

See the list of [contributors](https://github.com/atoptima/Coluna.jl/graphs/contributors)
who make Coluna possible.


## Premium support

Using Coluna for your business?
[Contact us](https://atoptima.com/contact/?sup) to get tailored and qualified support.

## Acknowledgments

The platform development has received an important support grant from the international scientific society [**Mathematical Optimization Society (MOS)**](http://www.mathopt.org/) and [**Région Nouvelle-Aquitaine**](https://www.nouvelle-aquitaine.fr/).

[**Atoptima**](https://atoptima.com/)

[**University of Bordeaux**](https://www.u-bordeaux.fr/)

[**Inria**](https://www.inria.fr/fr)

## Related packages

- [BlockDecomposition](https://github.com/atoptima/BlockDecomposition.jl) is a JuMP extension to model decomposition.
- [DynamicSparseArrays](https://github.com/atoptima/DynamicSparseArrays.jl) provides data structures based on packed-memory arrays for dynamic sparse matrices.

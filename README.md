# Coluna.jl

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://atoptima.github.io/Coluna.jl/stable)
![CI](https://github.com/atoptima/Coluna.jl/workflows/CI/badge.svg?branch=master)
[![codecov](https://codecov.io/gh/atoptima/Coluna.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/atoptima/Coluna.jl)
[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
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

The documentation is still under construction but provides examples to run advanced branch-cut-and-price.
You can browse the [stable documentation](https://atoptima.github.io/Coluna.jl/stable) if you work with the latest release
or the [dev documentation](https://atoptima.github.io/Coluna.jl/latest) if you work with the master version of Coluna.

## Features

We aim to integrate into Coluna the state-of-the-art techniques used for
branch-and-cut-and-price algorithms.

The latest minor release `0.6.0` suffers from regressions as some features are not available anymore. Indeed, we focused on the correctness of the algorithms and all the missing features will be back soon, well implemented and well tested.

- ![Stable](https://img.shields.io/badge/-stable-brightgreen) No stable feature at the moment
- ![Beta](https://img.shields.io/badge/-beta-green) Features that work well but need more tests/usage and performance review before being stable:
  - Dantzig-Wolfe decomposition
  - Benders decomposition
  - Branch-and-bound algorithm
  - Column generation (MILP pricing solver/pricing callback)
  - Cut generation (robust and non-robust cut generation)
  - Strong-branching
- ![Alpha](https://img.shields.io/badge/-alpha-yellow) Features that should work. Structural work is done but these features may have bugs:
  - Benders cut generation
  - Stabilization for column generation 
- ![Dev](https://img.shields.io/badge/-dev-orange) Features in development.
  - Stabilization for benders.
  - Clean-up of large scales formulation (regression)
  - Preprocessing of formulations and reformulations

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

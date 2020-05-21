# Coluna.jl

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://atoptima.github.io/Coluna.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://atoptima.github.io/Coluna.jl/latest)
[![Build Status](https://travis-ci.org/atoptima/Coluna.jl.svg?branch=master)](https://travis-ci.org/atoptima/Coluna.jl)
[![codecov](https://codecov.io/gh/atoptima/Coluna.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/atoptima/Coluna.jl)
[![Discord](https://img.shields.io/discord/651851215264808971?logo=discord)](https://discord.gg/cg77wFW)
[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)


Coluna is a branch-and-price-and-cut framework written in Julia. 
The user introduces an original MIP that models his problem using the 
[JuMP](https://github.com/JuliaOpt/JuMP.jl) modeling language and our specific extension 
[BlockDecomposition](https://github.com/atoptima/BlockDecomposition.jl) that offers a syntax 
to specify the problem decomposition. Then, Coluna reformulates the original MIP and 
optimizes the reformulation using the algorithms chosen by the user. 
Coluna aims to be very modular and tweakable so that any user can define the behavior of
his customized branch-and-price-and-cut algorithm. 

## Installation

Coluna is package for Julia 1.0+

You can install Coluna through the Julia package manager: 

```
   ] add Coluna
```

See the [documentation](https://atoptima.github.io/Coluna.jl/stable) for examples.

If you are working with the development version, you may want to check the [dev documentation](https://atoptima.github.io/Coluna.jl/latest).

## Features

We aim to integrate to Coluna the state-of-the-art techniques used for 
branch-and-cut-and-price algorithms. We look for beta users as Coluna is under
active development. 

- ![Stable](https://img.shields.io/badge/-stable-brightgreen) No stable feature at the moment
- ![Beta](https://img.shields.io/badge/-beta-green) Features that work but you may have some bugs:
  - Dantzig-Wolfe decomposition 
  - Column generation algorithm
  - Pricing callback
- ![Alpha](https://img.shields.io/badge/-alpha-yellow) Features that should work. Structural work is done but it may be not performant:
  - Branch-and-price-and-cut algorithm
  - Benders decomposition
- ![Dev](https://img.shields.io/badge/-dev-orange) Features in development, foundations have been laid:
  - Nested/Recursive decomposition
  - Cuts generation
  - Stabilisation and other convergence speed-up methods
  - Strong-branching 
  - Parallelisation of the Branch-and-Bound Tree Search 
  - Cleaning up of large scale formulations 
- ![Future](https://img.shields.io/badge/-future-red) Future features:
  - Mixed Dantzig-Benders decomposition
  - Preprocessing specific to reformulated problems

## Contributing

Contributors are first and foremost users of the framework. If you encounter a
bug or something unexpected happens while using Coluna, please open an issue via
the GitHub issues tracker or chat with us on the 
[discord](https://discord.gg/cg77wFW) dedicated to Coluna.

You can suggest new features or ways to improve the package.

You can also suggest and add new models in [ColunaDemos](https://github.com/atoptima/ColunaDemos.jl)
for tests and benchmarks.

See the list of [contributors](https://github.com/atoptima/Coluna.jl/graphs/contributors)
who make Coluna possible.

## Acknowledgments

The platform development has received an important support grant from the international scientific society [**Mathematical Optimization Society (MOS)**](http://www.mathopt.org/) and [**Région Nouvelle-Aquitaine**](https://www.nouvelle-aquitaine.fr/)

[**Atoptima**](https://atoptima.com/)

[**University of Bordeaux**](https://www.u-bordeaux.fr/)

[**Inria**](https://www.inria.fr/fr)
# Coluna.jl

[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://atoptima.github.io/Coluna.jl/latest)
[![Build Status](https://travis-ci.org/atoptima/Coluna.jl.svg?branch=master)](https://travis-ci.org/atoptima/Coluna.jl)
[![codecov](https://codecov.io/gh/atoptima/Coluna.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/atoptima/Coluna.jl)
[![Join the chat at https://gitter.im/Coluna-dev/community](https://badges.gitter.im/Coluna-dev/community.svg)](https://gitter.im/Coluna-dev/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

## What

Coluna.jl is a work-in-progess framework that allows the user to define and solve a deposed 'Reformulation' from an original 'Compact' model. It aims to be very modular and tweakable so that an experienced user can define the desired behaviour on many of the algorithm steps through overriding default methods.


## How it works

Coluna uses BlockDecomposition.jl and JuMP.jl to gather all the information needed related to the model to be solved as well as the desired decomposition structure.

Once all this information is given by the user, Coluna is able to break the original model in all its sub-structures witch will be solved in a branch-and-bound fashion by applied a master-slave algorithm.


## Current state

The master version of Coluna is able to solve a standard Branch-and-Price algorithm where master and subproblems are solved by LP and MILP respectively. Coluna is also capable of using a restricted master IP heuristic in order to find primal bounds faster.


## Future goals

We aim to integrate to Coluna the state-of-the-art strategies and algorithms used in some of the best research teams on combinatorial optimisation.

As functionality goes, we aim to provide the support for:

- [x] Dantzig-Wolfe decomposition 
- [ ] Benders decomposition
- [ ] Nested and mixed Dantzig-Benders decomposition
- [ ] Possibility for the user to override a great part of the solution routines in order to have a fully customisable framework
- [x] Column generation
- [ ] Cuts generation
- [ ] Ad-hoc customised oracles for solving subproblems / separation routines
- [ ] Preprocessing, stabilisation, strong-branching and other standard speed-up methods


## Authors

The current main contributors to Coluna.jl are:

- François Vanderbeck
- Guillaume Marques
- Vitor Nesello

## Contributing

See the list of current issues, choose one, and open a PR with a proposition.
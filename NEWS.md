# Coluna 0.3.13 Release notes

## New features

- none

## Changes

### Pricing callback API

The pricing callback has to transmit the dual bound which is use to compute the contribution of the subproblem to the lagrangian bound in column generation.

```julia
MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), db)
```

Moreover, it's not possible to retrieve the column generation stage from the callback data anymore.


## Dep updates

- BlockDecomposition -> v1.5
- MOI -> v0.9


## Deprecations 

- none

## Removed

- Specific treatement of single variable constraint of a formulation in `MathProg`.
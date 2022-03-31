# Coluna 0.4.0 Release notes

Major update of the MOI wrapper and various bugfixes.
## Changes

### Pricing callback API

The pricing callback has to transmit the dual bound which is use to compute the contribution of the subproblem to the lagrangian bound in column generation.

```julia
MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), db)
```

Moreover, it's not possible to retrieve the column generation stage from the callback data anymore.


## Dep updates

- BlockDecomposition -> v1.7
- MOI -> 1


## Removed

- Specific treatement of single variable constraint of a formulation in `MathProg`.
# Home

Coluna.jl package provides a branch-and-price-and-cut framework
that can decompose (with user hints) and solve models
formulated with JuMP (or MOI). It relies on MOI optimizers in order
to solve the decomposed blocks (master, pricing, separation...).

The user must be familiar with the syntax of JuMP, which is described in its
[documentation](http://www.juliaopt.org/JuMP.jl/v0.19.0/).

## Manual Outline

```@contents
Pages = [
    "index.md",
    "installation.md",
    "introduction.md",
    "basic.md",
]
Depth = 1
```    

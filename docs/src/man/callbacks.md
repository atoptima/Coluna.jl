# Callbacks

Callbacks are functions defined by the user that allow him to take over part of the default
algorithm.
The more classical callbacks in a branch-and-price solver are:

- Pricing callback that takes over the procedure to determine whether the current master LP
    solution is optimum or produces an entering variable with negative reduced cost by solving subproblems
- Separation callback that takes over the procedure to determine whether the current master
    LP solution is feasible or produces a valid problem constraint that is violated
- Branching callback that takes over the procedure to determine whether the current master
    LP solution is integer or produces a valid branching disjunctive constraint that rules out
    the current fractional solution.

!!! note
    You can't change the original formulation in a callback because Coluna does not propagate the
    changes into the reformulation and does not check if solutions found are still feasible.

## Pricing callback

The pricing callback let you define how to solve the subproblems of a Dantzig-Wolfe
decomposition to generate a new entering column in the master program.
This callback is useful when you know an efficient algorithm to solve the subproblems,
i.e. an algorithm better than solving the subproblem with a MIP solver.

See the example in the manual [Pricing callback](@ref).

### Errors and Warnings
```@meta
CurrentModule = Coluna.Algorithm
DocTestSetup = quote
    using Coluna.Algorithm
end
```

```@docs
Algorithm.IncorrectPricingDualBound
Algorithm.MissingPricingDualBound
Algorithm.MultiplePricingDualBounds
```

```@meta
CurrentModule = nothing
DocTestSetup = nothing
```

# Separation callbacks

Separation callbacks let you define how to separate cuts or constraints.

## Facultative & essential cuts (user cut & lazy constraint)

This callback allows you to add cuts to the master problem.
The cuts must be expressed in terms of the original variables.
Then, Coluna expresses them over the master variables.
You can find an example of [essential cut separation](https://jump.dev/JuMP.jl/stable/tutorials/Mixed-integer%20linear%20programs/callbacks/#Lazy-constraints)
and [facultative cut separation](https://jump.dev/JuMP.jl/stable/tutorials/Mixed-integer%20linear%20programs/callbacks/#User-cut)
in the JuMP documentation.



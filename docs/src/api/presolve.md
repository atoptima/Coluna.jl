# Presolve

Currently, the presolve algorithm supports only the Dantzig-Wolfe decomposition.

The presolve algorithm operates on matrix representations of the formulation.
It requires two representations of the master formulation:

- the restricted master that contains master column variables, pure master variables and artificial variables;

- the representative master that contains subproblem representative variables and pure master variables;

and the representation of the pricing subproblems.

The current presolve operations available are the following (taxonomy of Achterberg et al. 2016):
- model cleanup & removal of redundant constraints
- bound strengthening
- removal of fixed variables

## Partial solution

The presolve algorithm has the responsibility to define and fix a partial solution
when it exists.
When a variable $x$ a value $\bar{x} > 0$ (resp. $\bar{x}0 < 0$) in the partial solution, 
it means that $x$ has a lower (upper) bounds $\bar{x}$ that will definitely be part of
the solution at the current branch-and-bound node and its successors.

In other words, the partial solution describes a minimal distance of the variables from
zero in the all the solutions to a problem at a given branch-and-bound node.
It always restricts the domain of the variables (i.e. increase distance from zero).
The only way to relax the domains is to backtrack to an ancestor of the current
branch-and-bound node (i.e. go back to a previous partial solution).

Fixing a partial solution is straightforward for positive and negative variables.
When the variable has a positive (negative) lower bound, this bound is added to the partial solution and we propagate this change into the formulation.

For the following formulation

$$\min \{ cx ~:~ Ax \leq  b, ~ x \geq l \}$$

the partial solution is $\bar{x} = l$ and given that $x = \bar{x} + x'$,
the new formulation is:

$$\min \{ c\bar{x} + cx' ~:~ Ax' \leq b - \bar{x},~ x' \geq 0 \}$$




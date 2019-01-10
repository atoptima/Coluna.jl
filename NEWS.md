Coluna release notes
====================================

v0.0.1 (January 10, 2019)
-------------------------

- Text book column generation implementation.
- JuMP-compatible thanks to the MOI interface.
- Branching in the master on pure master variables.
- master_factory and pricing_factory to use any MOI solver as for
  solving respectively the restricted master and the pricing subproblem.
- Problem decomposition using either annotations or a decomposition
  function.
- Restricted master MIP heuristic allows to find integer solutions without
  branching.
- Pricing subproblems with cardinality other than 1.
- Automated global artificial variables.
- Automated convexity constraint.

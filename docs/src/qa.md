# Question & Answer

#### Default algorithms of Coluna do not beat the commercial solver I usually use. Is it normal ?

Yes it is.

Solvers such as Gurobi, Cplex ... are handy powerful black-box tools. 
They can run a very efficient presolve step to simplify the formulation,
automatically apply lots of valid inequalities (such as MIR or cover cuts), 
choose good branching strategies, or also run heuristics.
However, when your formulation reaches a certain size,
commercial solvers may run for hours without finding anything.
This is the point where you may want to decompose your formulation.

Coluna is a framework, not a solver.
It provides algorithms to try column generation on your problem very easily.
Then, you can devise your own branch-cut-and-price algorithm on top of Coluna's algorithms.
to scale up and hopefully beats the commercial solver.

To start customizing Coluna for your own problem, 
you can [separate valid inequalities](../user/callbacks/#Separation-callbacks) 
or [call your own algorithm that optimizes subproblems](../user/callbacks/#Pricing-callback).

## I'm using Gurobi as a subsolver

#### My license prevents me from running several environments at the same time. How can I use a single environment for the master and all subproblems?



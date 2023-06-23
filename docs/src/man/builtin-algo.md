```@meta
CurrentModule = Coluna
```

# Built-in algorithms for Branch-and-Bound

Branch-and-Bound algorithm aims to find an optimal solution of a MIP by successive divisions of the search space. 

In the classic Branch-and-Bound algorithm, one starts by optimizing the linear relaxation of the MIP, raising a dual bound on the value of the optimal solution of the MIP. This step takes place in the Root Node of the Branch-and-Bound tree. One then chooses a fractional variable $$x_i$$ of the relaxation i.e. a variable with a fractional part in the solution while it is supposed to be an integer in the MIP's constraints. Two children nodes are then created, both corresponding to divisions of the search space. To be more specific, in one branch we add the constraint $$x_i \leq \lfloor x_i \rfloor$$, and in the other branch the constraint $$x_i \geq \lceil x_i \rceil$$. The intuition behind such a bounding is to hopefully drive $$x_i$$ towards integrality. By iterating the procedure on the children nodes, the search space becomes increasingly restricted, until the problem becomes infeasible, or a feasible solution of the MIP is obtained. In this context, the dual bound provided by the linear relaxation optimization at each node plays the role of indicator and can be used in order to prune the search tree. Indeed, if one finds a feasible (but suboptimal) solution $$s$$ of the MIP during the exploration, then one can prune all branches where the local dual bound is worse than $$s$$, because no better feasible solution can be found in these subspaces. The process is illustrated by the figure below:

TODO: insert the two pictures of my oral presentation to show the division of the search space during branch-and-bound (polyhedron vs tree)

In this 2-dimensional example, a feasible solution of the MIP has been found in subspace/node B (circled in blue). The dual bounds of all subspaces have been computed (indicated by blue stars on the polyhedron). We notice that dual bounds of subspaces A and D are worse than this current feasible solution (w.r.t. the objective function whose direction is indicated by the gray arrow). Thus, we can avoir exploring subspaces A and D, and nodes A and D can be pruned. 

In order to speed up the algorithm, it could be helpful to apply some decompositions s.t. Dantzig-Wolfe or Benders ahead of the Branch-and-Bound tree. However, these decompositions lead to the creation of an exponential number of variables in the formulation. To avoid spending too much time optimizing each node, the alternative is to solve the linear relaxation at each node using Cut, and/or Column Generation (for Dantzig-Wolfe decomposed problems only). This approach leads to algorithms known as Branch-and-Cut (Branch-and-Bound + Cut Generation), Branch-and-Price (Branch-and-Bound + Column Generation) and Branch-and-Cut-and-Price (Branch-and-Bound + Cut and Column Generation).

The main loop used for the implementation of such algorithms is implemented by ```Algorithm.TreeSearchAlgorithm```. It is highly customizable so that the user can specify its own strategy to optimize each node (conquer) and to explore the tree:

```@docs
Algorithm.TreeSearchAlgorithm
```

In the following sections, we present the global setup of ```Algorithm.TreeSearchAlgorithm```. First, we describe the construction and the exploration of the search tree. Then, we "zoom" on the tree to describe the setup of Cut and Column Generation at each node.


## Manage the branching phase

When generating branches in the Branch-and-Bound process, two questions arise:
- which fractional variable to branch on ?
- which branch to explore first ? 
The two next sections describe the parameters that can be used to setup the branching phase. 

### Select the variable to branch on

```@docs
Branching.AbstractSelectionCriterion
Algorithm.FirstFoundCriterion
Algorithm.MostFractionalCriterion
```

```@docs
Algorithm.SingleVarBranchingRule
```


### Division of the search space

```@docs
Algorithm.NoBranching
Algorithm.ClassicBranching
Algorithm.StrongBranching
```

## Optimize each node by Column and/or Cut Generation

TODO: add precisions to indicate to the user what is used with DW or Benders respectively

```@docs
Algorithm.ColCutGenConquer
```

```@docs
Algorithm.ColumnGeneration
```

## Basic algorithms

### Optimize a linear program

```@docs
Algorithm.SolveLpForm
```


### Optimize an mixed-integer program / solve a combinatorial problem

```@docs
Algorithm.SolveIpForm
Algorithm.MoiOptimize
Algorithm.UserOptimize
Algorithm.CustomOptimize
```
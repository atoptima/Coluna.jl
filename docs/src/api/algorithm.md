# Algorithm API

An algorithm is a procedure that given a model and and input performs some operations and 
returns an output.

```@docs
run!
```

Parameters of an algorithm may contain its child algorithms which used by it. Therefore, 
the algoirthm tree is formed, in which the root is the algorithm called to solver the model 
(root algorithm should be an optimization algorithm, see below). 

Algorithms are divided into two types : "manager algorithms" and "worker algorithms". 
Worker algorithms just continue the calculation. They do not store and restore units 
as they suppose it is done by their master algorithms. Manager algorithms may divide 
the calculation flow into parts. Therefore, they store and restore units to make sure 
that their child worker algorithms have units prepared. 
A worker algorithm cannot have child manager algorithms. 

Examples of manager algorithms : TreeSearchAlgorithm (which covers both BCP algorithm and 
diving algorithm), conquer algorithms, strong branching, branching rule algorithms 
(which create child nodes). Examples of worker algorithms : column generation, SolveIpForm, 
SolveLpForm, cut separation, pricing algorithms, etc.
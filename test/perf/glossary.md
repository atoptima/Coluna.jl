## Generate Julia code profile using ```PProf.jl```

https://github.com/JuliaPerf/PProf.jl



## Interpret code profiling

useful links:
https://docs.julialang.org/en/v1/devdocs/init/
https://docs.julialang.org/en/v1/devdocs/ast/
https://docs.julialang.org/en/v1/devdocs/functions/


some Julia build-in methods:

- ```jl_repl_entrypoint```: loads the contents of ```argv[ ]```
- ```eval``` calls ```jl_toplevel_eval_in``` which calls ```jl_toplevel_eval_flex```
- ```jl_toplevel_eval_flex``` implements a simple heuristic to decide whether to compile a given code thunk or run it by interpreter.
- ```jl_interpret_toplevel_thunk``` is called by ```jl_toplevel_eval_flex``` when deciding to run the code by interpreter. It then calls ```eval_body```
- ```jl_apply_generic```: perfoms the dispatch process.
- ```kwcall```: "keyword argument sorter" or "keyword sorter", manages the keyword argurments when calling a method, e.g. consider method (see ```/devdocs/functions.md``` from Julia repo to get an example and more details)


how to read pprof output ?

- graph: (taken from https://github.com/google/pprof/issues/493)
    * Dotted/dashed lines indicated that that intervening nodes have been removed. Nodes are removed to keep graphs small enough for visualization.
    * The wider an arrow the more of the metric being measured is used along that path.
    *  Nodes and edges are colored according to their total value (total being the amount of a metric used by a node and all of its children); large positive values are red; large negative values are green.

- flat/cum:
    
    * flat: the value of the location itself.
    * cum: the value of the location plus all its descendants.

# # [Column generation with the Generalized Assignment Problem](@id tuto_gen_assignement)

# This quick start guide introduces the main features of Coluna through the example of the
# Generalized Assignment Problem.

# ## Classic model solved with MIP solver

# Consider a set of machines `M` and a set of jobs `J`.
# A machine $m$ has a resource capacity $Q_m$ .
# A job $j$ assigned to a machine $m$ has a cost $c_{mj}$ and consumes $w_{mj}$ resource units
# of the machine $m$.
# The goal is to minimize the sum of job costs while assigning each job to a machine and not
# exceeding the capacity of each machine.

# Let $x_{mj}$ equal to one if job $j$ is assigned to machine $m$; $0$ otherwise.
# The problem has the original formulation:

# ```math
# \begin{alignedat}{4}
# \text{[GAP]} \equiv \min \mathrlap{\sum_{m \in M}\sum_{j \in J} c_{mj} x_{mj}}  \\
# \text{s.t.} && \sum_{m \in M} x_{mj} &= 1  \quad& j \in J \\
# && \sum_{j \in J} w_{mj} x_{mj} &\leq Q_m  \quad  \quad& m \in M  \\
# && x_{mj}  &\in \{0,1\}  &m \in M,\; j \in J
# \end{alignedat}
# ```

# Let us consider the following instance. 

M = 1:3;
J = 1:15;
c = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5; 19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7; 13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2];
w = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91;91 81 66 63 59 81 87 90 65 55 57 68 92 91 86; 62 79 73 60 75 66 68 99 69 60 56 100 67 68 54];
Q = [1020 1460 1530];

# We write the model with [JuMP](https://github.com/jump-dev/JuMP.jl), a domain-specific modeling
# language for mathematical optimization embedded in Julia. We optimize with GLPK.
# If you are not familiar with the JuMP package, you may want to check its 
# [documentation](https://jump.dev/JuMP.jl/stable/).

using JuMP, GLPK;

# A JuMP model for the original formulation is:

model = Model(GLPK.Optimizer)
@variable(model, x[m in M, j in J], Bin);
@constraint(model, cov[j in J], sum(x[m, j] for m in M) >= 1);
@constraint(model, knp[m in M], sum(w[m, j] * x[m, j] for j in J) <= Q[m]);
@objective(model, Min, sum(c[m, j] * x[m, j] for m in M, j in J));

# We optimize the instance and retrieve the objective value.

optimize!(model);
objective_value(model)

# ## Try column generation easily with Coluna and BlockDecomposition

# This model has a block structure: each knapsack constraint defines
# an independent block and the set-partitioning constraints couple these independent
# blocks. By applying the Dantzig-Wolfe reformulation, each knapsack constraint forms
# a tractable subproblem and the set-partitioning constraints are handled in a master problem.

# To write the model, you need JuMP and BlockDecomposition. 
# The latter is an extension built on top of JuMP to model Dantzig-Wolfe and Benders decompositions.
# You will find more documentation about BlockDecomposition in the 
# [Decomposition & reformulation](@ref)
# To optimize the problem, you need Coluna and a Julia package that provides a MIP solver such as GLPK.

# Since we have already loaded JuMP and GLPK, we just need:

using BlockDecomposition, Coluna;

# Next, you instantiate the solver and define the algorithm that you use to optimize the problem.
# In this case, the algorithm is a classic branch-and-price provided by Coluna.

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default branch-cut-and-price
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

# In BlockDecomposition, an axis is an index set of subproblems.
# Let `M_axis` be the index set of machines; it defines an axis along which we can implement the
# desired decomposition.

@axis(M_axis, M);

# In this example, the axis `M_axis` defines one knapsack subproblem for each machine.
# For instance, the first machine index is 1 and is of type `BlockDecomposition.AxisId`: 

M_axis[1]

typeof(M_axis[1])

# Jobs are not involved in the decomposition, set `J` of jobs thus stays as a classic
# range.

# The model takes the form:

model = BlockModel(coluna); 

# You can write `BlockModel(coluna; direct_model = true)` to pass names of variables 
# and constraints to Coluna.

@variable(model, x[m in M_axis, j in J], Bin);
@constraint(model, cov[j in J], sum(x[m, j] for m in M_axis) >= 1);
@constraint(model, knp[m in M_axis], sum(w[m, j] * x[m, j] for j in J) <= Q[m]);
@objective(model, Min, sum(c[m, j] * x[m, j] for m in M_axis, j in J));

# This is the same model as above except that we use a `BlockModel` instead of a `Model` and 
# `M_axis` as the set of machines instead of `M`.
# Therefore, BlockDecomposition will know which variables and constraints are involved in subproblems
# because one of their indices is a `BlockDecomposition.AxisId`.

# You then apply a Dantzig-Wolfe decomposition along `M_axis`:

@dantzig_wolfe_decomposition(model, decomposition, M_axis)

# where `decomposition` is a variable that contains information about the decomposition.

decomposition

# Once the decomposition is defined, you can retrieve the master and the subproblems to give
# additional information to the solver.

master = getmaster(decomposition)
subproblems = getsubproblems(decomposition)

# The multiplicity of a subproblem is the number of times that the same independent block
# shaped by the subproblem appears in the model. This multiplicity also specifies the number of
# solutions to the subproblem that can appear in the solution to the original problem.

# In this GAP instance, the upper multiplicity is $1$ because every subproblem is different,
# *i.e.*, every machine is different and used at most once.

# The lower multiplicity is $0$ because a machine may stay unused.
# The multiplicity specifications take the form:

specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)
getsubproblems(decomposition)

# The model is now fully defined. To solve it, you need to call:

optimize!(model)

# You can find more information about the output of the column generation algorithm [ColumnGeneration](@ref).

# Finally, you can retrieve the solution to the original formulation with JuMP methods.
# For example, if we want to know if job 3 is assigned to machine 1:

value(x[1,3])


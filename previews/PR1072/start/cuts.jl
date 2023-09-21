# # [Valid inequalities](@id tuto_cut_callback)

# Now let us consider a variant of the Generalized Assignment Problem in which we have to
# pay `f[m]` to use machine `m`.

# Consider the following instance:

J = 1:10
M = 1:5
c = [10.13 15.6 15.54 13.41 17.08;19.58 16.83 10.75 15.8 14.89;14.23 17.36 16.05 14.49 18.96;16.47 16.38 18.14 15.46 11.64;17.87 18.25 13.12 19.16 16.33;11.09 16.76 15.5 12.08 13.06;15.19 13.86 16.08 19.47 15.79;10.79 18.96 16.11 19.78 15.55;12.03 19.03 16.01 14.46 12.77;14.48 11.75 16.97 19.95 18.32];
w = [5, 4, 5, 6, 8, 9, 5, 8, 10, 7];
Q = [25,  24,  31,  28,  24];
f = [105, 103, 109, 112, 100];

# We define the dependencies:

using JuMP, BlockDecomposition, Coluna, GLPK;

# We parametrize the solver. 
# We solve only the root node of the branch-and-bound tree and we use a column and cut 
# generation algorithm to conquer (optimize) this node.

coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm(
            conqueralg = Coluna.Algorithm.ColCutGenConquer(
                max_nb_cut_rounds = 20
            ),
            branchingtreefile = "tree2.dot", 
            maxnumnodes = 1
        )
    ),
    "default_optimizer" => GLPK.Optimizer
);

# ## Column generation

# We write the model:

model = BlockModel(coluna; direct_model = true);
@axis(M_axis, M)
@variable(model, x[j in J, m in M_axis], Bin);
@variable(model, y[m in M_axis], Bin);
@constraint(model, setpartitioning[j in J], sum(x[j,m] for m in M_axis) == 1);
@constraint(model, knp[m in M_axis], sum(w[j]*x[j,m] for j in J) <= Q[m] * y[m]);
@objective(model, Min, sum(c[j,m] * x[j,m] for m in M_axis, j in J) + sum(f[m] * y[m] for m in M_axis));

@dantzig_wolfe_decomposition(model, dec, M_axis);
sp = getsubproblems(dec);
specify!.(sp, lower_multiplicity = 0);

# We optimize:

optimize!(model)

# The final dual bound is:

db1 = objective_bound(model)

# ## Strengthen with valid inequalities

# Let `H` be the set of configurations of open machines (`h[m] = 1` if machine m open; `0` otherwise)
# such that all jobs can be assigned : `sum(h'Q) >= sum(w)` 
# i.e. the total capacity of the open machines must exceed the total weight of the jobs.

H = Vector{Int}[]
for h in digits.(1:(2^length(M) - 1), base=2, pad=length(M))
    if sum(h'Q) >= sum(w)
        push!(H, h)
    end
end
H

# Let `ȳ` be the solution to the linear relaxation of the problem.
# Let us try to express `ȳ` as a linear expression of the configurations.
# If `ȳ ∈ conv H`, we can derive a cut because the optimal integer solution to the problem uses one of the configurations of H.

# We need MathOptInterface to define the cut callback: 

using MathOptInterface

# The separation algorithm looks for the non-negative coefficients `χ[k]`, `k = 1:length(H)`,  :
# `max sum(χ[k] for k in 1:length(H))` such that `sum(χ[k]* h for (k,h) in enumerate(H)) <= ̄ȳ`.
# If the objective value is less than 1, we must add a cut.

# Since the separation algorithm is a linear program, strong duality applies.
# So we separate these cuts with the dual.

fc_sep_m = Model(GLPK.Optimizer)
@variable(fc_sep_m, ψ[m in M] >= 0) # one variable for each constraint
@constraint(fc_sep_m, config_dual[h in H], ψ'h >= 1) # one constraint for each χ[k]
MathOptInterface.set(fc_sep_m, MathOptInterface.Silent(), true)

# The objective is `min ȳ'ψ` = `sum(χ[k] for k in 1:length(H))`.
# Let `ψ*` be an optimal solution to the dual. If `ȳ'ψ* < 1`, then `ψ*'y >= 1` is a valid inequality.

function fenchel_cuts_separation(cbdata)
    println("Fenchel cuts separation callback...")
    ȳ = [callback_value(cbdata, y[m]) for m in M_axis]
    @objective(fc_sep_m, Min, ȳ'ψ) # update objective
    optimize!(fc_sep_m)
    if objective_value(fc_sep_m) < 1
        con = @build_constraint(value.(ψ)'y >= 1) # valid inequality.
        MathOptInterface.submit(model, MathOptInterface.UserCut(cbdata), con)
    end
end

MathOptInterface.set(model, MathOptInterface.UserCutCallback(), fenchel_cuts_separation);

# We optimize:

optimize!(model)

# Valid inequalities significantly improve the previous dual bound:

db2 = objective_bound(model)


db2



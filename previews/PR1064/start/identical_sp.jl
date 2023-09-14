# # [Identical subproblems](@id tuto_identical_sp)

# Let us see an example of resolution using the advantage of identical subproblems with Dantzig-Wolfe and a variant of the Generalized Assignment Problem.

# Consider a set of machine type `T = 1:nb_machine_types` and a set of jobs `J = 1:nb_jobs`.
# A machine type `t` has a resource capacity `Q[t]` and the factory contains `U[t]` machines of type `t`.
# A job `j` assigned to a machine of type `t` has a cost `c[t,j]` and consumes `w[t,j]` resource units of the machine of type `t`.

# Consider the following instance :

nb_machine_types = 2;
nb_jobs = 8;
J = 1:nb_jobs;
Q = [10, 15];
U = [3, 2];  # 3 machines of type 1 & 2 machines of type 2
c = [10 11 13 11 12 14 15 8; 20 21 23 21 22 24 25 18];
w = [4 4 5 4 4 3 4 5; 5 5 6 5 5 4 5 6];


#Here is the JuMP model to optimize this instance with a classic solver : 

using JuMP, GLPK;

T1 = [1, 2, 3]; # U[1] machines
T2 = [4, 5]; # U[2] machines
M = union(T1, T2);
m2t = [1, 1, 1, 2, 2]; # machine id -> type id

model = Model(GLPK.Optimizer);
@variable(model, x[M, J], Bin); # 1 if job j assigned to machine m
@constraint(model, cov[j in J], sum(x[m,j] for m in M) == 1);
@constraint(model, knp[m in M], sum(w[m2t[m],j] * x[m,j] for j in J) <= Q[m2t[m]]);
@objective(model, Min, sum(c[m2t[m],j] * x[m,j] for m in M, j in J));

optimize!(model);
objective_value(model)


# You can decompose over the machines by defining an axis on `M`.
# However, if you want to take advantage of the identical subproblems, you must 
# define the formulation as follows : 

using BlockDecomposition, Coluna, JuMP, GLPK;
const BD = BlockDecomposition

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm() # default BCP
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

@axis(T, 1:nb_machine_types);

model = BlockModel(coluna);
@variable(model, x[T, J], Bin); # 1 if job j assigned to machine m
@constraint(model, cov[j in J], sum(x[t,j] for t in T) == 1);
@constraint(model, knp[t in T], sum(w[t] * x[t,j] for j in J) <= Q[t]);
@objective(model, Min, sum(c[t,j] * x[t,j] for t in T, j in J));



# We assign jobs to a type of machine and we define one knapsack constraint for
# each type. This formulation cannot be solved as it stands with a commercial solver.
# 
# Then, we decompose and specify the multiplicity of each knapsack subproblem : 


@dantzig_wolfe_decomposition(model, dec_on_types, T);
sps = getsubproblems(dec_on_types)
for t in T
    specify!(sps[t], lower_multiplicity = 0, upper_multiplicity = U[t]);
end
getsubproblems(dec_on_types)

# We see that subproblem for machine type 1 has an upper multiplicity equals to 3,
# and the second subproblem for machine type 2 has an upper multiplicity equals to 2.
# It means that we can use at most 3 machines of type 1 and at most 2 machines of type 2.

# We can then optimize

optimize!(model);


# and retrieve the disaggregated solution

for t in T
    assignment_patterns = BD.getsolutions(model, t);
    for pattern in assignment_patterns
        nb_times_pattern_used = BD.value(pattern);
        jobs_in_pattern = [];
        for j in J
            if BD.value(pattern, x[t, j]) ≈ 1
                push!(jobs_in_pattern, j);
            end
        end
        println("Pattern of machine type $t used $nb_times_pattern_used times : $jobs_in_pattern");
    end
end

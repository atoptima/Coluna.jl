# # Advanced tutorial - Location Routing

# We demonstrate the main features of Coluna on a variant of the Location Routing problem.
# In the Location Routing Problem, we are given a set of facilities and a set of customers.
# Each customers must be delivered by a route starting from one facility. Each facility has 
# a setup cost, while the cost of a route is the distance traveled.

# A route is defined as a vector of locations that satisfies the following rules:

# - any route must start from a open facility location
# - every route has a maximum number of visited locations (which is fixed to a constant `nb_positions`)
# - the routes are said to be open, i.e. they finish at last visited customer.

# Our objective is to minimize the fixed costs for opening facilities and the distance traveled
# by the routes while ensuring that each customer is by one route.


# In this tutorial, we will show you how to optimize this problem using:
# - a direct approach with JuMP and a MILP solver (without Coluna)
# - a classic branch-and-price provided by Coluna and a pricing callback that calls a custom code to optimize pricing subproblems
# - a branch-cut-and-price algorithm based on valid inequalities on the original variables (so called "robust" cuts) 
# - a branch-cut-and-price algorithm based on valid inequalities on the varibles of column geenration  reformulation (so called "non-robust" cuts) 
# - a multi-stage column generation algorithm using two different pricing solvers
# - a Benders decomposition approach (based on LP)

# We work on a small instance with 2 facilities and 7 customers. 
# The maximum length of a route is fixed to 4. 
# We also provide a larger instance in the last section of the tutorial.

nb_positions = 4
facilities_fixed_costs = [120, 150]
facilities = [1, 2]
customers = [3, 4, 5, 6, 7, 8, 9]
arc_costs =
    [
        0.0 25.3 25.4 25.4 35.4 37.4 31.9 24.6 34.2;
        25.3 0.0 21.2 16.2 27.1 26.8 17.8 16.7 23.2;
        25.4 21.2 0.0 14.2 23.4 23.8 18.3 17.0 21.6;
        25.4 16.2 14.2 0.0 28.6 28.8 22.6 15.6 29.5;
        35.4 27.1 23.4 28.6 0.0 42.1 30.4 24.9 39.1;
        37.4 26.8 23.8 28.8 42.1 0.0 32.4 29.5 38.2;
        31.9 17.8 18.3 22.6 30.4 32.4 0.0 22.5 30.7;
        24.6 16.7 17.0 15.6 24.9 29.5 22.5 0.0 21.4;
        34.2 23.2 21.6 29.5 39.1 38.2 30.7 21.4 0.0;
    ]
locations = vcat(facilities, customers)
nb_customers = length(customers)
nb_facilities = length(facilities)
positions = 1:nb_positions;

# In this tutorial, we will use the following packages:

using JuMP, HiGHS, GLPK, BlockDecomposition, Coluna;

# We want to set an upper bound `nb_routes_per_facility` on the number of routes starting from a facility. 
# This limit is computed as follows:

## We compute the minimum number of routes needed to visit all customers:
nb_routes = Int(ceil(nb_customers / nb_positions))
## We define the upper bound `nb_routes_per_facility`: 
nb_routes_per_facility = min(Int(ceil(nb_routes / nb_facilities)) * 2, nb_routes)
routes_per_facility = 1:nb_routes_per_facility;

# ## Direct model

# First, we solve the problem by a direct approach, using the HiGHS solver. 
# We start by creating a JuMP model:

model = JuMP.Model(HiGHS.Optimizer);

# We declare 3 types of binary variables: 

## y[j] equals 1 if facility j is open; 0 otherwise.
@variable(model, y[j in facilities], Bin)

## z[u,v] equals 1 if a vehicle travels from u to v; 0 otherwise
@variable(model, z[u in locations, v in locations], Bin)

## x[i,j,k,p] equals 1 if customer i is delivered from facility j at position p of route k; 0 otherwise
@variable(model, x[i in customers, j in facilities, k in routes_per_facility, p in positions], Bin);


# We define the constraints:

## each customer visited once
@constraint(model, cov[i in customers],
    sum(x[i, j, k, p] for j in facilities, k in routes_per_facility, p in positions) == 1)

## each facility is open if there is a route starting from it
@constraint(model, setup[j in facilities, k in routes_per_facility],
    sum(x[i, j, k, 1] for i in customers) <= y[j])

## flow conservation
@constraint(model, flow_conservation[j in facilities, k in routes_per_facility, p in positions; p > 1],
    sum(x[i, j, k, p] for i in customers) <= sum(x[i, j, k, p-1] for i in customers))

## there is an arc between two customers whose demand is satisfied by the same route at consecutive positions
@constraint(model, route_arc[i in customers, l in customers, j in facilities, k in routes_per_facility, p in positions; p > 1 && i != l],
    z[i, l] >= x[l, j, k, p] + x[i, j, k, p-1] - 1)

## there is an arc between the facility `j` and the first customer visited by the route `k` from facility `j`
@constraint(model, start_arc[i in customers, j in facilities, k in routes_per_facility],
    z[j, i] >= x[i, j, k, 1]);

# We set the objective function:

@objective(model, Min,
    sum(arc_costs[u, v] * z[u, v] for u in locations, v in locations)
    +
    sum(facilities_fixed_costs[j] * y[j] for j in facilities));

# and we optimize the model:

optimize!(model)
objective_value(model)

# We find an optimal solution involving two routes starting from facility 1:
# - `1` -> `8` -> `9` -> `3` -> `6`
# - `1` -> `4` -> `5` -> `7`

# ## Dantzig-Wolfe decomposition and Branch-and-Price

# One can solve the above problem by exploiting its structure with a Dantzig-Wolfe decomposition approach.
# The subproblem induced by such decompostion amount to generating routes starting from each facility. 
# The most naive decomposition is to consider a subproblem associated with each vehicle, generating the vehicle route.
# However, for a given facility, the vehicles that are identical will give rise to the same subproblem and route solutions.
# So instead of the naive decomposition, with several identical subproblems for each facility, we define below a single subproblem per facility.
# For each subproblem, we define its multipliclity, i.e. we bound the number of solutions of this subproblem that can be used in a master solution.

# The following method creates the model according to the decomposition described: 
function create_model(optimizer, pricing_algorithms)
    ## We declare an axis over the facilities.
    ## We must use `facilities_axis` instead of `facilities` in the declaration of the 
    ## variables and constraints that belong to pricing subproblems.
    @axis(facilities_axis, collect(facilities))

    ## We declare a `BlockModel` instead of `Model`.
    model = BlockModel(optimizer)

    ## `y[j]` is a master variable equal to 1 if the facility j is open; 0 otherwise
    @variable(model, y[j in facilities], Bin)

    ## `x[i,j]` is a subproblem variable equal to 1 if customer i is delivered from facility j; 0 otherwise.
    @variable(model, x[i in customers, j in facilities_axis], Bin)
    ## `z[u,v]` is assimilated to a subproblem variable equal to 1 if a vehicle travels from u to v; 0 otherwise.
    ## we don't use the `facilities_axis` axis here because the `z` variables are defined as
    ## representatives of the subproblem variables later in the model.
    @variable(model, z[u in locations, v in locations], Bin)

    ## `cov` constraints are master constraints ensuring that each customer is visited once.
    @constraint(model, cov[i in customers],
        sum(x[i, j] for j in facilities) >= 1)

    ## `open_facilities` are master constraints ensuring that the depot is open if one vehicle.
    ## leaves it.
    @constraint(model, open_facility[j in facilities],
        sum(z[j, i] for i in customers) <= y[j] * nb_routes_per_facility)

    ## We don't need to describe the subproblem constraints because we use a pricing callback.

    ## We set the objective function:
    @objective(model, Min,
        sum(arc_costs[u, v] * z[u, v] for u in locations, v in locations) +
        sum(facilities_fixed_costs[j] * y[j] for j in facilities)
    )

    ## We perform decomposition over the facilities.
    @dantzig_wolfe_decomposition(model, dec, facilities_axis)

    ## Subproblems generated routes starting from each facility.
    ## The number of routes from each facilities is at most `nb_routes_per_facility`.
    subproblems = BlockDecomposition.getsubproblems(dec)
    specify!.(subproblems, lower_multiplicity=0, upper_multiplicity=nb_routes_per_facility, solver=pricing_algorithms)

    ## We define `z` are a subproblem variable common to all subproblems.
    subproblemrepresentative.(z, Ref(subproblems))

    return model, x, y, z, cov
end;

# Note that contrary to the direct model, we don't have to add constraints to ensure the
# consistency of the routes because we solve our subproblems using a pricing callback.
# The pricing callback will therefore have the responsibility to create consistent routes.

# We setup Coluna:

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver=Coluna.Algorithm.TreeSearchAlgorithm( ## default branch-and-bound of Coluna
            maxnumnodes=100,
            conqueralg=Coluna.ColCutGenConquer() ## default column and cut generation of Coluna
        ) ## default branch-cut-and-price
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

# ### Pricing callback

# Each subproblem could be solved by a MIP, provided the right sub-problem constraints are added in the model.
# Here, we do not use this default pricing subproblem solver, but instead we define a pricing callback.
# This pricing callback solver takes here the form of an enumeration all possible routes for each facility.
# However the enumeration of feasible routes is time-consuming.
# Therefore, this operation is performed in a preprocessing phase, before starting the branch-cut-and-price algorithm.
# The pricing callback for a given facility then simply have to update the cost of each route and select 
# the route with the best reduced cost.

# We first define a structure to store the routes:
mutable struct Route
    length::Int # record the number of visited customers 
    path::Vector{Int} # record the sequence of visited customers 
end;

# A method that computes the cost of a route:

function route_original_cost(arc_costs, route::Route)
    route_cost = 0.0
    path = route.path
    path_length = route.length
    for i in 1:(path_length-1)
        route_cost += arc_costs[path[i], path[i+1]]
    end
    return route_cost
end;

# The reduced cost of the route only depends on the facility used, the selected set of customers,
# and the total arc costs. There is no master constraints that may have an effect of the customer visit order.
# Hence, for a given subset of customers, one needs only to consider the optimal visit sequence 
# that can be computed once and for all in the preprocessing phase, 
# as it is done by enumeration in the following best_visit_sequence function.
# We therefore keep only this dominant route for each subset of customers and facilities.

function best_visit_sequence(arc_costs, cust_subset, facility_id)
    ## generate all the possible visit orders
    set_size = size(cust_subset)[1]
    all_paths = collect(multiset_permutations(cust_subset, set_size))
    all_routes = Vector{Route}()
    for path in all_paths
        ## add the first index i.e. the facility id 
        enpath = vcat([facility_id], path)
        ## length of the route = 1 + number of visited customers
        route = Route(set_size + 1, enpath)
        push!(all_routes, route)
    end
    ## compute each route original cost
    routes_costs = map(r ->
            (r, route_original_cost(arc_costs, r)), all_routes)
    ## keep only the best visit sequence
    tmp = argmin([c for (_, c) in routes_costs])
    (best_order, _) = routes_costs[tmp]
    return best_order
end;

# We are now able to compute the best route for all the possible customers subsets,
# given a facility id:

using Combinatorics

function best_route_forall_cust_subsets(arc_costs, customers, facility_id, max_size)
    best_routes = Vector{Route}()
    all_subsets = Vector{Vector{Int}}()
    for subset_size in 1:max_size
        subsets = collect(combinations(customers, subset_size))
        for s in subsets
            push!(all_subsets, s)
        end
    end
    for s in all_subsets
        route_s = best_visit_sequence(arc_costs, s, facility_id)
        push!(best_routes, route_s)
    end
    return best_routes
end;

# We store all the information given by this pre-processing phase in a dictionary.
# To each facility id, we match a vector of routes that are the best visiting sequences
# for each possible subset of customers.

routes_per_facility = Dict(
    j => best_route_forall_cust_subsets(arc_costs, customers, j, nb_positions) for j in facilities
)

# Our pricing callback must compute the reduced cost of each route, 
# given the reduced cost of the subproblem variables `x` and `z`.
# Note that for `z` variables, the reduced cost is initially equal the original arc_cost,
# as long as there are no master constraints involving `z`;
# but this will change as branching constraints and cuts are added to the master.


# We therefore need methods to compute the contributions to the reduced cost of the `x` and `z` variables:

function x_contribution(route::Route, j::Int, x_red_costs)
    x = 0.0
    visited_customers = route.path[2:route.length]
    for i in visited_customers
        x += x_red_costs["x_$(i)_$(j)"]
    end
    return x
end;

function z_contribution(route::Route, z_red_costs)
    z = 0.0
    for i in 1:(route.length-1)
        current_position = route.path[i]
        next_position = route.path[i+1]
        z += z_red_costs["z_$(current_position)_$(next_position)"]
    end
    return z
end;

# We are now able to write our pricing callback: 

function pricing_callback(cbdata)
    ## Get the id of the facility.
    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))

    ## Retrieve variables reduced costs.
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations)
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )

    ## Keep route with minimum reduced cost.
    red_costs_j = map(r -> (
            r,
            x_contribution(r, j, x_red_costs) + z_contribution(r, z_red_costs) # the reduced cost of a route is the sum of the contribution of the variables
        ), routes_per_facility[j]
    )
    min_index = argmin([x for (_, x) in red_costs_j])
    (best_route, min_reduced_cost) = red_costs_j[min_index]

    ## Retrieve the route's arcs
    best_route_arcs = Vector{Tuple{Int,Int}}()
    for i in 1:(best_route.length-1)
        push!(best_route_arcs, (best_route.path[i], best_route.path[i+1]))
    end
    best_route_customers = best_route.path[2:best_route.length]

    ## Create the solution (send only variables with non-zero values).
    z_vars = [z[u, v] for (u, v) in best_route_arcs]
    x_vars = [x[i, j] for i in best_route_customers]
    sol_vars = vcat(z_vars, x_vars)
    sol_vals = ones(Float64, length(z_vars) + length(x_vars))
    sol_cost = min_reduced_cost

    ## Submit the solution of the subproblem to Coluna.
    MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)

    ## Submit the dual bound to the solution of the subproblem.
    ## This bound is used to compute the contribution of the subproblem to the lagrangian
    ## bound in column generation.
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), sol_cost) ## optimal solution

end;

# Create the model:
model, x, y, z, _ = create_model(coluna, pricing_callback);

# Solve:
JuMP.optimize!(model)


# ### Strengthening the master with linear valid inequalities on the original variables (so called "robust" cuts)

# We introduce of first type of classic valid inequalities that tries to improve the 
# integrality enforcement on the `y` variables. 
# A cut speration callback is presented that implements a simple enumeration process.
#
# ```math
# x_{ij} \leq y_j\; \forall i \in I, \forall j \in J
# ```
# where $I$ is the set of customers and J the set of facilities.

# We declare a structure representing an instance of this inequality:
struct OpenFacilityInequality
    facility_id::Int
    customer_id::Int
end

# To identify violated valid inequalities for a current master LP solution, we proceed by enumeration (i.e. iterating over all pairs of customer and facility).
# Let's write our cut separation callback as follows:

function valid_inequalities_callback(cbdata)
    ## Get variables valuations, store them into dictionaries.
    x_vals = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_value(cbdata, x[i, j]) for i in customers, j in facilities
    )
    y_vals = Dict(
        "y_$(j)" => BlockDecomposition.callback_value(cbdata, y[j]) for j in facilities
    )

    ## Separate the valid inequalities (i.e. retrieve the inequalities that are violated by 
    ## the current solution) by enumeration.
    inequalities = OpenFacilityInequality[]

    for j in facilities
        y_j = y_vals["y_$(j)"]
        for i in customers
            x_i_j = x_vals["x_$(i)_$(j)"]
            if x_i_j > y_j
                push!(inequalities, OpenFacilityInequality(j, i))
            end
        end
    end

    ## Add the valid inequalities to the model. 
    for ineq in inequalities
        constr = JuMP.@build_constraint(x[ineq.customer_id, ineq.facility_id] <= y[ineq.facility_id])
        MOI.submit(model, MOI.UserCut(cbdata), constr)
    end
end;

# We re-declare the model and optimize it with these valid inequalites:
model, x, y, z, _ = create_model(coluna, pricing_callback);
MOI.set(model, MOI.UserCutCallback(), valid_inequalities_callback);
JuMP.optimize!(model)


# ### Strengthening the master with valid inequalities on the column generation variables (so called "non-robust" cuts)

# Here, we implement special types of cuts called "rank-one cuts" (R1C).
# These cuts are non-robust in the sense that they cannot be expressed as a linear expression of only the
# original variables of the model. In particular, they have to be expressed with the master 
# columns variables $λ_k, k \in K$ where $K$ is the set of generated columns.

# "Rank-one cuts" (R1Cs) are obtained by applying the Chvátal-Gomory procedure once, 
# hence their name, in this case on the packing constraints implicitly going along side 
# the covering constraints of the master program to define the set partitionning formulation.
# R1Cs have the following form:

# ```math
# \sum_{k \in K} \lfloor \sum_{i \in C} \alpha_c \tilde{x}^k_{i,j} \lambda_{k} \rfloor \leq \lfloor \sum_{i \in C} \alpha_c \rfloor, \;  C \subseteq I
# ```

# where $C$ is a subset of customers, $\alpha_c$ is a multiplier, $\tilde{x}^k_{ij}$ is the
# value of the variable $x_{ij}$ in the $k$th column generated.

# Since we obtain R1C by applying a procedure on cover constraints, we must be able to
# differentiate them from the other constraints of the model. 
# To do this, we exploit an advantage of Coluna that allows us to attach custom data to the
# constraints and variables of our model, via the add-ons of BlockDecomposition

# First, we create a special custom data with the only information we need to characterize 
# our cover constraints: the customer id that corresponds to this constraint.
struct CoverConstrData <: BlockDecomposition.AbstractCustomData
    customer::Int
end

# We re-create the model:
(model, x, y, z, cov) = create_model(coluna, pricing_callback);

# We declare our custom data to Coluna and we attach one custom data to each cover constraint
BlockDecomposition.customconstrs!(model, CoverConstrData);

for i in customers
    customdata!(cov[i], CoverConstrData(i))
end

# For the sequel, we "restrict" our ambition to separate only R1Cs based on a subset of customers of size 3 ($|C|$ = 3) 
# and on a multipliers vector  $\alpha = (0.5, 0.5, 0.5)$.

# We perform the separation by enumeration (i.e. iterating over all subsets of customers of size 3).

# Therefore our R1Cs will have the following form:

# ```math
# \sum_{k \in K} \tilde{\alpha}(C, k) \lambda_{k} \leq 1\; C \subseteq I, |C| = 3
# ```

# where coefficient $\tilde{\alpha}(C, k)$ equals $1$ if route $k$ visits at least two customers of $C$; $0$ otherwise.

# For instance, if we consider separate a cut over constraints `cov[3]`, `cov[6]` and `cov[8]`,
# then the route `1`->`4`->`6`->`7` has a zero coefficient while the route `1`->`4`->`6`->`3`
# has a coefficient equal to one.

# Now the "challenge" is to implement the computation of the variable coefficients in such a cut. 
# This will be done thanks to further custom data structures attached to the cut constraints and 
# the master variables. 
# These custom data structure allow Coluna to recognize variables that are involved in such cuts
# and call a user-defined method `computecoeff` to get the coefficient of the variable in the cut.
# When adding new constraints or variables to the model, Coluna will call the `computecoeff` method.
# Each time it finds a pair of variable and constraint that carry custom data, it is an indicator that we probably are in a non-robust case.
# This method shall compute and return the coefficient of the variable in the constraint.
# Thanks to this mecnisme, Coluna basically computes the coefficient of a column as the addition of the robust
# contribution (i.e. linear expression of subproblem variable valuations) and the non-robust
# contribution retuned by the `computecoeff` method.


# Let us illustrate this for the restricted R1C case.
# First, we attach a custom data structure to master columns `λ_k` associated to a given route `k`.
# They record the set of customers that are visited by the given route `k`.

# Thus, to each `λ_k`, we associate a `R1cVarData` structure that carries the locations it visits.  
struct R1cVarData <: BlockDecomposition.AbstractCustomData
    visited_locations::Vector{Int}
end

# Then, we attach a ``R1cCutData` custom data structure to the R1C.
# It indicates which customer cover constraints are taken into account in defining the cut. 
struct R1cCutData <: BlockDecomposition.AbstractCustomData
    cov_constrs::Vector{Int}
end

# We declare our custom data to Coluna via BlockDecomposition add-ons: 
BlockDecomposition.customvars!(model, R1cVarData)
BlockDecomposition.customconstrs!(model, [CoverConstrData, R1cCutData]);

# We can see from the R1C formula that it is not possible to compute the coefficient of the 
# columns as a linear expression of the subproblem variables. 
# But we can instead define a function that computes the `\alpha` coefficient directly.
# This is here that custom data structures come into play.

# So we define this first method that Coluna calls to get the coefficients of the columns `λ_k`
# in a R1C constraint:
function Coluna.MathProg.computecoeff(
    ::Coluna.MathProg.Variable, var_custom_data::R1cVarData,
    ::Coluna.MathProg.Constraint, constr_custom_data::R1cCutData
)
    return floor(1 / 2 * length(var_custom_data.visited_locations ∩ constr_custom_data.cov_constrs))
end

# We also need to define a second method for the case of the cover constraints.
# Indeed, we use a custom data to know the customer attached to each cover constraint
# There is no contribution of the non-robust part of the coefficient of the `λ_k`, so
# the method returns 0.
function Coluna.MathProg.computecoeff(
    ::Coluna.MathProg.Variable, ::R1cVarData,
    ::Coluna.MathProg.Constraint, ::CoverConstrData)
    return 0
end

# We are now able to write fully our rank-one cut callback: 
function r1c_callback(cbdata)
    original_sol = cbdata.orig_sol
    master = Coluna.MathProg.getmodel(original_sol)
    ## retrieve the cover constraints 
    cov_constrs = Int[]
    for constr in values(Coluna.MathProg.getconstrs(master))
        constr_custom_data = Coluna.MathProg.getcustomdata(master, constr)
        if typeof(constr_custom_data) <: CoverConstrData
            push!(cov_constrs, constr_custom_data.customer)
        end
    end

    ## retrieve the master columns λ
    master = cbdata.form
    lambdas = Tuple{Float64,Coluna.MathProg.Variable}[]
    for (var_id, val) in original_sol
        if Coluna.MathProg.getduty(var_id) <= Coluna.MathProg.MasterCol
            push!(lambdas, (val, Coluna.MathProg.getvar(master, var_id)))
        end
    end

    ## separate the valid R1Cs (i.e. those violated by the current solution)
    ## for a fixed subset of cover constraints of size 3, iterate on the master columns 
    ## and check if lhs > 1 :
    for cov_constr_subset in collect(combinations(cov_constrs, 3))
        lhs = 0
        for lambda in lambdas
            (val, var) = lambda
            var_custom_data = Coluna.MathProg.getcustomdata(master, var)
            if !isnothing(var_custom_data)
                coeff = floor(1 / 2 * length(var_custom_data.visited_locations ∩ cov_constr_subset))
                lhs += coeff * val
            end
        end
        if lhs > 1
            ## Create the constraint and add it to the model.
            MOI.submit(model,
                MOI.UserCut(cbdata),
                JuMP.ScalarConstraint(JuMP.AffExpr(0.0), MOI.LessThan(1.0)),
                R1cCutData(cov_constr_subset)
            )
        end
    end
end;

# You can find disturbing the way we add the non-robust valid inequalities because we 
# literally add the constraint `0 <= 1` to the model.
# This is because you don't have directly access to the columns from the separation callback. 
# But you now understand that Coluna will get the coefficient of the columns in the constraints via 
# the above `compute_coeff` method. 
# Basically, you can only express the robust part of the inequality in the separation callback.
# The non-robust part is provided by the `compute_coeff` method.

# The last thing we need to do to complete the implementation of R1Cs is to update our pricing callback. 
# Unlike valid inequalities, R1Cs are not expressed directly with the subproblem variables. 
# Thus, their contribution to the reduced cost of a column is not captured by the reduced cost
# of subproblem variables.
# We must therefore take this contribution into account "manually". 

# The contribution of R1Cs to the reduced cost of a route is managed by the following method:
function r1c_contrib(route::Route, custduals)
    cost = 0
    if !isempty(custduals)
        for (r1c_cov_constrs, dual) in custduals
            coeff = floor(1 / 2 * length(route.path ∩ r1c_cov_constrs))
            cost += coeff * dual
        end
    end
    return cost
end;

# We re-write our pricing callback to: 
# - retrieve the dual cost of the R1Cs
# - take into account the contribution of the R1C in the reduced cost of the route
# - attach custom data to the route to know which customers are visited by the route and compute its coefficient in the R1Cs
function pricing_callback(cbdata)
    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
    )
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )

    ## FIRST CHANGE HERE:
    ## Get the dual values of the custom cuts to compute contributions of
    ## non-robust cuts to the cost of the solution:
    master = cbdata.form.parent_formulation
    custduals = Tuple{Vector{Int},Float64}[]
    for (_, constr) in Coluna.MathProg.getconstrs(master)
        constr_custom_data = Coluna.MathProg.getcustomdata(master, constr)
        if typeof(constr_custom_data) == R1cCutData
            push!(custduals, (
                constr_custom_data.cov_constrs,
                Coluna.MathProg.getcurincval(master, constr)
            ))
        end
    end
    ## END OF FIRST CHANGE

    ## SECOND CHANGE HERE:
    ## Keep route with minimum reduced cost: contribution of the subproblem variables and 
    ## the R1C.
    red_costs_j = map(r -> (
            r,
            x_contribution(r, j, x_red_costs) + z_contribution(r, z_red_costs) - r1c_contrib(r, custduals)
        ), routes_per_facility[j]
    )
    ## END OF SECOND CHANGE
    min_index = argmin([x for (_, x) in red_costs_j])
    best_route, min_reduced_cost = red_costs_j[min_index]

    best_route_arcs = Tuple{Int,Int}[]
    for i in 1:(best_route.length-1)
        push!(best_route_arcs, (best_route.path[i], best_route.path[i+1]))
    end
    best_route_customers = best_route.path[2:best_route.length]
    z_vars = [z[u, v] for (u, v) in best_route_arcs]
    x_vars = [x[i, j] for i in best_route_customers]
    sol_vars = vcat(z_vars, x_vars)
    sol_vals = ones(Float64, length(z_vars) + length(x_vars))
    sol_cost = min_reduced_cost

    ## Submit the solution of the subproblem to Coluna
    ## THIRD CHANGE HERE:
    ## You must attach the visited customers `R1cVarData` to the solution of the subproblem
    MOI.submit(
        model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals,
        R1cVarData(best_route.path)
    )
    ## END OF THIRD CHANGE
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), sol_cost)
end

MOI.set(model, MOI.UserCutCallback(), r1c_callback);
JuMP.optimize!(model)

# ### Multi-stages pricing callback

# In this section, we implement a pricing heuristic that can be used together with the exact
# pricing callback to generate sub-problems solutions. 

# The idea of the heuristic is very simple:

# - Given a facility `j`, the heuristic computes the closest customer to j, add it to the route.
# - Then, while the reduced cost keeps improving, the heuristic computes and adds to the route 
# the nearest neighbor to the last customer of the route. It stops if the maximum length of the route is reached.

# We first define an auxiliary function used to compute the route tail's nearest neighbor at each step:
function add_nearest_neighbor(route::Route, customers, costs)
    ## get the last customer of the route
    loc = last(route.path)
    ## initialize its nearest neighbor to zero and mincost to infinity
    (nearest, mincost) = (0, Inf)
    ## compute nearest and mincost
    for i in customers
        if !(i in route.path) # implying in particular (i != loc)
            if (costs[loc, i] < mincost)
                nearest = i
                mincost = costs[loc, i]
            end
        end
    end
    ## add the last customer's nearest neighbor to the route 
    if nearest != 0
        push!(route.path, nearest)
        route.length += 1
    end
end;

# We then define our heuristic for the enumeration of the routes, the method returns the best route found by he heuristic together with its cost:
function enumeration_heuristic(x_red_costs, z_red_costs, j)
    ## initialize our "greedy best route"
    best_route = Route(1, [j])
    ## initialize the route's cost to zero
    current_redcost = 0.0
    old_redcost = Inf

    ## main loop
    while (current_redcost < old_redcost)
        add_nearest_neighbor(best_route, customers, arc_costs)
        old_redcost = current_redcost
        current_redcost = x_contribution(best_route, j, x_red_costs) +
                          z_contribution(best_route, z_red_costs)
        ## max length is reached
        if best_route.length == nb_positions
            break
        end
    end
    return (best_route, current_redcost)
end

# We can now define our inexact pricing callback:
function approx_pricing(cbdata)

    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
    )
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )

    ## call the heuristic to elect the "greedy best route":
    best_route, sol_cost = enumeration_heuristic(x_red_costs, z_red_costs, j)

    ## build the solution:
    best_route_arcs = Vector{Tuple{Int,Int}}()
    for i in 1:(best_route.length-1)
        push!(best_route_arcs, (best_route.path[i], best_route.path[i+1]))
    end
    best_route_customers = best_route.path[2:length(best_route.path)]

    z_vars = [z[u, v] for (u, v) in best_route_arcs]
    x_vars = [x[i, j] for i in best_route_customers]
    sol_vars = vcat(z_vars, x_vars)
    sol_vals = ones(Float64, length(z_vars) + length(x_vars))

    MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)
    ## as the procedure is inexact, no dual bound can be computed, we set it to -Inf
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), -Inf)
end

# We set the solver, `colgen_stages_pricing_solvers` indicates which solver to use first (here it is `approx_pricing`)
coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "default_optimizer" => GLPK.Optimizer,
    "params" => Coluna.Params(
        solver=Coluna.Algorithm.BranchCutAndPriceAlgorithm(
            maxnumnodes=100,
            colgen_stages_pricing_solvers=[2, 1]
        )
    )
)
# We add the two pricing algorithms to our model: 
model, x, y, z, cov = create_model(coluna, [approx_pricing, pricing_callback])
# We declare our custom data to Coluna: 
BlockDecomposition.customvars!(model, R1cVarData)
BlockDecomposition.customconstrs!(model, [CoverConstrData, R1cCutData]);
for i in customers
    customdata!(cov[i], CoverConstrData(i))
end

# Optimize:
JuMP.optimize!(model)


# ## Benders decomposition

# In this last section, we show you how to solve the linear relaxation of the master program of 
# a Benders Decomposition approach to this facility location demo problem.

# The first stage decisions consist in choosing a subset of facilities to open. 
# The second stage decisions consist in choosing the routes that are assigned to each facility. 
# Because the second stage problem is an integer program, we convexify it into a linear program by formulating it 
# as a convex combination of enumerated routes. 
# The subproblem takes the form of an LP and we solve this linear relaxation of the routing problem for each facility that is open.
# Given that we play with a toy instance, we can enumerate all the routes and use a direct formulation of the second stage subproblem.
# Otherwise, we would have to implement a column generation approach to handle the second-level and select the routes to use.

# In the same spirit as the above models, we use the variables.
# Let `y[j]` equals 1 if the facility `j` is open and 0 otherwise.
# Let `λ[j,k]` equals 1 if route `k` starting from facility `j` is selected and 0 otherwise.

# Since there is only one subproblem at the second stage, we introduce a fake axis that contains
# only one element.
# In the case of Benders, when the second-stage is decomposable, you can imagine the axis as the set of scenarios for instance.

fake = 1
@axis(axis, collect(fake:fake))

coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(solver=Coluna.Algorithm.BendersCutGeneration()
    ),
    "default_optimizer" => GLPK.Optimizer
)

model = BlockModel(coluna);


# We introduce auxiliary structures to make the code readable.

## routes covering customer i from facility j.
covering_routes = Dict(
    (j, i) => findall(r -> (i in r.path), routes_per_facility[j]) for i in customers, j in facilities
)
## routes costs from facility j.
routes_costs = Dict(
    j => [route_original_cost(arc_costs, r) for r in routes_per_facility[j]] for j in facilities
)

# We declare the variables.
@variable(model, 0 <= y[j in facilities] <= 1) ## 1st stage
@variable(model, 0 <= λ[f in axis, j in facilities, k in 1:length(routes_per_facility[j])] <= 1) ## 2nd stage

# We declare the constraints.

## Linking constraints
@constraint(model, open[fake in axis, j in facilities, k in 1:length(routes_per_facility[j])],
    y[j] >= λ[fake, j, k])

## Second-stage constraints 
@constraint(model, cover[fake in axis, i in customers],
    sum(λ[fake, j, k] for j in facilities, k in covering_routes[(j, i)]) >= 1)

## Second-stage constraints
@constraint(model, limit_nb_routes[fake in axis, j in facilities],
    sum(λ[fake, j, q] for q in 1:length(routes_per_facility[j])) <= nb_routes_per_facility
)

## First-stage constraint
@constraint(model, min_opening,
    sum(y[j] for j in facilities) >= 1)

@objective(model, Min,
    sum(facilities_fixed_costs[j] * y[j] for j in facilities) +
    sum(routes_costs[j][k] * λ[fake, j, k] for j in facilities, k in 1:length(routes_per_facility[j])));

# We perform the decomposition over the axis and we optimize the problem.
@benders_decomposition(model, dec, axis)
JuMP.optimize!(model)

# ## Example of comparison of the dual bounds obtained on a larger instance.

# In this section, we propose to create an instance with 3 facilities and 20 customers. We will solve only the root node and look at the dual bound:
# - with the "raw" decomposition model
# - by adding robust cuts
# - by adding non-robust cuts
# - by adding both robust and non-robust cuts

nb_positions = 6
facilities_fixed_costs = [120, 150, 110]
facilities = [1, 2, 3]
customers = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
arc_costs = [
    0.0 125.6 148.9 182.2 174.9 126.2 158.6 172.9 127.4 133.1 152.6 183.8 182.4 176.9 120.7 129.5;
    123.6 0.0 175.0 146.7 191.0 130.4 142.5 139.3 130.1 133.3 163.8 127.8 139.3 128.4 186.4 115.6;
    101.5 189.6 0.0 198.2 150.5 159.6 128.3 133.0 195.1 167.3 187.3 178.1 171.7 161.5 142.9 142.1;
    159.4 188.4 124.7 0.0 174.5 174.0 142.6 102.5 135.5 184.4 121.6 112.1 139.9 105.5 190.9 140.7;
    157.7 160.3 184.2 196.1 0.0 115.5 175.2 153.5 137.7 141.3 109.5 107.7 125.3 151.0 133.1 140.6;
    145.2 120.4 106.7 138.8 157.3 0.0 153.6 192.2 153.2 184.4 133.6 164.9 163.6 126.3 121.3 161.4;
    182.6 152.1 178.8 184.1 150.8 163.5 0.0 164.1 104.0 100.5 117.3 156.1 115.1 168.6 186.5 100.2;
    144.9 193.8 146.1 191.4 136.8 172.7 108.1 0.0 131.0 166.3 116.4 187.0 161.3 148.2 162.1 116.0;
    173.4 199.1 132.9 133.2 139.8 112.7 138.1 118.8 0.0 173.4 131.8 180.6 191.0 133.9 178.7 108.7;
    150.5 171.0 163.8 171.5 116.3 149.1 124.0 192.5 188.8 0.0 112.2 188.7 197.3 144.9 110.7 186.6;
    153.6 104.4 141.1 124.7 121.1 137.5 190.3 177.1 194.4 135.3 0.0 146.4 132.7 103.2 150.3 118.4;
    112.5 133.7 187.1 170.0 130.2 177.7 159.2 169.9 183.8 101.6 156.2 0.0 114.7 169.3 149.9 125.3;
    151.5 165.6 162.1 133.4 159.4 200.5 132.7 199.9 136.8 121.3 118.1 123.4 0.0 104.8 197.1 134.4;
    195.0 101.1 194.1 160.1 147.1 164.6 137.2 138.6 166.7 191.2 169.2 186.0 171.2 0.0 106.8 150.9;
    158.2 152.7 104.0 136.0 168.9 175.7 139.2 163.2 102.7 153.3 185.9 164.0 113.2 200.7 0.0 127.4;
    136.6 174.3 103.2 131.4 107.8 191.6 115.1 127.6 163.2 123.2 173.3 133.0 120.5 176.9 173.8 0.0;
]

locations = vcat(facilities, customers)
nb_customers = length(customers)
nb_facilities = length(facilities)
positions = 1:nb_positions;

routes_per_facility = Dict(
    j => best_route_forall_cust_subsets(arc_costs, customers, j, nb_positions) for j in facilities
);

# We set `maxnumnodes` to zero to optimize only the root node:
coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver=Coluna.Algorithm.TreeSearchAlgorithm(
            maxnumnodes=0,
            conqueralg=Coluna.ColCutGenConquer()
        )
    ),
    "default_optimizer" => GLPK.Optimizer
);


# We define a method to call both `valid_inequalities_callback` and `r1c_callback`:
function cuts_callback(cbdata)
    valid_inequalities_callback(cbdata)
    r1c_callback(cbdata)
end

function attach_data(model, cov)
    BlockDecomposition.customvars!(model, R1cVarData)
    BlockDecomposition.customconstrs!(model, [CoverConstrData, R1cCutData])
    for i in customers
        customdata!(cov[i], CoverConstrData(i))
    end
end;

# First, we solve the root node with the "raw" decomposition model:
model, x, y, z, cov = create_model(coluna, pricing_callback)
attach_data(model, cov)

# dual bound found after optimization = 1588.00

# Then, we re-solve it with the robust cuts:
model, x, y, z, cov = create_model(coluna, pricing_callback)
attach_data(model, cov)
MOI.set(model, MOI.UserCutCallback(), valid_inequalities_callback);

# dual bound found after optimization = 1591.55


# And with non-robust cuts:
model, x, y, z, cov = create_model(coluna, pricing_callback)
attach_data(model, cov)
MOI.set(model, MOI.UserCutCallback(), r1c_callback);

# dual bound found after optimization = 1598.26

# Finally we add both robust and non-robust cuts:
model, x, y, z, cov = create_model(coluna, pricing_callback)
attach_data(model, cov)
MOI.set(model, MOI.UserCutCallback(), cuts_callback);

# dual bound found after optimization =  1600.63

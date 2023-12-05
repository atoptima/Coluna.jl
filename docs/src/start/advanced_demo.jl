# # Advanced tutorial - Location Routing

# We demonstrate the main features of Coluna on a variant of the Location Routing problem.
# In the Location Routing Problem, we are given a set of facilities and a set of customers.
# Each customer must be delivered by a route starting from one facility. Each facility has 
# a setup cost, while the cost of a route is the distance traveled.

# A route is defined as a vector of locations that satisfies the following rules:
# - it must start from an open facility location
# - it can finish at any customer (open route variant)
# - its length is limited (the maximum number of visited locations is equal to a constant `nb_positions`)

# Our objective is to minimize the sum of fixed costs for opening facilities and the total traveled distance
# while ensuring that each customer is covered by a route.


# In this tutorial, we will show you how to solve this problem by applying:
# - a direct approach with JuMP and a MILP solver (without Coluna)
# - a branch-and-price algorithm provided by Coluna, which uses a custom pricing callback to optimize pricing subproblems
# - a robust branch-cut-and-price algorithm, which separates valid inequalities on the original arc variables (so-called "robust" cuts) 
# - a non-robust branch-cut-and-price algorithm, which separates valid inequalities on the route variables of the Dantzig-Wolfe reformulation (so-called "non-robust" cuts) 
# - a multi-stage column generation algorithm using two different pricing solvers
# - a classic Benders decomposition approach, which uses the LP relaxation of the subproblem

# For illustration purposes, we use a small instance with 2 facilities and 7 customers. 
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

## each customer is visited once
@constraint(model, cov[i in customers],
    sum(x[i, j, k, p] for j in facilities, k in routes_per_facility, p in positions) == 1)

## a facility is open if there is a route starting from it
@constraint(model, setup[j in facilities, k in routes_per_facility],
    sum(x[i, j, k, 1] for i in customers) <= y[j])

## flow conservation
@constraint(model, flow_conservation[j in facilities, k in routes_per_facility, p in positions; p > 1],
    sum(x[i, j, k, p] for i in customers) <= sum(x[i, j, k, p-1] for i in customers))

## there is an arc between two customers whose demand is satisfied by the same route at consecutive positions
@constraint(model, route_arc[i in customers, l in customers, j in facilities, k in routes_per_facility, p in positions; p > 1 && i != l],
    z[i, l] >= x[l, j, k, p] + x[i, j, k, p-1] - 1)

## there is an arc between facility `j` and the first customer visited by route `k` from facility `j`
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

# One can solve the problem by exploiting its structure with a Dantzig-Wolfe decomposition approach.
# The subproblem induced by such decomposition amounts to generate routes starting from each facility. 
# A possible decomposition is to consider a subproblem associated with each vehicle, generating the vehicle route.
# However, for a given facility, the vehicles that are identical will give rise to the same subproblem and route solutions.
# So instead of this decomposition with several identical subproblems for each facility, we define below a single subproblem per facility.
# For each subproblem, we define its multiplicity, i.e. we bound the number of solutions of this subproblem that can be used in a master solution.

# The following method creates the model according to the decomposition described: 
function create_model(optimizer, pricing_algorithms)
    ## A user should resort to axes to communicate to Coluna how to decompose a formulation.
    ## For our problem, we declare an axis over the facilities, thus `facilities_axis` contain subproblem indices.
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

    ## `open_facilities` are master constraints ensuring that the depot is open if one vehicle
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

    ## Subproblems generate routes starting from each facility.
    ## The number of routes from each facility is at most `nb_routes_per_facility`.
    subproblems = BlockDecomposition.getsubproblems(dec)
    specify!.(subproblems, lower_multiplicity=0, upper_multiplicity=nb_routes_per_facility, solver=pricing_algorithms)

    ## We define `z` as a subproblem variable common to all subproblems.
    ## Each implicit variable `z` replaces a sum of explicit `z'` variables: `z[u,v] = sum(z'[j,u,v] for j in facilities_axis)`
    ## This way the model is simplified, and column generation is accelerated as the reduced cost for pair `z[u,v]` is calculated only once
    ## instead of performing the same reduced cost calculation for variables `z'[j,u,v]`, `j in facilities_axis`.
    subproblemrepresentative.(z, Ref(subproblems))

    return model, x, y, z, cov
end;

# Contrary to the direct model, we do not add constraints to ensure the
# feasibility of the routes because we solve our subproblems in a pricing callback.
# The user who implements the pricing callback has the responsibility to create only feasible routes.

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

# If the user declares all the necessary subproblem constraints and possibly additional subproblem variables 
# to describe the set of feasible subproblem solutions, Coluna may perform automatic Dantzig-Wolfe 
# decomposition in which the pricing subproblems are solved by applying a (default) MIP solver. 
# In our case, applying a MIP solver is not the most efficient way to solve the pricing problem. 
# Therefore, we implement an ad-hoc algorithm for solving the pricing subproblems and declare it as a pricing callback.
# In our pricing callback for a given facility, we inspect all feasible routes enumerated before calling the branch-cut-and-price algorithm.
# The inspection algorithm calculates the reduced cost for each enumerated route and returns a route with the minimum reduced cost.

# We first define a structure to store the routes:
mutable struct Route
    length::Int # record the length of the route (number of visited customers + 1) 
    path::Vector{Int} # record the sequence of visited customers 
end;

# We can reduce the number of enumerated routes by exploiting the following property.
# Consider two routes starting from the same facility and visiting the same subset of locations (customers).
# These two routes correspond to columns with the same vector of coefficients in master constraints. 
# A solution containing the route with a larger traveled distance (i.e., larger route original cost) is dominated:
# this dominated route can be replaced by the other route without increasing the total solution cost. 
# Therefore, for each subset of locations of a size not exceeding the maximum one, 
# the enumeration procedure keeps only one route visiting this subset, the one with the smallest cost.

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

# This procedure finds a least-cost sequence of visiting the given set of customers starting from a given facility.

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

# We are now able to compute a dominating route for all the possible customers' subsets,
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

# We store all the information given by the enumeration phase in a dictionary.
# For each facility id, we match a vector of routes that are the best visiting sequences
# for each possible subset of customers.

routes_per_facility = Dict(
    j => best_route_forall_cust_subsets(arc_costs, customers, j, nb_positions) for j in facilities
)

# Our pricing callback must compute the reduced cost of each route, 
# given the reduced cost of the subproblem variables `x` and `z`.
# Remember that subproblem variables `z` are implicitly defined by master representative variables `z`.
# We remark that `z` variables participate only in the objective function.
# Thus their reduced costs are initially equal to the original costs (i.e., objective coefficients)
# This is not true anymore after adding branching constraints and robust cuts involving variables `z`.

# We need methods to compute the contributions to the reduced cost of the `x` and `z` variables:

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

    ## Retrieve the route's arcs.
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

    ## Submit the solution to the subproblem to Coluna.
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


# ### Strengthening the master with linear valid inequalities on the original variables (so-called "robust" cuts)

# To improve the quality of the linear relaxation, a family of classic facility location valid inequalities can be used:
#
# ```math
# x_{ij} \leq y_j\; \forall i \in I, \forall j \in J
# ```
# where $I$ is the set of customers and $J$ the set of facilities.

# We declare a structure representing an inequality in this family:
struct OpenFacilityInequality
    facility_id::Int
    customer_id::Int
end

# To identify violated valid inequalities from a current master LP solution, 
# we proceed by enumeration (i.e. iterating over all pairs of customer and facility).
# Enumeration separation procedure is implemented in the following callback.

function valid_inequalities_callback(cbdata)
    ## Get variables valuations and store them in dictionaries.
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

# We re-declare the model and optimize it with these valid inequalities:
model, x, y, z, _ = create_model(coluna, pricing_callback);
MOI.set(model, MOI.UserCutCallback(), valid_inequalities_callback);
JuMP.optimize!(model)


# ### Strengthening the master with valid inequalities on the column generation variables (so-called "non-robust" cuts)

# In order to further strengthen the linear relaxation of the Dantzig-Wolfe reformulation, 
# we separate a family of subset-row cuts, which is a subfamily of Chvátal-Gomory rank-1 cuts (R1C), 
# obtained from the set-partitioning constraints. 
# These cuts cannot be expressed as a linear combination of the original variables of the model. 
# Instead, they are expressed with the master columns variables $λ_k$, $k \in K$, where $K$ is the set of generated columns
# or set of solutions returned by the pricing subproblems. 
# Subset-row cuts are "non-robust" in the sense that they modify the structure of the pricing subproblems, 
# and not just the reduced cost of subproblem variables. Thus, the implementation of the pricing callback should 
# be updated to take into account dual costs associated with non-robust cutting planes. 

# Each Chvátal-Gomory rank-1 cut is characterized by a subset of set-partitioning constraints, or equivalently by a subset $C$ of customers,
# and a multiplier $\alpha_i$ for each customer $i\in C$:
# ```math
# \sum_{k \in K} \lfloor \sum_{i \in C} \alpha_i \tilde{x}^k_{i,j} \lambda_{k} \rfloor \leq \lfloor \sum_{i\in C} \alpha_i \rfloor, \;  C \subseteq I,
# ```
# where $\tilde{x}^k_{ij}$ is the value of the variable $x_{ij}$ in the $k$-th column generated. 
# For subset-row cuts, $|C|=3$, and $\alpha_i=\frac{1}{2}$, $i\in C$.

# Since we obtain subset-row cuts based on set-partitioning constraints, we must be able to
# differentiate them from the other constraints of the model. 
# To do this, we exploit a feature of Coluna that allows us to attach custom data to the
# constraints and variables of a model, via the add-ons of BlockDecomposition package. 

# First, we create special custom data with the only information we need to characterize 
# our cover constraints: the customer id that corresponds to this constraint.
struct CoverConstrData <: BlockDecomposition.AbstractCustomConstrData
    customer::Int
end

# We re-create the model:
(model, x, y, z, cov) = create_model(coluna, pricing_callback);

# We declare our custom data to Coluna and we attach one custom data to each cover constraint
BlockDecomposition.customconstrs!(model, CoverConstrData);

for i in customers
    customdata!(cov[i], CoverConstrData(i))
end

# We perform the separation by enumeration (i.e. iterating over all subsets of customers of size three).

# The subset-row cut has the following form:
# ```math
# \sum_{k \in K} \tilde{\alpha}(C, k) \lambda_{k} \leq 1\; C \subseteq I, |C| = 3,
# ```
# where coefficient $\tilde{\alpha}(C, k)$ equals $1$ if route $k$ visits at least two customers of $C$; $0$ otherwise.

# For instance, if we consider separating a cut over constraints `cov[3]`, `cov[6]` and `cov[8]`,
# then the route `1`->`4`->`6`->`7` has a zero coefficient while the route `1`->`4`->`6`->`3`
# has a coefficient equal to one.

# Since columns are generated dynamically, we cannot pre-compute the coefficients of columns in the subset-row cuts. 
# Instead, coefficients are computed dynamically via a user-defined `computecoeff` method which takes
# a cut and a column as arguments. To recognize which cut and which column are passed to the method, 
# custom data structures are attached to the cut constraints and the master variables. 
# When a new column is generated, Coluna computes its coefficients in the original constraints and robust cuts
# using coefficients of subproblem variables in the master constraints. 
# Coluna retrieves coefficients of the new column in the non-robust cuts by calling the `computecoeff` method for the column and each such cut. 
# When a new non-robust cut is generated, Coluna retrieves the coefficients of columns in this cut by calling the `computecoeff` method for the cut and all existing columns. 

# We now proceed to the implementation of necessary data structures and methods needed to support the subset-row cuts.
# First, we attach a custom data structure to master columns `λ_k` associated with a given route `k`.
# They record the set of customers that are visited by the given route `k`.

# Thus, to each `λ_k`, we associate a `R1cVarData` structure that carries the customers it visits.  
struct R1cVarData <: BlockDecomposition.AbstractCustomVarData
    visited_locations::Vector{Int}
end

# Then, we attach a `R1cCutData` custom data structure to the subset-row cuts.
# It contains the set $C$ of customers characterizing the cut. 
struct R1cCutData <: BlockDecomposition.AbstractCustomVarData
    cov_constrs::Vector{Int}
end

# We declare our custom data to Coluna via BlockDecomposition add-ons: 
BlockDecomposition.customvars!(model, R1cVarData)
BlockDecomposition.customconstrs!(model, [CoverConstrData, R1cCutData]);

# The next method calculates the coefficients of a column `λ_k` in a subset-row cut:
function Coluna.MathProg.computecoeff(
    var_custom_data::R1cVarData, constr_custom_data::R1cCutData
)
    return floor(1 / 2 * length(var_custom_data.visited_locations ∩ constr_custom_data.cov_constrs))
end

# We also need to define a second method for the case of the cover constraints.
# Indeed, we use custom data to know the customer attached to each cover constraint
# There is no contribution of the non-robust part of the coefficient of the `λ_k`, so
# the method returns 0.
function Coluna.MathProg.computecoeff(::R1cVarData, ::CoverConstrData)
    return 0
end

# We are now able to write our rank-one cut callback completely:
function r1c_callback(cbdata)
    original_sol = cbdata.orig_sol
    master = Coluna.MathProg.getmodel(original_sol)
    ## Retrieve the cover constraints. 
    cov_constrs = Int[]
    for constr in values(Coluna.MathProg.getconstrs(master))
        constr_custom_data = Coluna.MathProg.getcustomdata(master, constr)
        if typeof(constr_custom_data) <: CoverConstrData
            push!(cov_constrs, constr_custom_data.customer)
        end
    end

    ## Retrieve the master columns λ and their values in the current fractional solution
    lambdas = Tuple{Float64,Coluna.MathProg.Variable}[]
    for (var_id, val) in original_sol
        if Coluna.MathProg.getduty(var_id) <= Coluna.MathProg.MasterCol
            push!(lambdas, (val, Coluna.MathProg.getvar(master, var_id)))
        end
    end

    ## Separate the valid subset-row cuts violated by the current solution.
    ## For a fixed subset of customers of size three, iterate on the master columns 
    ## and check if lhs > 1:
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

# When creating non-robust constraints, only the linear (i.e., robust) part is passed to the model.
# In our case, the constraint `0 <= 1` is passed.
# As explained above, the non-robust part is computed by calling the `computecoeff` method using 
# the structure of type `R1cCutData` provided.

# Finally, we need to update our pricing callback to take into account the active non-robust cuts. 
# The contribution of these cuts to the reduced cost of a column is not captured by the reduced cost
# of subproblem variables. We must therefore take this contribution into account manually, by inquiring 
# the set of existing non-robust cuts and their values in the current dual solution. 

# The contribution of a subset-row cut to the reduced cost of a route is managed by the following method:
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
# - retrieve the dual cost of the subset-row cuts
# - take into account the contribution of the subset-row cuts in the reduced cost of the route
# - attach custom data to the route so that its coefficient in the existing non-robust cuts can be computed 
function pricing_callback(cbdata)
    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
    )
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )

    ## FIRST CHANGE HERE:
    ## Get the dual values of the constraints of the specific type to compute the contributions of
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
    ## Keep route with the minimum reduced cost: contribution of the subproblem variables and 
    ## the non-robust cuts.
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
    ## You must attach the visited customers in the structure of type `R1cVarData` to the solution of the subproblem
    MOI.submit(
        model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals,
        R1cVarData(best_route.path)
    )
    ## END OF THIRD CHANGE
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), sol_cost)
end

MOI.set(model, MOI.UserCutCallback(), r1c_callback);
JuMP.optimize!(model)

# ### Multi-stage pricing callback

# In this section, we implement a pricing heuristic that can be used together with the exact
# pricing callback to generate subproblems solutions. 

# The idea of the heuristic is very simple:

# - Given a facility `j`, the heuristic finds the closest customer to `j` and adds it to the route.
# - Then, while the reduced cost keeps improving and the maximum length of the route is not reached, the heuristic computes and adds to the route the nearest neighbor to the last customer of the route. 

# We first define an auxiliary function used to compute the route tail's nearest neighbor at each step:
function add_nearest_neighbor(route::Route, customers, costs)
    ## Get the last customer of the route.
    loc = last(route.path)
    ## Initialize its nearest neighbor to zero and mincost to infinity.
    (nearest, mincost) = (0, Inf)
    ## Compute nearest and mincost.
    for i in customers
        if !(i in route.path) # implying in particular (i != loc)
            if (costs[loc, i] < mincost)
                nearest = i
                mincost = costs[loc, i]
            end
        end
    end
    ## Add the last customer's nearest neighbor to the route.
    if nearest != 0
        push!(route.path, nearest)
        route.length += 1
    end
end;

# We then define our heuristic for the enumeration of the routes, the method returns the best route found by the heuristic together with its cost:
function enumeration_heuristic(x_red_costs, z_red_costs, j)
    ## Initialize our "greedy best route".
    best_route = Route(1, [j])
    ## Initialize the route's cost to zero.
    current_redcost = 0.0
    old_redcost = Inf

    ## main loop
    while (current_redcost < old_redcost)
        add_nearest_neighbor(best_route, customers, arc_costs)
        old_redcost = current_redcost
        current_redcost = x_contribution(best_route, j, x_red_costs) +
                          z_contribution(best_route, z_red_costs)
        ## Max length is reached.
        if best_route.length == nb_positions
            break
        end
    end
    return (best_route, current_redcost)
end;

# We can now define our heuristic pricing callback:
function approx_pricing(cbdata)

    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
    )
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )

    ## Call the heuristic to elect the "greedy best route":
    best_route, sol_cost = enumeration_heuristic(x_red_costs, z_red_costs, j)

    ## Build the solution:
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
    ## As the procedure is inexact, no dual bound can be computed, we set it to -Inf.
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), -Inf)
end;

# We set the solver; `colgen_stages_pricing_solvers` indicates which solver to use first (here it is `approx_pricing`)
coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "default_optimizer" => GLPK.Optimizer,
    "params" => Coluna.Params(
        solver=Coluna.Algorithm.BranchCutAndPriceAlgorithm(
            maxnumnodes=100,
            colgen_stages_pricing_solvers=[2, 1]
        )
    )
);
# We add the two pricing algorithms to our model: 
model, x, y, z, cov = create_model(coluna, [approx_pricing, pricing_callback]);
# We declare our custom data to Coluna: 
BlockDecomposition.customvars!(model, R1cVarData)
BlockDecomposition.customconstrs!(model, [CoverConstrData, R1cCutData]);
for i in customers
    customdata!(cov[i], CoverConstrData(i))
end

# Optimize:
JuMP.optimize!(model)


# ## Benders decomposition

# In this section, we show how one can solve the linear relaxation of the master program of 
# a Benders Decomposition approach to this facility location demo problem.

# The first-stage decisions consist in choosing a subset of facilities to open. 
# The second-stage decisions consist in choosing the routes that are assigned to each facility. 
# The second stage problem is an integer program, so for simplicity, we use its linear relaxation instead. To improve the quality of this
# relaxation, we enumerate the routes and use one variable per route. As this approach is practical only for small instances, 
# we use it only for illustration purposes. For larger instances, we would have to implement a column generation approach 
# to solve the subproblem, i.e., the Benders cut separation problem. 

# In the same spirit as the above models, we use the variables.
# Let `y[j]` equal 1 if the facility `j` is open and 0 otherwise.
# Let `λ[j,k]` equal 1 if route `k` starting from facility `j` is selected and 0 otherwise.

# Since there is only one subproblem in the second stage, we introduce a fake axis that contains
# only one element. This approach can be generalized to the case where customer demand uncertainty is expressed with scenarios. 
# In this case, we would have one subproblem for each scenario, and the axis would have been defined for the set of scenarios.
# In our case, the set of scenarios consists of one "fake" scenario. 

fake = 1
@axis(axis, collect(fake:fake))

coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(solver=Coluna.Algorithm.BendersCutGeneration()
    ),
    "default_optimizer" => GLPK.Optimizer
)

model = BlockModel(coluna);


# We introduce auxiliary structures to improve the clarity of the code.

## routes covering customer i from facility j.
covering_routes = Dict(
    (j, i) => findall(r -> (i in r.path), routes_per_facility[j]) for i in customers, j in facilities
);
## routes costs from facility j.
routes_costs = Dict(
    j => [route_original_cost(arc_costs, r) for r in routes_per_facility[j]] for j in facilities
);

# We declare the variables.
@variable(model, 0 <= y[j in facilities] <= 1) ## 1st stage
@variable(model, 0 <= λ[f in axis, j in facilities, k in 1:length(routes_per_facility[j])] <= 1); ## 2nd stage

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
## This constraint is redundant, we add it in order not to start with an empty master problem
@constraint(model, min_opening,
    sum(y[j] for j in facilities) >= 1)

@objective(model, Min,
    sum(facilities_fixed_costs[j] * y[j] for j in facilities) +
    sum(routes_costs[j][k] * λ[fake, j, k] for j in facilities, k in 1:length(routes_per_facility[j])));

# We perform the decomposition over the axis and we optimize the problem.
@benders_decomposition(model, dec, axis)
JuMP.optimize!(model)

# ## Example of comparison of the dual bounds 

# In this section, we use a larger instance with 3 facilities and 13 customers. We solve only the root node and look at the dual bound:
# - with the standard column generation (without cut separation)
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

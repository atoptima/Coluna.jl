# # Advanced tutorial - Location Routing

# We demonstrate the main features of Coluna on a variant of the Location Routing problem.
# In the Location Routing Problem, we are given a set of facilities and a set of customers.
# Each customers must be delivered by a route starting from one facility. Each facility has 
# a setup cost and the cost of a route is the distance traveled.

# A route is defined as a vector of locations that satisfies the following rules:
 
# - any route must start from a open facility location
# - every route has a maximum length, i.e. the number of visited locations cannot exceed a fixed constant `nb_positions`
# - the routes are said to be open, i.e. finish at last visited customer. 

# Our objective is to minimize the fixed costs of opened facilities and the distance traveled by the routes while
# ensuring that each customer is at least visited once by a route.

# In this tutorial, we work on a small instance with 2 facilities and 7 customers. 
# The maximum length of a route is fixed to 4. 

nb_positions = 4
facilities_fixed_costs = [120, 150]
facilities = [1, 2]
customers = [3, 4, 5, 6, 7, 8, 9]
arc_costs = 
[
    0.0  25.3  25.4  25.4  35.4  37.4  31.9  24.6  34.2;
    25.3   0.0  21.2  16.2  27.1  26.8  17.8  16.7  23.2;
    25.4  21.2   0.0  14.2  23.4  23.8  18.3  17.0  21.6;
    25.4  16.2  14.2   0.0  28.6  28.8  22.6  15.6  29.5;
    35.4  27.1  23.4  28.6   0.0  42.1  30.4  24.9  39.1;
    37.4  26.8  23.8  28.8  42.1   0.0  32.4  29.5  38.2;
    31.9  17.8  18.3  22.6  30.4  32.4   0.0  22.5  30.7;
    24.6  16.7  17.0  15.6  24.9  29.5  22.5   0.0  21.4;
    34.2  23.2  21.6  29.5  39.1  38.2  30.7  21.4   0.0;
]
locations  = vcat(facilities, customers)
nb_customers = length(customers)
nb_facilities = length(facilities)
positions = 1:nb_positions;

# In this tutorial, we will use the following packages:

using JuMP, HiGHS, GLPK, BlockDecomposition, Coluna;

# We want to set an upper bound `nb_routes_per_facility` on the number of routes starting from a facility. 
# This limit is calculated as follows:

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
    sum(x[i,j,k,1] for i in customers) <= y[j]) 

## flow conservation
@constraint(model, flow_conservation[j in facilities, k in routes_per_facility, p in positions; p > 1], 
    sum(x[i, j, k, p] for i in customers) <= sum(x[i, j, k, p-1] for i in customers)) 

## there is an arc between two customers whose demand is satisfied by the same route at consecutive positions
@constraint(model, route_arc[i in customers, l in customers, j in facilities, k in routes_per_facility, p in positions; p > 1 && i != l], 
    z[i,l] >= x[l, j, k, p] + x[i, j, k, p-1] - 1)

## there is an arc between the facility `j` and the first customer visited by the route `k` from facility `j`
@constraint(model, start_arc[i in customers, j in facilities, k in routes_per_facility], 
        z[j,i] >= x[i, j, k, 1]);

# We set the objective function:

@objective(model, Min,
    sum(arc_costs[u, v] * z[u, v] for u in locations, v in locations) 
    +
    sum(facilities_fixed_costs[j] * y[j] for j in facilities));

# and we optimize the model:

#optimize!(model)
#objective_value(model)

# We find an optimal solution involving two routes starting from facility 1:
# - `1` -> `8` -> `9` -> `3` -> `6`
# - `1` -> `4` -> `5` -> `7``

# ## Decomposed model

# We can exploit the structure of the problem by generating routes starting from each facility. 
# The most immediate decomposition is to consider each route traveled by a vehicle as a subproblem.
# However, at a given facility, vehicles are identical and therefore any vehicle can travel
# on any route. So we have several identical subproblems at each facility.

# In this tutorial, we plan to:
# - solve the subproblems using a pricing callback
# - strengthen the master problem using robust valid inequalities
# - strengthen the master problem using non-robust valid inequalities
# - speed-up the optimization using multi-stage column generation.
 
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
    ## `z[u,v]` is a subproblem variable equal to 1 if a vehicle travels from u to v; 0 otherwise.
    ## we don't use the `facilities_axis` axis here because the `z` variables are defined as
    ## representatives of the subproblems later.
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
end

# Note that contrary to the direct model, we don't have to add constraints to ensure the
# consistency of the routes because we solve our subproblems using a pricing callback.
# The pricing callback will therefore have the responsibility to create consistent routes.

# We setup Coluna:

coluna = optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm( ## default branch-and-bound of Coluna
            maxnumnodes = 100,
            conqueralg = Coluna.ColCutGenConquer() ## default column and cut generation of Coluna
        ) ## default branch-cut-and-price
    ),
    "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
);

# ### Pricing callback

# Each subproblem could be solved by a MIP, provided the right sub-problem constraints are added.
# Here, we propose a resolution by enumeration within a pricing callback. 
# The general idea of enumeration is very simple: we enumerate the possible routes from a
# facility and keep the one with the lowest reduced cost, i.e. the one that improves the
# current solution the most. 
# Enumerating all possible routes is very expensive.
# We improve the pricing efficiency a bit by pre-processing, for a given subset of customers 
# and a given facility, the best order to visit the customers of the subset. 
# This order depends only on the original cost of the arcs, so we need a method to compute it:

mutable struct Route
    length::Int
    path::Vector{Int} 
end

function route_original_cost(costs, route::Route)
    route_cost = 0.0
    path = route.path
    path_length = route.length
    for i in 1:(path_length-1)
        route_cost += costs[path[i], path[i+1]]
    end
    return route_cost
end

function best_visit_order(costs, cust_subset, facility_id)
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
                         (r, route_original_cost(costs, r)), all_routes )
    ## keep the best visit order
    tmp = argmin([c for (_, c) in routes_costs])
    (best_order, _) = routes_costs[tmp]
    return best_order
end

# We are now able to compute the best route for all the possible customers subsets, given a facility id:

using Combinatorics

function best_route_forall_cust_subsets(costs, customers, facility_id, max_size)
    best_routes = Vector{Route}()
    all_subsets = Vector{Vector{Int}}()
    for subset_size in 1:max_size
        subsets = collect(combinations(customers, subset_size))
        for s in subsets
            push!(all_subsets, s)
        end
    end 
    for s in all_subsets
        route_s = best_visit_order(costs, s, facility_id)
        push!(best_routes, route_s)
    end 
    return best_routes
end

# We store all the information given by the pre-computation in a dictionary. To each facility id we match a vector of routes that are the best visiting orders for each possible subset of customers.

routes_per_facility = Dict(
    j => best_route_forall_cust_subsets(arc_costs, customers, j, nb_positions) for j in facilities
)


# We must also declare methods to calculate the contribution to the reduced cost of the two types of subproblem variables, `x` and `z`:

function x_contribution(route::Route, j::Int, x_red_costs)
    x = 0.0
    visited_customers = route.path[2:route.length]
    for i in visited_customers
        x += x_red_costs["x_$(i)_$(j)"]
    end
    return x
end

function z_contribution(route::Route, z_red_costs)
    z = 0.0
    for i in 1:(route.length-1) 
        current_position = route.path[i]
        next_position = route.path[i+1]
        z += z_red_costs["z_$(current_position)_$(next_position)"]
    end
    return z 
end



# We are now able to write our pricing callback: 

function pricing_callback(cbdata)
    ## get the id of the facility
    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    
    ## retrieve variables reduced costs
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
        
    )
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )

    ## keep route with minimum reduced cost.
    red_costs_j = map(r -> (
            r, 
            x_contribution(r, j, x_red_costs) + z_contribution(r, z_red_costs) # the reduced cost of a route is the sum of the contribution of the variables
        ), routes_per_facility[j]
    ) 
    min_index = argmin([x for (_,x) in red_costs_j])
    (best_route, min_reduced_cost) = red_costs_j[min_index]

    ## Create the solution (send only variables with non-zero values)

    ## retrieve the route's arcs
    best_route_arcs = Vector{Tuple{Int, Int}}()
    for i in 1:(best_route.length - 1)
        push!(best_route_arcs, (best_route.path[i], best_route.path[i+1]))
    end
    best_route_customers = best_route.path[2:best_route.length]
    z_vars = [z[u, v] for (u,v) in best_route_arcs]
    x_vars = [x[i, j] for i in best_route_customers]
    sol_vars = vcat(z_vars, x_vars)
    sol_vals = ones(Float64, length(z_vars) + length(x_vars))
    sol_cost = min_reduced_cost

    ## Submit the solution of the subproblem to Coluna
    MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)
    
    ## Submit the dual bound to the solution of the subproblem
    ## This bound is used to compute the contribution of the subproblem to the lagrangian
    ## bound in column generation.
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), sol_cost) # optimal solution

end

# Create the model:
model, x, y, z, _ = create_model(coluna, pricing_callback)
# Solve:
#JuMP.optimize!(model)

# ## TODO: display "raw" decomp model output and comment, transition to next section 

# ### Strengthen with robust cuts (valid inequalities)

# We introduce of first type of classic valid inequalities that tries to improve the 
# integrality of the `y` variables.

# ```math
# x_{ij} <= y_j; \forall i \in customers, \forall j \in facilities
# ```

# We declare a structure representing an instance of this inequality:
struct OpenFacilityInequality
    facility_id::Int
    customer_id::Int
end

# and we write our valid inequalities callback:

function valid_inequalities_callback(cbdata)
    ## Get variables valuations, store them into dictionaries
    x_vals = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_value(cbdata, x[i, j]) for i in customers, j in facilities
    )
    y_vals = Dict(
        "y_$(j)" => BlockDecomposition.callback_value(cbdata, y[j]) for j in facilities
    )

    ## Separate the valid inequalities (i.e. retrieve the inequalities that are violated by 
    ## the current solution) by enumeration.
    inequalities = Vector{OpenFacilityInequality}()

    for j in facilities
        for i in customers
            x_i_j = x_vals["x_$(i)_$(j)"]
            y_j = y_vals["y_$(j)"]
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
end

# We re-declare the model and optimize it with the inequalities_callback:
(model, x, y, z, _) = create_model(coluna, pricing_callback)
MOI.set(model, MOI.UserCutCallback(), valid_inequalities_callback);
#JuMP.optimize!(model)

# TODO: comment on the improvement of the dual bound

# ### Strengthen with non-robust cuts (rank-one cuts)

# Here, we implement special types of cuts called "rank-one cuts" (R1C).
# These cuts are non-robust in the sense that they cannot be expressed only with the
# original variables of the model. In particular, they have to be expressed with the master 
# columns variables $λ_k, k \in K$ where $K$ is the set of generated columns.

# R1Cs are obtained by applying the Chvátal-Gomory procedure once, 
# hence their name, on cover constraints.
# R1Cs have the following form:

# ```math
# \sum_{k \in K} \lfloor \sum_{i \in C} \alpha_c \tilde{x}^k_{i,j} \lambda_k \rfloor \leq \lfloor \sum_{i \in C} \alpha_c \rfloor,  C \subseteq I
# ```

# where:
# - $C$ is a subset of customers
# - $\alpha_c$ is a multiplier
# - $\tilde{x}^k_{ij}$ is the value of the variable $x_{ij}$ in column k

# We must therefore be able to differentiate the cover constraints from the other
# constraints of the model. 
# To do this, we exploit an advantage of Coluna that allows us to attach custom data to the
# constraints and variables of our model.

# First, we create a special custom data with the only information we need to characterize 
# our cover constraints: the customer id that corresponds to this constraint.
struct CoverConstrData <: BlockDecomposition.AbstractCustomData
    customer::Int
end

(model, x, y, z, cov) = create_model(coluna, pricing_callback)

# We declare our custom data to Coluna
BlockDecomposition.customconstrs!(model, CoverConstrData);
# And we attach one custom data to each cover constraint
for i in customers
    customdata!(cov[i], CoverConstrData(i))
end


# The rank-one cuts we are going to add are of the form:
# `sum(c_k λ_k) <= 1.0` 
# for a fixed subset `r1c_cov_constrs` of cover constraints of size 3, with `λ_k` the master columns variables and `c_k` s.t. 
# `c_k = ⌊ 1/2 x |r1c_locations ∩ r1c_cov_constrs| ⌋`
# with `r1c_locations` the current solution (route) that corresponds to `λ_k`.
# e.g. if we consider cover constraints cov[3], cov[6] and cov[8] in our cut, then the route 1-4-6-7 gives a zero coefficient while the route 1-4-6-3 gives a coefficient equal to one. 

# But a problem arises: how to get the current solution `r1c_locations` that corresponds to a given `λ_k` ? To handle that difficulty, we use once again the custom data trick:

# Each `λ_k` is associated to a `R1cVarData` structure that carries the current solution.  
struct R1cVarData <: BlockDecomposition.AbstractCustomData
    visited_locations::Vector{Int}
end

# The rank-one cuts are associated with `R1cCutData` structures indicating which cover constraints are taken into account in the cut. 
struct R1cCutData <: BlockDecomposition.AbstractCustomData
    cov_constrs::Vector{Int}
end

# We declare our custom data to Coluna: 
BlockDecomposition.customvars!(model, R1cVarData)
BlockDecomposition.customconstrs!(model, [CoverConstrData, R1cCutData]);

# This method is called by Coluna to compute the coefficients of the `λ_k` in the cuts:
function Coluna.MathProg.computecoeff(
    ::Coluna.MathProg.Variable, var_custom_data::R1cVarData,
    ::Coluna.MathProg.Constraint, constr_custom_data::R1cCutData
)
    return floor(1/2 * length(var_custom_data.visited_locations ∩ constr_custom_data.cov_constrs))
end

# TODO: fix necessity to write computecoeff for cover constr or explain trick
function Coluna.MathProg.computecoeff(
    ::Coluna.MathProg.Variable, ::R1cVarData, 
    ::Coluna.MathProg.Constraint, ::CoverConstrData) 
    return 0
end

# We are now able to write our rank-one cut callback: 
function r1c_callback(cbdata)
    original_sol = cbdata.orig_sol
    master = Coluna.MathProg.getmodel(original_sol)
    ## retrieve the cover constraints 
    cov_constrs = Int[]
    for constr in values(Coluna.MathProg.getconstrs(master))
        if typeof(constr.custom_data) <: CoverConstrData
            push!(cov_constrs, constr.custom_data.customer)
        end
    end
    
    ## retrieve the master columns λ 
    lambdas = Vector{Any}()
    for (var_id, val) in original_sol
        if Coluna.MathProg.getduty(var_id) <= Coluna.MathProg.MasterCol
            push!(lambdas, (val, Coluna.MathProg.getvar(cbdata.form, var_id)))
        end
    end

    ## separate the valid R1Cs (i.e. those violated by the current solution)
    ## for a fixed subset of cover constraints of size 3, iterate on the master columns and check violation:
    subsets = collect(combinations(cov_constrs, 3))
    for cov_constr_subset in subsets
        violation = 0
        for lambda in lambdas 
            (val, var) = lambda
            if !isnothing(var.custom_data)
                coeff = floor(1/2 * length(var.custom_data.visited_locations ∩ cov_constr_subset))
                violation += coeff * val
            end
        end
        if violation > 1
            ## create the constraint and add it to the model, use custom data to keep information about the cut (= the subset of considered cover constraints)
            MOI.submit(model, 
                      MOI.UserCut(cbdata), 
                      JuMP.ScalarConstraint(JuMP.AffExpr(0.0), MOI.LessThan(1.0)), 
                      R1cCutData(cov_constr_subset)
                      )
        end
    end
    
end

# The last thing we need to do to complete the implementation of R1Cs is to update our pricing callback. Unlike valid inequalities, R1Cs are not expressed directly with the model variables. Thus, their cost is not taken into account in the reduced cost calculations. We must therefore add it "manually" in the callback. 

# The contribution of R1Cs to the reduced cost computation is managed by the following method:
function r1c_contrib(route::Route, custduals)
    cost=0
    if !isempty(custduals)
        for (r1c_cov_constrs, dual) in custduals 
            coeff = floor(1/2 * length(route.path ∩ r1c_cov_constrs))
            cost += coeff*dual
        end
    end
    return cost
end

# We re-write our pricing callback, with the additional contribution that corresponds to R1Cs cost:
function pricing_callback(cbdata)
    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
    )
    x_red_costs = Dict(
        "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
    )
    ## Get the dual values of the custom cuts to calculate contributions of
    ## non-robust cuts to the cost of the solution:
    custduals = Tuple{Vector{Int}, Float64}[]
    for (_, constr) in Coluna.MathProg.getconstrs(cbdata.form.parent_formulation)            
        if typeof(constr.custom_data) == R1cCutData
            push!(custduals, (
                constr.custom_data.cov_constrs,
                Coluna.MathProg.getcurincval(cbdata.form.parent_formulation, constr)
            ))
        end
    end

    ## Keep route with minimum reduced cost,
    ## add variables contribution and also the non-robust cuts contribution 
    red_costs_j = map(r -> (
            r, 
            x_contribution(r, j, x_red_costs) + 
            z_contribution(r, z_red_costs) - #TODO: comment on sign ? 
            r1c_contrib(r, custduals)
        ), routes_per_facility[j]
    ) 
    min_index = argmin([x for (_,x) in red_costs_j])
    (best_route, min_reduced_cost) = red_costs_j[min_index]

    best_route_arcs = Vector{Tuple{Int, Int}}()
    for i in 1:(best_route.length - 1)
        push!(best_route_arcs, (best_route.path[i], best_route.path[i+1]))
    end
    best_route_customers = best_route.path[2:best_route.length]
    z_vars = [z[u, v] for (u,v) in best_route_arcs]
    x_vars = [x[i, j] for i in best_route_customers]
    sol_vars = vcat(z_vars, x_vars)
    sol_vals = ones(Float64, length(z_vars) + length(x_vars))
    sol_cost = min_reduced_cost

    ## Submit the solution of the subproblem to Coluna
    ## TODO: comment on custom data here
    MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals, R1cVarData(best_route.path))
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), sol_cost) 

end


MOI.set(model, MOI.UserCutCallback(), r1c_callback);
#JuMP.optimize!(model)


# ### Multi-stages pricing callback

# In this section, we implement a pricing heuristic that can be used together with the exact pricing callback to generate sub-problems solutions. 

# The idea of the heuristic is very simple:

# - Given `j` the idea of the facility, compute the closest customer to j, add it to the route.
# - While the reduced cost keeps improving, compute and add to the route its last customer's nearest neighbor. Stop if the maximum length of the route is reached.

# We first define an auxiliary function used to compute the route tail's nearest neighbor at each step:
function add_nearest_neighbor(route::Route, customers, costs)
    ## get the last customer of the route
    loc = last(route.path)
    ## initialize its nearest neighbor to zero and mincost to infinity
    (nearest, mincost) = (0, Inf) 
    ## compute nearest and mincost
    for i in customers
        if (i != loc) && !(i in route.path) 
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
end

# Then we define our inexact pricing callback:
function approx_pricing(cbdata)
    
    j = BlockDecomposition.indice(BlockDecomposition.callback_spid(cbdata, model))
    z_red_costs = Dict(
        "z_$(u)_$(v)" => BlockDecomposition.callback_reduced_cost(cbdata, z[u, v]) for u in locations, v in locations
        )
    x_red_costs = Dict(
            "x_$(i)_$(j)" => BlockDecomposition.callback_reduced_cost(cbdata, x[i, j]) for i in customers
        )

    custduals = Tuple{Vector{Int}, Float64}[]
    for (_, constr) in Coluna.MathProg.getconstrs(cbdata.form.parent_formulation)            
        if typeof(constr.custom_data) == R1cCutData
            push!(custduals, (
                constr.custom_data.cov_constrs,
                Coluna.MathProg.getcurincval(cbdata.form.parent_formulation, constr)
            ))
        end
    end

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
    
    best_route_arcs = Vector{Tuple{Int, Int}}()
    for i in 1:(best_route.length - 1)
        push!(best_route_arcs, (best_route.path[i], best_route.path[i+1]))
    end
    best_route_customers = best_route.path[2:length(best_route.path)]
    
    z_vars = [z[u, v] for (u,v) in best_route_arcs]
    x_vars = [x[i, j] for i in best_route_customers]
    sol_vars = vcat(z_vars, x_vars)
    sol_vals = ones(Float64, length(z_vars) + length(x_vars))
    ## take the eventual rank-one cuts contribution into account
    sol_cost = current_redcost - r1c_contrib(best_route, custduals)
        
    MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), sol_cost, sol_vars, sol_vals)
    ## as the procedure is inexact, no dual bound can be computed, we set it to -Inf
    MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), -Inf) 
            
end

# We set the solver, `colgen_stages_pricing_solvers` indicates which solver to use first (here it is `approx_pricing`)
coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => Coluna.Params(
            solver = Coluna.Algorithm.BranchCutAndPriceAlgorithm(
                maxnumnodes = 100,
            colgen_stages_pricing_solvers = [2, 1]
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
#JuMP.optimize!(model)
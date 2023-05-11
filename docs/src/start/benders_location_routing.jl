fake = 1
@axis(axis, collect(fake:fake))

coluna = JuMP.optimizer_with_attributes(
    Coluna.Optimizer,
    "params" => Coluna.Params(
        
        solver = Coluna.Algorithm.BendersCutGeneration()
    ),
    "default_optimizer" => GLPK.Optimizer
)

model = BlockModel(coluna)


covering_routes = Dict(
    (j, i) => findall(r -> (i in r.path), routes_per_facility[j]) for i in customers, j in facilities
)
routes_costs = Dict(
    j => [route_original_cost(arc_costs, r) for r in routes_per_facility[j]] for j in facilities 
)


#master variables
@variable(model, y[j in facilities], Bin)


#sp variables
@variable(model, 0 <= λ[f in axis, j in facilities, k in 1:length(routes_per_facility[j])] <= 1) # λj,q = 1 -> route (j,q) is opened

@constraint(model, open[fake in axis, j in facilities, k in 1:length(routes_per_facility[j])], 
    y[j] >= λ[fake, j, k])

@constraint(model, cover[fake in axis, i in customers], 
    sum(λ[fake, j, k] for j in facilities, k in covering_routes[(j,i)]) >= 1)

@constraint(model, min_opening, 
    sum(y[j] for j in facilities) >= 1)

@objective(model, Min,
    sum(facilities_fixed_costs[j] * y[j] for j in facilities) + 
    sum(routes_costs[j][k] * λ[fake, j, k] for j in facilities, k in 1:length(routes_per_facility[j])))               

@benders_decomposition(model, dec, axis)
JuMP.optimize!(model)
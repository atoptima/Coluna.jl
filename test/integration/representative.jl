@testset "Decomposition with representatives and single subproblem" begin
    d = CvrpToyData(false)
    model, x, cov, mast, sps, dec = cvrp_with_representatives(d)
    JuMP.optimize!(model)
end

@testset "Decomposition with representatives and multiple subproblems" begin
    d = CvrpToyData(true)
    model, x, cov, mast, sps, dec = cvrp_with_representatives(d)
    JuMP.optimize!(model)
end

struct CvrpSol
    travel_cost
    edges
    coeffs
end

struct CvrpData
    vehicle_types
    E
    V
    δ
    edge_costs
    fixed_costs     # by vehicle type
    nb_sols         # by vehicle type
    sp_sols
end

function CvrpToyData(is_hfvrp)
    vehicle_types = is_hfvrp ? [1, 2] : [1]
    E = [(1,2), (1,3), (1,4), (1,5), (2,3), (2,4), (2,5), (3,4), (3,5), (4,5)]
    V = [1,2,3,4,5]
    δ = Dict(
        1 => [(1,2), (1,3), (1,4), (1,5)],
        2 => [(1,2), (2,3), (2,4), (2,5)],
        3 => [(1,3), (2,3), (3,4), (3,5)],
        4 => [(1,4), (2,4), (3,4), (4,5)],
        5 => [(1,5), (2,5), (3,5), (4,5)]
    )
    edge_costs = [10, 11, 13, 12, 4, 5, 6, 7, 8, 9]
    fixed_costs = is_hfvrp ? [0, 10] : [0]
    nb_sols = is_hfvrp ? [4, 13] : [13]
    sp_sols = [
        CvrpSol(20, [(1,2)], [2]),
        CvrpSol(22, [(1,3)], [2]),
        CvrpSol(26, [(1,4)], [2]),
        CvrpSol(24, [(1,5)], [2]),
        CvrpSol(10 + 4 + 11, [(1,2), (2,3), (1,3)], [1, 1, 1]),
        CvrpSol(10 + 5 + 13, [(1,2), (2,4), (1,4)], [1, 1, 1]),
        CvrpSol(10 + 6 + 12, [(1,2), (2,5), (1,5)], [1, 1, 1]),
        CvrpSol(11 + 7 + 13, [(1,3), (3,4), (1,4)], [1, 1, 1]),
        CvrpSol(11 + 8 + 12, [(1,3), (3,5), (1,5)], [1, 1, 1]),
        CvrpSol(13 + 9 + 12, [(1,4), (4,5), (1,5)], [1, 1, 1]),
        CvrpSol(11 + 7 + 9 + 12, [(1,3), (3,4), (4,5), (1,5)], [1, 1, 1, 1]),
        CvrpSol(13 + 7 + 9 + 12, [(1,4), (3,4), (4,5), (1,5)], [1, 1, 1, 1]),
        CvrpSol(11 + 8 + 9 + 13, [(1,3), (3,5), (4,5), (1,4)], [1, 1, 1, 1]),
    ] 
    return CvrpData(vehicle_types, E, V, δ, edge_costs, fixed_costs, nb_sols, sp_sols)
end

function cvrp_with_representatives(data::CvrpData)
    V₊ = data.V[2:end]
    edgeidx = Dict(
        (1,2) => 1,
        (1,3) => 2,
        (1,4) => 3,
        (1,5) => 4,
        (2,3) => 5,
        (2,4) => 6,
        (2,5) => 7,
        (3,4) => 8,
        (3,5) => 9,
        (4,5) => 10
    )
    rcost(sol, rcosts) = sum(
        rcosts[edgeidx[e]] * sol.coeffs[i] for (i,e) in enumerate(sol.edges)
    )

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm(
            maxnumnodes = 10000,
            branchingtreefile = "cvrp.dot"
        )),
        "default_optimizer" => GLPK.Optimizer
    )
    @axis(VehicleTypes, data.vehicle_types)
    model = BlockModel(coluna)
    @variable(model, 0 <= x[e in data.E] <= 2, Int)
    if length(data.vehicle_types) > 1
        @variable(model, y[vt in VehicleTypes] >= 0)
        @objective(model, Min,
            sum(data.fixed_costs[vt] * y[vt] for vt in VehicleTypes) +
            sum(data.edge_costs[i] * x[e] for (i,e) in enumerate(data.E))
        )
    else
        @objective(model, Min, sum(data.edge_costs[i] * x[e] for (i,e) in enumerate(data.E)))
    end
    @constraint(model, cov[v in V₊], sum(x[e] for e in data.δ[v]) == 2)

    @dantzig_wolfe_decomposition(model, dec, VehicleTypes)

    function route_pricing_callback(cbdata)
        if length(data.vehicle_types) > 1
            spid = BlockDecomposition.callback_spid(cbdata, cvrp)
        end
        rcosts = [BlockDecomposition.callback_reduced_cost(cbdata, x[e]) for e in data.E]

        bestsol = data.sp_sols[1]
        bestrc = rcost(bestsol, rcosts)
        for sol in data.sp_sols[2:end]
            rc = rcost(sol, rcosts)
            if rc < bestrc
                bestrc = rc
                bestsol = sol
            end
        end
        if length(data.vehicle_types) > 1
            bestrc += BlockDecomposition.callback_reduced_cost(cbdata, y[spid])
        end

        # Create the solution (send only variables with non-zero values)
        solvars = JuMP.VariableRef[]
        solvals = Float64[]
        for (i,e) in enumerate(bestsol.edges) 
            push!(solvars, x[e])
            push!(solvals, bestsol.coeffs[i])
        end
        if length(data.vehicle_types) > 1
            push!(solvars, y[spid])
            push!(solvals, 1.0)
        end

        # Submit the solution to the subproblem to Coluna
        MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), bestrc, solvars, solvals)
        MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), bestrc)
    end

    master = BlockDecomposition.getmaster(dec)
    subproblems = BlockDecomposition.getsubproblems(dec)

    subproblemrepresentative.(x, Ref(subproblems))

    sp_lm = (length(data.vehicle_types) == 1) ? 2 : 0
    for vt in VehicleTypes
        specify!(
            subproblems[vt], lower_multiplicity = sp_lm, upper_multiplicity = 4,
            solver = route_pricing_callback
        )
    end

    return model, x, cov, master, subproblems, dec
end

@testset "Decomposition with representatives" begin
    d = CvrpToyData()
    model, x, cov, mast, sps, dec = cvrp_with_representatives(d)
    JuMP.optimize!(model)
end

struct CvrpSol
    cost
    edges
    coeffs
end

struct CvrpData
    E
    V
    δ
    costs
    sp_sols
end

function CvrpToyData()
    E = [(1,2), (1,3), (1,4), (1,5), (2,3), (2,4), (2,5), (3,4), (3,5), (4,5)]
    V = [1,2,3,4,5]
    δ = Dict(
        1 => [(1,2), (1,3), (1,4), (1,5)],
        2 => [(1,2), (2,3), (2,4), (2,5)],
        3 => [(1,3), (2,3), (3,4), (3,5)],
        4 => [(1,4), (2,4), (3,4), (4,5)],
        5 => [(1,5), (2,5), (3,5), (4,5)]
    )
    costs = [10, 11, 13, 12, 4, 5, 6, 7, 8, 9]
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
    return CvrpData(E, V, δ, costs, sp_sols)
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
    @axis(VehicleTypes, [1])
    model = BlockModel(coluna)
    @variable(model, 0 <= x[e in data.E] <= 2, Int)

    @constraint(model, cov[v in V₊], sum(x[e] for e in data.δ[v]) == 2)
    @objective(model, Min, sum(data.costs[i] * x[e] for (i,e) in enumerate(data.E)))

    @dantzig_wolfe_decomposition(model, dec, VehicleTypes)


    function route_pricing_callback(cbdata)
        rcosts = [BlockDecomposition.callback_reduced_cost(cbdata, x[e]) for e in E]

        bestsol = data.sp_sols[1]
        bestrc = rcost(bestsol, rcosts)
        for sol in data.sp_sols[2:end]
            rc = rcost(sol, rcosts)
            if rc < bestrc
                bestrc = rc
                bestsol = sol
            end
        end

        # Create the solution (send only variables with non-zero values)
        solvars = JuMP.VariableRef[]
        solvals = Float64[]
        for (i,e) in enumerate(bestsol.edges) 
            push!(solvars, x[e])
            push!(solvals, bestsol.coeffs[i])
        end

        # Submit the solution to the subproblem to Coluna
        MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), bestrc, solvars, solvals)
        MOI.submit(model, BlockDecomposition.PricingDualBound(cbdata), bestrc)
    end

    master = BlockDecomposition.getmaster(dec)
    subproblems = BlockDecomposition.getsubproblems(dec)

    subproblemrepresentative.(x, Ref(subproblems))

    specify!(
        subproblems[1], lower_multiplicity = 2, upper_multiplicity = 4,
        solver = route_pricing_callback
    )

    return model, x, cov, master, subproblems, dec
end

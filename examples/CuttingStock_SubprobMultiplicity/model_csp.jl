function model_scsp(d::DataCsp)
    params = Coluna.Params(use_restricted_master_heur = true,
                           max_num_nodes = 1,
                           restricted_master_heur_solver_type = GLPK.Optimizer)

    csp = Model(with_optimizer(Coluna.ColunaModelOptimizer, params = params,
                               # master_factory = with_optimizer(Gurobi.Optimizer),
                               # pricing_factory = with_optimizer(Gurobi.Optimizer)),
                               # master_factory = with_optimizer(CPELX.Optimizer),
                               # pricing_factory = with_optimizer(CPELX.Optimizer)),
                               master_factory = with_optimizer(GLPK.Optimizer),
                               pricing_factory = with_optimizer(GLPK.Optimizer)),
                bridge_constraints=false)

    xub = [ min(d.orders[o].demand, floor(d.stocksheetswidth/d.orders[o].width))
            for o in 1:d.nborders ]

    @variable(csp, 0 <= x[o in 1:d.nborders] <= xub[o], Int)

    @variable(csp, y, Bin)

    @constraint(csp, cov[o in 1:d.nborders], x[o] >= d.orders[o].demand)

    @constraint(csp, knp,
                sum(x[o] * d.orders[o].width for o in 1:d.nborders)
                - y * d.stocksheetswidth <= 0)

    @objective(csp, Min, y)

    # setting Dantzig Wolfe composition: one subproblem per machine
    function csp_decomp_func(name, key)
        if name == :cov
            return 0
        else
            return 1
        end
    end
    Coluna.set_dantzig_wolfe_decompostion(csp, csp_decomp_func)

    # setting pricing cardinality bounds
    card_bounds_dict = Dict(1 => (0,100))
    Coluna.set_dantzig_wolfe_cardinality_bounds(csp, card_bounds_dict)

    return (csp, x,  y)
end

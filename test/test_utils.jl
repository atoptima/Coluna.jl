@MOIU.model ModelForCachingOptimizer (ZeroOne, Integer) (EqualTo, GreaterThan, LessThan, Interval) () () (SingleVariable,) (ScalarAffineFunction,) () ()



function build_cachingOptimizer_model(n_items::Int, nb_bins::Int,
                                      profits::Vector{Float64},
                                      weights::Vector{Float64},
                                      binscap::Vector{Float64})



    master_optimizer = Cbc.CbcOptimizer()
    coluna_optimizer = CL.ColunaModelOptimizerConstructor(master_optimizer)
    MOI.empty!(coluna_optimizer)
    moi_model = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                      coluna_optimizer)


    # x_vars = Vector{Vector{MOI.VariableIndex}}()
    # for j in 1:n_items
    #     x_vec = MOI.addvariables!(moi_model, nb_bins)
    #     push!(x_vars, x_vec)
    # end



    # knap_constrs = MOI.ConstraintIndex[]



    # for i in 1:nb_bins
    #     cf = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([w_j for j in weights], x), 0.0)
    #     constr = MOI.addconstraint!(model, cf, MOI.LessThan(binscap[i]))
    #     push!(knap_constrs, constr)
    # end


    #     constr = CL.MasterConstr(master_problem.counter,
    #         string("knapConstr_", i), binscap[i], 'L', 'M', 's')
    #     push!(knap_constrs, constr)
    #     CL.add_constraint(master_problem, constr)
    # end

    # cover_constrs = CL.MasterConstr[]
    # for j in 1:n_items
    #     constr = CL.MasterConstr(master_problem.counter,
    #         string("CoverCons_", j), 1.0, 'L', 'M', 's')
    #     push!(cover_constrs, constr)
    #     CL.add_constraint(master_problem, constr)
    # end


    # ### Model constructors
    # params = CL.Params()
    # pricingoptimizer = Cbc.CbcOptimizer()
    # callback = CL.Callback()
    # extended_problem = CL.ExtendedProblemConstructor(master_problem,
    #     CL.Problem[], CL.Problem[], counter, params, params.cut_up, params.cut_lo)
    # model = CL.ModelConstructor(extended_problem, callback, params)
    return moi_model

end


function build_bb_coluna_model(n_items::Int, nb_bins::Int,
                               profits::Vector{Float64}, weights::Vector{Float64},
                               binscap::Vector{Float64})

    counter = CL.VarConstrCounter(0)
    master_problem = CL.SimpleCompactProblem(counter)
    CL.initialize_problem_optimizer(master_problem, Cbc.CbcOptimizer())

    knap_constrs = CL.MasterConstr[]
    for i in 1:nb_bins
        @show typeof(binscap[i])
        constr = CL.MasterConstr(master_problem.counter,
            string("knapConstr_", i), binscap[i], 'L', 'M', 's')
        push!(knap_constrs, constr)
        CL.add_constraint(master_problem, constr)
    end

    cover_constrs = CL.MasterConstr[]
    for j in 1:n_items
        constr = CL.MasterConstr(master_problem.counter,
            string("CoverCons_", j), 1.0, 'L', 'M', 's')
        push!(cover_constrs, constr)
        CL.add_constraint(master_problem, constr)
    end

    x_vars = Vector{Vector{CL.MasterVar}}()
    for j in 1:n_items
        x_vec = CL.MasterVar[]
        for i in 1:nb_bins
            x_var = CL.MasterVar(master_problem.counter, string("x(", j, ",", i, ")"),
                profits[j], 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
            push!(x_vec, x_var)
            CL.add_variable(master_problem, x_var)
            CL.add_membership(x_var, cover_constrs[j], master_problem, 1.0)
            CL.add_membership(x_var, knap_constrs[i], master_problem, weights[j])
        end
        push!(x_vars, x_vec)
    end

    ### Model constructors
    params = CL.Params()
    pricingoptimizer = Cbc.CbcOptimizer()
    callback = CL.Callback()
    extended_problem = CL.ExtendedProblemConstructor(master_problem,
        CL.Problem[], CL.Problem[], counter, params, params.cut_up, params.cut_lo)
    model = CL.ModelConstructor(extended_problem, callback, params)
    return model

end

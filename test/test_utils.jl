@MOIU.model ModelForCachingOptimizer (ZeroOne, Integer) (EqualTo, GreaterThan, LessThan, Interval) () () (SingleVariable,) (ScalarAffineFunction,) () ()


function build_tricky_model()

    coluna_optimizer = CL.ColunaModelOptimizer()

    moi_model = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                      coluna_optimizer)

    x1 = MOI.addvariable!(moi_model)
    x2 = MOI.addvariable!(moi_model)
    x3 = MOI.addvariable!(moi_model)
    x4 = MOI.addvariable!(moi_model)
    x5 = MOI.addvariable!(moi_model)

    objF = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([10.0, 1.0, 1.0], [x1, x2, x3]), 0.0)
    MOI.set!(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objF)
    MOI.set!(moi_model, MOI.ObjectiveSense(), MOI.MinSense)

    cf1 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0, 1.0], [x1, x2, x3]), 0.0)
    constr1 = MOI.addconstraint!(moi_model, cf1, MOI.GreaterThan(5.0))

    cf2 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x2, x3]), 0.0)
    constr2 = MOI.addconstraint!(moi_model, cf2, MOI.LessThan(3.0))

    constr31 = MOI.addconstraint!(moi_model, MOI.SingleVariable(x1), MOI.Integer())
    constr32 = MOI.addconstraint!(moi_model, MOI.SingleVariable(x1), MOI.Interval(1.0, 2.0))

    constr4 = MOI.addconstraint!(moi_model, MOI.SingleVariable(x2), MOI.ZeroOne())
    constr5 = MOI.addconstraint!(moi_model, MOI.SingleVariable(x3), MOI.GreaterThan(0.0))

    constr6 = MOI.addconstraint!(moi_model, MOI.SingleVariable(x4), MOI.EqualTo(0.0))

    cf7 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x4, x5]), 0.0)
    constr7 = MOI.addconstraint!(moi_model, cf7, MOI.EqualTo(0.0))

    ## set coluna optimizers
    master_problem = coluna_optimizer.inner.extended_problem.master_problem
    coluna_optimizer.inner.problemidx_optimizer_map[master_problem.prob_ref] = GLPK.Optimizer()
    CL.set_model_optimizers(coluna_optimizer.inner)

    return moi_model, [x1, x2, x3, x4, x5]

end



function build_cachingOptimizer_model(n_items::Int, nb_bins::Int,
                                      profits::Vector{Float64},
                                      weights::Vector{Float64},
                                      binscap::Vector{Float64})

    coluna_optimizer = CL.ColunaModelOptimizer()

    moi_model = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                      coluna_optimizer)
                                      
    x_vars = Vector{Vector{MOI.VariableIndex}}()
    for j in 1:n_items
        x_vec = MOI.addvariables!(moi_model, nb_bins)
        push!(x_vars, x_vec)
    end

    knap_constrs = MOI.ConstraintIndex[]
    for i in 1:nb_bins
        cf = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([w for w in weights], [x_vars[j][i] for j in 1:n_items]), 0.0)
        constr = MOI.addconstraint!(moi_model, cf, MOI.LessThan(binscap[i]))
        push!(knap_constrs, constr)
        # @show cf
        # @show MOI.LessThan(binscap[i])
    end

    cover_constrs = MOI.ConstraintIndex[]
    for j in 1:n_items
        cf = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0 for i in 1:nb_bins], [x_vars[j][i] for i in 1:nb_bins]), 0.0)
        constr = MOI.addconstraint!(moi_model, cf, MOI.LessThan(1.0))
        push!(cover_constrs, constr)
        # @show cf
    end

    for j in 1:n_items
        for i in 1:nb_bins
            cf = MOI.SingleVariable(x_vars[j][i])
            constr = MOI.addconstraint!(moi_model, cf, MOI.ZeroOne())
            # @show cf
        end
    end

    ### set objective function
    terms = MOI.ScalarAffineTerm{Float64}[]
    for j in 1:n_items
        cost = profits[j]
        for i in 1:nb_bins
            push!(terms, MOI.ScalarAffineTerm(cost, x_vars[j][i]))
        end
    end
    objF = MOI.ScalarAffineFunction(terms, 0.0)
    MOI.set!(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objF)
    MOI.set!(moi_model, MOI.ObjectiveSense(), MOI.MinSense)
    # @show objF
    # readline()

    ## set coluna optimizers
    master_problem = coluna_optimizer.inner.extended_problem.master_problem
    coluna_optimizer.inner.problemidx_optimizer_map[master_problem.prob_ref] = GLPK.Optimizer()
    CL.set_model_optimizers(coluna_optimizer.inner)

    return moi_model

end


function build_bb_coluna_model(n_items::Int, nb_bins::Int,
                               profits::Vector{Float64}, weights::Vector{Float64},
                               binscap::Vector{Float64})

    ### Model constructors
    model = CL.ModelConstructor()
    params = model.params
    callback = model.callback
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    master_problem = extended_problem.master_problem
    model.problemidx_optimizer_map[master_problem.prob_ref] = GLPK.Optimizer()
    CL.set_model_optimizers(model)

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

    return model
end

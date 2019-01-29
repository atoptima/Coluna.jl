
@MOIU.model(ModelForCachingOptimizer,
        (MOI.ZeroOne, MOI.Integer),
        (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan, MOI.Interval),
        (),
        (),
        (MOI.SingleVariable,),
        (MOI.ScalarAffineFunction,),
        (),
        ())

function build_coluna_model(n_items::Int, nb_bins::Int,
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
        constr = CL.MasterConstr(master_problem.counter,
            string("knapConstr_", i), binscap[i], 'L', 'M', 's')
        push!(knap_constrs, constr)
        CL.add_constraint(master_problem, constr; update_moi = true)
    end

    cover_constrs = CL.MasterConstr[]
    for j in 1:n_items
        constr = CL.MasterConstr(master_problem.counter,
            string("CoverCons_", j), 1.0, 'L', 'M', 's')
        push!(cover_constrs, constr)
        CL.add_constraint(master_problem, constr; update_moi = true)
    end

    x_vars = Vector{Vector{CL.MasterVar}}()
    for j in 1:n_items
        x_vec = CL.MasterVar[]
        for i in 1:nb_bins
            x_var = CL.MasterVar(master_problem.counter, string("x(", j, ",", i, ")"),
                profits[j], 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
            push!(x_vec, x_var)
            CL.add_variable(master_problem, x_var, true)
            CL.add_membership(x_var, cover_constrs[j], 1.0; optimizer = master_problem.optimizer)
            CL.add_membership(x_var, knap_constrs[i], weights[j]; optimizer = master_problem.optimizer)
        end
        push!(x_vars, x_vec)
    end

    return model
end

function build_colgen_gap_model_with_moi(nb_jobs::Int, nb_machs::Int, caps::Vector{Float64},
                                         costs::Vector{Vector{Float64}}, weights::Vector{Vector{Float64}})

    coluna_optimizer = CL.ColunaModelOptimizer()
    universal_fallback_model = MOIU.UniversalFallback(ModelForCachingOptimizer{Float64}())
    moi_model = MOIU.CachingOptimizer(universal_fallback_model, coluna_optimizer)

    ## Subproblem variables
    vars = []
    for m in 1:nb_machs
        push!(vars, [MOI.add_variable(moi_model) for j in 1:nb_jobs])
    end

    ## Bounds
    bounds = MOI.ConstraintIndex[]
    for m in 1:nb_machs, j in 1:nb_jobs
        ci = MOI.add_constraint(moi_model, MOI.SingleVariable(vars[m][j]), MOI.ZeroOne())
        MOI.set(moi_model, CL.VariableDantzigWolfeAnnotation(), vars[m][j], m)
    end

    ## Subproblem constrs
    knp_constrs = MOI.ConstraintIndex[]
    for m in 1:nb_machs
        knp_constr = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(weights[m], vars[m]), 0.0), MOI.LessThan(caps[m]))
        MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), knp_constr, m)
        push!(knp_constrs, knp_constr)
    end

    cover_constrs = MOI.ConstraintIndex[]
    for j in 1:nb_jobs
        ci = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0 for m in 1:nb_machs], 
                                                                                          [vars[m][j] for m in 1:nb_machs]), 0.0), MOI.GreaterThan(1.0))
        MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), ci, 0)
        push!(cover_constrs, ci)
    end

    ### set objective function
    all_vars = []
    all_costs = []
    for m in 1:nb_machs
        append!(all_vars, vars[m])
        append!(all_costs, costs[m])
    end
    objF = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(all_costs, all_vars), 0.0)
    MOI.set(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objF)
    MOI.set(moi_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    card_bounds_dict = Dict{Int, Tuple{Int,Int}}()
    for m in 1:nb_machs
        card_bounds_dict[m] = (0,1)
    end
    MOI.set(moi_model, CL.DantzigWolfePricingCardinalityBounds(), card_bounds_dict)

    return moi_model, vars, cover_constrs, knp_constrs
end

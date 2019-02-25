function moi_wrapper()
    test_moi_optimize_and_getters()
    test_moi_copy_optimize_and_getters()
    test_moi_annotations()
    test_root_colgen_with_moi()
end

function test_moi_optimize_and_getters() ## change
    @testset "MOI wrapper: optimize! and getters" begin
        n_items = 4
        nb_bins = 3
        profits = [-10.0, -15.0, -20.0, -50.0]
        weights = [  4.0,   5.0,   6.0,  10.0]
        binscap = [ 10.0,   2.0,  10.0]

        model = build_coluna_model(n_items, nb_bins, profits, weights, binscap)
        coluna_optimizer = CL.Optimizer()

        @test MOI.is_empty(coluna_optimizer) == true
        coluna_optimizer.inner = model
        @test MOI.is_empty(coluna_optimizer) == false
        MOI.empty!(coluna_optimizer)
        @test MOI.is_empty(coluna_optimizer) == true
        coluna_optimizer.inner = model

        MOI.optimize!(coluna_optimizer)

        @test MOI.get(coluna_optimizer, MOI.ObjectiveValue()) == -80.0
        println("Dual bound: ", MOI.get(coluna_optimizer, MOI.ObjectiveBound()))
    end
end

function test_moi_copy_optimize_and_getters()
    @testset "MOI wrapper: copy!, optimize!, and get solution" begin
        ## Create user_model, an MOI.CachingOptimizer object, using coluna as
        ## optimizer.
        n_items = 4
        nb_bins = 3
        profits = [-10.0, -15.0, -20.0, -50.0]
        weights = [  4.0,   5.0,   6.0,  10.0]
        binscap = [ 10.0,  2.0,  10.0]

        # Builds a caching optimizer model using Coluna as solver
        caching_optimizer = build_model_1(n_items, nb_bins, profits,
                                          weights, binscap)
        caching_optimizer.optimizer.inner.params.node_eval_mode = CL.Lp


        MOI.optimize!(caching_optimizer)
        @test MOI.get(caching_optimizer, MOI.ObjectiveValue()) == -80.0

        # Builds a caching optimizer model using Coluna as solver
        caching_optimizer, vars = build_model_2()
        MOI.optimize!(caching_optimizer)
        @test MOI.get(caching_optimizer, MOI.ObjectiveValue()) == 23.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[1]) == 2.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[2]) == 1.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[3]) == 2.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[4]) == 0.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[5]) == 0.0
        sol = MOI.get(caching_optimizer, MOI.VariablePrimal(), vars)
        @test sol == [2.0, 1.0, 2.0, 0.0, 0.0]
    end
end

function test_moi_annotations()
    @testset "MOI wrapper: annotations" begin

        coluna_optimizer = CL.Optimizer()
        universal_fallback_model = MOIU.UniversalFallback(ModelForCachingOptimizer{Float64}())
        moi_model = MOIU.CachingOptimizer(universal_fallback_model, coluna_optimizer)

        # Subproblem variables
        x1 = MOI.add_variable(moi_model)
        MOI.set(moi_model, CL.VariableDantzigWolfeAnnotation(), x1, 1)

        # Subproblem constrs
        knp_constr = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([3.0], [x1]), 0.0), MOI.LessThan(0.0))
        MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), knp_constr, 1)

        # Master constraint
        cov = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0], [x1]), 0.0), MOI.GreaterThan(1.0))
        MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), cov, 0)

        @test MOI.get(moi_model, CL.ConstraintDantzigWolfeAnnotation(), cov) == 0
        @test MOI.get(moi_model, CL.ConstraintDantzigWolfeAnnotation(), knp_constr) == 1
        @test MOI.get(moi_model, CL.VariableDantzigWolfeAnnotation(), x1) == 1
    end
end

function test_root_colgen_with_moi()
    @testset "MOI wrapper: root colgen" begin
        caching_optimizer, vars = build_colgen_root_model_with_moi()
        MOI.optimize!(caching_optimizer)
        @test MOI.get(caching_optimizer, MOI.ObjectiveValue()) == 4.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[1]) == 1.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[2]) == 1.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[3]) == 1.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[4]) == 2.0
        @test MOI.get(caching_optimizer, MOI.VariablePrimal(), vars[5]) == 1.0
    end
end

function build_colgen_root_model_with_moi()

    coluna_optimizer = CL.Optimizer()
    universal_fallback_model = MOIU.UniversalFallback(ModelForCachingOptimizer{Float64}())
    moi_model = MOIU.CachingOptimizer(universal_fallback_model, coluna_optimizer)

    ## Subproblem variables
    x1 = MOI.add_variable(moi_model)
    x2 = MOI.add_variable(moi_model)
    x3 = MOI.add_variable(moi_model)
    y = MOI.add_variable(moi_model)
    z = MOI.add_variable(moi_model)
    sp_vars = [x1, x2, x3, y]
    vars = [x1, x2, x3, y, z]

    ## Bounds
    bounds = MOI.ConstraintIndex[]
    for var in vars
        ci = MOI.add_constraint(moi_model, MOI.SingleVariable(var), MOI.ZeroOne())
        MOI.set(moi_model, CL.VariableDantzigWolfeAnnotation(), var, var in sp_vars ? 1 : 0)
        push!(bounds, ci)
    end
    ci = MOI.add_constraint(moi_model, MOI.SingleVariable(y), MOI.GreaterThan(1.0))
    MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), ci, 1)
    push!(bounds, ci)

    ## Subproblem constrs
    knp_constr = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([3.0, 4.0, 5.0, -8.0], sp_vars), 0.0), MOI.LessThan(0.0))
    MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), knp_constr, 1)

    cover_constr = MOI.ConstraintIndex[]
    for var in [x1, x2, x3]
        ci = MOI.add_constraint(moi_model, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0,], [var,]), 0.0), MOI.GreaterThan(1.0))
        MOI.set(moi_model, CL.ConstraintDantzigWolfeAnnotation(), ci, 0)
        push!(cover_constr, ci)
    end

    ### set objective function
    objF = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, -1.0, 1.0, 1.0, 1.0], [y, z, x1, x2, x3]), 0.0)
    MOI.set(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objF)
    MOI.set(moi_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    card_bounds_dict = Dict(1 => (0,1000))
    MOI.set(moi_model, CL.DantzigWolfePricingCardinalityBounds(), card_bounds_dict)

    return moi_model, vars
end

function build_model_2()

    coluna_optimizer = CL.Optimizer()
    universal_fallback_model = MOIU.UniversalFallback(ModelForCachingOptimizer{Float64}())
    moi_model = MOIU.CachingOptimizer(universal_fallback_model, coluna_optimizer)

    x1 = MOI.add_variable(moi_model)
    x2 = MOI.add_variable(moi_model)
    x3 = MOI.add_variable(moi_model)
    x4 = MOI.add_variable(moi_model)
    x5 = MOI.add_variable(moi_model)

    objF = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([10.0, 1.0, 1.0],
                                                          [x1, x2, x3]), 0.0)
    MOI.set(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objF)
    MOI.set(moi_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    cf1 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0, 1.0],
                                                         [x1, x2, x3]), 0.0)
    constr1 = MOI.add_constraint(moi_model, cf1, MOI.GreaterThan(5.0))

    cf2 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x2, x3]), 0.0)
    constr2 = MOI.add_constraint(moi_model, cf2, MOI.LessThan(3.0))

    constr31 = MOI.add_constraint(moi_model, MOI.SingleVariable(x1), MOI.Integer())
    constr32 = MOI.add_constraint(moi_model, MOI.SingleVariable(x1), MOI.LessThan(2.0))
    constr33 = MOI.add_constraint(moi_model, MOI.SingleVariable(x1), MOI.GreaterThan(1.0))

    constr4 = MOI.add_constraint(moi_model, MOI.SingleVariable(x2), MOI.ZeroOne())
    constr5 = MOI.add_constraint(moi_model, MOI.SingleVariable(x3), MOI.GreaterThan(0.0))

    constr6 = MOI.add_constraint(moi_model, MOI.SingleVariable(x4), MOI.EqualTo(0.0))

    cf7 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x4, x5]), 0.0)
    constr7 = MOI.add_constraint(moi_model, cf7, MOI.EqualTo(0.0))

    return moi_model, [x1, x2, x3, x4, x5]
end

function build_model_1(n_items::Int, nb_bins::Int,
                       profits::Vector{Float64},
                       weights::Vector{Float64},
                       binscap::Vector{Float64})

    coluna_optimizer = CL.Optimizer()
    universal_fallback_model = MOIU.UniversalFallback(ModelForCachingOptimizer{Float64}())
    moi_model = MOIU.CachingOptimizer(universal_fallback_model, coluna_optimizer)

    x_vars = Vector{Vector{MOI.VariableIndex}}()
    for j in 1:n_items
        x_vec = MOI.add_variables(moi_model, nb_bins)
        push!(x_vars, x_vec)
    end

    knap_constrs = MOI.ConstraintIndex[]
    for i in 1:nb_bins
        cf = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([w for w in weights], [x_vars[j][i] for j in 1:n_items]), 0.0)
        constr = MOI.add_constraint(moi_model, cf, MOI.LessThan(binscap[i]))
        push!(knap_constrs, constr)
    end

    cover_constrs = MOI.ConstraintIndex[]
    for j in 1:n_items
        cf = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0 for i in 1:nb_bins], [x_vars[j][i] for i in 1:nb_bins]), 0.0)
        constr = MOI.add_constraint(moi_model, cf, MOI.LessThan(1.0))
        push!(cover_constrs, constr)
    end
    for j in 1:n_items
        for i in 1:nb_bins
            cf = MOI.SingleVariable(x_vars[j][i])
            constr = MOI.add_constraint(moi_model, cf, MOI.ZeroOne())
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
    MOI.set(moi_model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objF)
    MOI.set(moi_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    return moi_model
end

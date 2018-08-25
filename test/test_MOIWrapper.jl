


function simple_MOI_calls_to_ColunaModelOptimizer()
    @testset "Calls to MOI functions using ColunaOptimizer" begin
        n_items = 4
        nb_bins = 3
        profits = [-10.0, -15.0, -20.0, -50.0]
        weights = [  4.0,   5.0,   6.0,  10.0]
        binscap = [ 10.0,  2.0,  10.0]

        model = build_bb_coluna_model(n_items, nb_bins, profits, weights, binscap)
        coluna_optimizer = CL.ColunaModelOptimizer()

        @test MOI.isempty(coluna_optimizer) == true
        coluna_optimizer.inner = model
        @test MOI.isempty(coluna_optimizer) == false
        MOI.empty!(coluna_optimizer)
        @test MOI.isempty(coluna_optimizer) == true
        coluna_optimizer.inner = model

        MOI.optimize!(coluna_optimizer)

        @test MOI.get(coluna_optimizer, MOI.ObjectiveValue()) == -80.0
        println("Dual bound: ", MOI.get(coluna_optimizer, MOI.ObjectiveBound()))

        

    end
end



function tests_with_CachingOptimizer()
    @testset "Copy and optimize models with CachingOptimizer" begin

        ## Create user_model, an MOI.CachingOptimizer object, using coluna as
        ## optimizer.
        n_items = 4
        nb_bins = 3
        profits = [-10.0, -15.0, -20.0, -50.0]
        weights = [  4.0,   5.0,   6.0,  10.0]
        binscap = [ 10.0,  2.0,  10.0]

        # Builds a caching optimizer model using Coluna as solver
        caching_optimizer = build_cachingOptimizer_model(n_items, nb_bins, profits,
                                                         weights, binscap)


        MOI.optimize!(caching_optimizer)
        @test MOI.get(caching_optimizer.optimizer, MOI.ObjectiveValue()) == -80.0


        # Builds a caching optimizer model using Coluna as solver
        caching_optimizer = build_tricky_model()
        MOI.optimize!(caching_optimizer)
        @test MOI.get(caching_optimizer.optimizer, MOI.ObjectiveValue()) == 23.0

    end
end

function reset_parameters_after_optimize_with_moi()
    # Create the formulation:
    # Min  x
    # s.t. x >= 1

    env = Env{ClMP.VarId}(Coluna.Params())
    form = ClMP.create_formulation!(env, ClMP.Original(), obj_sense = ClMP.MinSense)
    ClMP.setvar!(form, "x", ClMP.OriginalVar; cost = 1, lb = 1)
    closefillmode!(ClMP.getcoefmatrix(form))

    algo1 = ClA.MoiOptimize(
        time_limit = 1200,
        silent = false,
        custom_parameters = Dict(
            "it_lim" => 60
        )
    )

    algo2 = ClA.MoiOptimize(
        silent = false,
        custom_parameters = Dict(
            "mip_gap" => 0.03
        )
    )

    optimizer = ClMP.MoiOptimizer(MOI._instantiate_and_check(GLPK.Optimizer))

    get_time_lim() = MOI.get(optimizer.inner, MOI.TimeLimitSec()) 
    get_silent() = MOI.get(optimizer.inner, MOI.Silent())
    get_it_lim() = MOI.get(optimizer.inner, MOI.RawOptimizerAttribute("it_lim")) 
    get_mip_gap() = MOI.get(optimizer.inner, MOI.RawOptimizerAttribute("mip_gap"))

    default_time_lim = get_time_lim()
    default_silent = get_silent()
    default_it_lim = get_it_lim()
    default_mip_gap = get_mip_gap()

    ClA.optimize_with_moi!(optimizer, form, algo1, ClA.OptimizationState(form))

    @test get_time_lim() == default_time_lim
    @test get_silent() == default_silent
    @test get_it_lim() == default_it_lim 
    @test get_mip_gap() == default_mip_gap

    ClA.optimize_with_moi!(optimizer, form, algo2, ClA.OptimizationState(form))

    @test get_time_lim() == default_time_lim
    @test get_silent() == default_silent
    @test get_it_lim() == default_it_lim 
    @test get_mip_gap() == default_mip_gap
    return
end
register!(unit_tests, "subsolvers", reset_parameters_after_optimize_with_moi)
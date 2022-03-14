function model_factory_for_buffer()
    form = ClMP.create_formulation!(Env(Coluna.Params()), ClMP.Original())
    push!(form.optimizers, ClMP.MoiOptimizer(MOI._instantiate_and_check(GLPK.Optimizer)))
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost=2.0, lb=-1.0, ub=1.0, 
        kind=ClMP.Integ, inc_val=4.0
    )
    constr = ClMP.setconstr!(
        form, "constr1", ClMP.MasterBranchOnOrigVarConstr,
        rhs=-13.0
    )
    CL.closefillmode!(ClMP.getcoefmatrix(form))
    return form, var, constr
end

@testset "MathProg - buffer" begin
    @testset "setcurcost! variable" begin
        form, var, constr = model_factory_for_buffer()
        ClMP.setcurcost!(form, var, 3.0)
        ClMP.deactivate!(form, var)
        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
    end

    @testset "setcurkind! variable" begin
        form, var, constr = model_factory_for_buffer()
        ClMP.setcurkind!(form, var, ClMP.Integ)
        ClMP.deactivate!(form, var)
        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
    end


    @testset "setcurlb! variable" begin
        form, var, constr = model_factory_for_buffer()
        ClMP.setcurlb!(form, var, 0.0)
        ClMP.deactivate!(form, var)
        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
    end

    @testset "setcurub! variable" begin
        form, var, constr = model_factory_for_buffer()
        ClMP.setcurub!(form, var, 0.0)
        ClMP.deactivate!(form, var)
        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
    end

    @testset "setcurrhs! constraint" begin
        form, var, constr = model_factory_for_buffer()
        ClMP.setcurrhs!(form, constr, 0.0)
        ClMP.deactivate!(form, constr)
        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, constr) == false
    end

    @testset "set_matrix_coeff!" begin
        form, var, constr = model_factory_for_buffer()
        ClMP.set_matrix_coeff!(form, ClMP.getid(var), ClMP.getid(constr), 2.0)
        ClMP.deactivate!(form, var)
        ClMP.deactivate!(form, constr)
        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
        @test ClMP.iscuractive(form, constr) == false
    end
end
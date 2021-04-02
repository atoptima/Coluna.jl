function buffer_tests()
    form = create_formulation!(Env(Coluna.Params()), Original)
    form.optimizer = MoiOptimizer(MOI._instantiate_and_check(GLPK.Optimizer))
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost=2.0, lb=-1.0, ub=1.0, 
        kind=ClMP.Integ, inc_val=4.0
    )
    constr = ClF.setconstr!(
        form, "constr1", ClF.MasterBranchOnOrigVarConstr,
        rhs=-13.0
    )
    CL.closefillmode!(getcoefmatrix(form))
    
    # var `setcurcost!`
    ClMP.setcurcost!(form, var, 3.0)
    ClMP.deactivate!(form, var)
    ClMP.sync_solver!(getoptimizer(form), form)
    @test ClMP.iscuractive(form, var) == false

    # var `setcurkind!`
    ClMP.reset!(form, var)
    ClMP.setcurkind!(form, var, Integ)
    ClMP.deactivate!(form, var)
    ClMP.sync_solver!(getoptimizer(form), form)
    @test ClMP.iscuractive(form, var) == false
    
    # var `setcurlb!`
    ClMP.reset!(form, var)
    ClMP.setcurlb!(form, var, 0.0)
    ClMP.deactivate!(form, var)
    ClMP.sync_solver!(getoptimizer(form), form)
    @test ClMP.iscuractive(form, var) == false
    
    # var `setcurub!`
    ClMP.reset!(form, var)
    ClMP.setcurub!(form, var, 0.0)
    ClMP.deactivate!(form, var)
    ClMP.sync_solver!(getoptimizer(form), form)
    @test ClMP.iscuractive(form, var) == false

    # constr `setcurrhs!`
    ClMP.reset!(form, constr)
    ClMP.setcurrhs!(form, constr, 0.0)
    ClMP.deactivate!(form, constr)
    ClMP.sync_solver!(getoptimizer(form), form)
    @test ClMP.iscuractive(form, constr) == false
    
    # # `set_matrix_coeff!` TO DO
    # ClMP.reset!(form, var)
    # ClMP.reset!(form, constr)
    # ClMP.set_matrix_coeff!(form, getid(var), getid(constr), 2.0)
    # ClMP.deactivate!(form, var)
    # ClMP.deactivate!(form, constr)
    # ClMP.sync_solver!(getoptimizer(form), form)
    # @test ClMP.iscuractive(form, var) == false
    # @test ClMP.iscuractive(form, constr) == false
end
function model_factory_for_buffer()
    form = ClMP.create_formulation!(Env(Coluna.Params()), ClMP.Original())
    push!(form.optimizers, ClMP.MoiOptimizer(MOI._instantiate_and_check(GLPK.Optimizer)))
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost=2.0, lb=-1.0, ub=1.0, 
        kind=ClMP.Integ, inc_val=4.0
    )
    constr = ClMP.setconstr!(
        form, "constr1", ClMP.MasterBranchOnOrigVarConstr,
        rhs=-13.0, members = Dict(ClMP.getid(var) => 2.0)
    )
    CL.closefillmode!(ClMP.getcoefmatrix(form))
    return form, var, constr
end

function _test_buffer(current::ClMP.FormulationBuffer, expected::ClMP.FormulationBuffer)
    @test isequal(current.changed_obj_sense, expected.changed_obj_sense)
    @test isequal(current.changed_obj_const, expected.changed_obj_const)
    @test isequal(current.changed_cost, expected.changed_cost)
    @test isequal(current.changed_bound, expected.changed_bound)
    @test isequal(current.changed_var_kind, expected.changed_var_kind)
    @test isequal(current.changed_rhs, expected.changed_rhs)
    @test isequal(current.var_buffer, expected.var_buffer)
    @test isequal(current.constr_buffer, expected.constr_buffer)
    @test isequal(current.reset_coeffs, expected.reset_coeffs)
    return
end

@testset "MathProg - buffer" begin
    @testset "model factory - buffer initial state" begin
        form, var, constr = model_factory_for_buffer()
        varid = ClMP.getid(var)
        constrid = ClMP.getid(constr)
        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.changed_obj_sense = false # minimization by default
        expected_buffer.changed_obj_const = false
        expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId}(Set([varid]), Set())
        expected_buffer.constr_buffer = ClMP.VarConstrBuffer{ClMP.ConstrId}(Set([constrid]), Set())
        _test_buffer(form.buffer, expected_buffer)
    end

    @testset "setcurcost! & deactivate variable" begin
        form, var, constr = model_factory_for_buffer()
        varid = ClMP.getid(var)

        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId}(Set([]), Set([varid]))

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        ClMP.setcurcost!(form, var, 3.0)
        ClMP.deactivate!(form, var)

        _test_buffer(form.buffer, expected_buffer)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form) # should not throw any error
        @test ClMP.iscuractive(form, var) == false
        _test_buffer(form.buffer, ClMP.FormulationBuffer()) # empty buffer after sync_solver!        
    end

    @testset "setcurkind! & deactivate variable" begin
        form, var, constr = model_factory_for_buffer()
        varid = ClMP.getid(var)

        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId}(Set([]), Set([varid]))

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        ClMP.setcurkind!(form, var, ClMP.Integ)
        ClMP.deactivate!(form, var)

        _test_buffer(form.buffer, expected_buffer)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form) # should not throw any error
        @test ClMP.iscuractive(form, var) == false
        _test_buffer(form.buffer, ClMP.FormulationBuffer()) # empty buffer after sync_solver!        
    end


    @testset "setcurlb! & deactivate variable" begin
        form, var, constr = model_factory_for_buffer()
        varid = ClMP.getid(var)

        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId}(Set([]), Set([varid]))

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        ClMP.setcurlb!(form, var, 0.0)
        ClMP.deactivate!(form, var)

        _test_buffer(form.buffer, expected_buffer)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
        _test_buffer(form.buffer, ClMP.FormulationBuffer()) # empty buffer after sync_solver!        
    end

    @testset "setcurub! & deactivate variable" begin
        form, var, constr = model_factory_for_buffer()
        varid = ClMP.getid(var)

        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId}(Set([]), Set([varid]))

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        ClMP.setcurub!(form, var, 0.0)
        ClMP.deactivate!(form, var)

        _test_buffer(form.buffer, expected_buffer)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
        _test_buffer(form.buffer, ClMP.FormulationBuffer()) # empty buffer after sync_solver!        
    end

    @testset "setcurrhs! & deactivate constraint" begin
        form, var, constr = model_factory_for_buffer()
        constrid = ClMP.getid(constr)

        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.constr_buffer = ClMP.VarConstrBuffer{ClMP.ConstrId}(Set([]), Set([constrid]))

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        ClMP.setcurrhs!(form, constr, 0.0)
        ClMP.deactivate!(form, constr)

        _test_buffer(form.buffer, expected_buffer)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, constr) == false
        _test_buffer(form.buffer, ClMP.FormulationBuffer()) # empty buffer after sync_solver!        
    end

    @testset "set_matrix_coeff! & deactivate var + constr" begin
        form, var, constr = model_factory_for_buffer()
        varid = ClMP.getid(var)
        constrid = ClMP.getid(constr)

        expected_buffer = ClMP.FormulationBuffer()
        expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId}(Set([]), Set([varid]))
        expected_buffer.constr_buffer = ClMP.VarConstrBuffer{ClMP.ConstrId}(Set([]), Set([constrid]))

        # matrix coefficient change is kept because it's too expensive to propagate
        # variable or column deletion in the matrix coeff buffer
        expected_buffer.reset_coeffs = Dict((constrid => varid) => 2.0)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        ClMP.set_matrix_coeff!(form, ClMP.getid(var), ClMP.getid(constr), 2.0)
        ClMP.deactivate!(form, var)
        ClMP.deactivate!(form, constr)

        _test_buffer(form.buffer, expected_buffer)

        ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
        @test ClMP.iscuractive(form, var) == false
        @test ClMP.iscuractive(form, constr) == false
        _test_buffer(form.buffer, ClMP.FormulationBuffer()) # empty buffer after sync_solver!        
    end

    @testset "remove and add variable" begin
        form, var, constr = model_factory_for_buffer()

        # TODO : test_modification_transform_singlevariable_lessthan
    end
end
function model_factory_for_buffer()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
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
    @test isequal(current.changed_cost, expected.changed_cost)
    @test isequal(current.changed_bound, expected.changed_bound)
    @test isequal(current.changed_var_kind, expected.changed_var_kind)
    @test isequal(current.changed_rhs, expected.changed_rhs)
    @test isequal(current.var_buffer, expected.var_buffer)
    @test isequal(current.constr_buffer, expected.constr_buffer)
    @test isequal(current.reset_coeffs, expected.reset_coeffs)
    return
end

_empty_buffer() = ClMP.FormulationBuffer{ClMP.VarId,ClMP.Variable,ClMP.ConstrId,ClMP.Constraint}()


function model_factory_buffer_initial_state()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)
    constrid = ClMP.getid(constr)
    expected_buffer = _empty_buffer()
    expected_buffer.changed_obj_sense = false # minimization by default
    expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId, ClMP.Variable}()
    expected_buffer.var_buffer.added = Set([varid])
    expected_buffer.constr_buffer = ClMP.VarConstrBuffer{ClMP.ConstrId, ClMP.Constraint}()
    expected_buffer.constr_buffer.added = Set([constrid])
    _test_buffer(form.buffer, expected_buffer)
end
register!(unit_tests, "buffer", model_factory_buffer_initial_state)

function setcurcost!_and_deactivate_variable()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)

    expected_buffer = _empty_buffer()
    expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId, ClMP.Variable}()
    expected_buffer.var_buffer.removed = Set([varid])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurcost!(form, var, 3.0)
    ClMP.deactivate!(form, var)

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form) # should not throw any error
    @test ClMP.iscuractive(form, var) == false
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", setcurcost!_and_deactivate_variable)

function setcurkind!_deactivate_variable()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)

    expected_buffer = _empty_buffer()
    expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId, ClMP.Variable}()
    expected_buffer.var_buffer.removed = Set([varid])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurkind!(form, var, ClMP.Integ)
    ClMP.deactivate!(form, var)

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form) # should not throw any error
    @test ClMP.iscuractive(form, var) == false
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", setcurkind!_deactivate_variable)

function setcurlb!_deactivate_variable()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)

    expected_buffer = _empty_buffer()
    expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId, ClMP.Variable}()
    expected_buffer.var_buffer.removed = Set([varid])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurlb!(form, var, 0.0)
    ClMP.deactivate!(form, var)

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    @test ClMP.iscuractive(form, var) == false
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", setcurlb!_deactivate_variable)

function setcurub!_deactivate_variable()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)

    expected_buffer = _empty_buffer()
    expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId, ClMP.Variable}()
    expected_buffer.var_buffer.removed = Set([varid])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurub!(form, var, 0.0)
    ClMP.deactivate!(form, var)

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    @test ClMP.iscuractive(form, var) == false
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", setcurub!_deactivate_variable)

function setcurrhs!_deactivate_constraint()
    form, var, constr = model_factory_for_buffer()
    constrid = ClMP.getid(constr)

    expected_buffer = _empty_buffer()
    expected_buffer.constr_buffer = ClMP.VarConstrBuffer{ClMP.ConstrId, ClMP.Constraint}()
    expected_buffer.constr_buffer.removed = Set([constrid])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurrhs!(form, constr, 0.0)
    ClMP.deactivate!(form, constr)

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    @test ClMP.iscuractive(form, constr) == false
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", setcurrhs!_deactivate_constraint)

function set_matrix_coeff()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)
    constrid = ClMP.getid(constr)

    expected_buffer = _empty_buffer()
    expected_buffer.reset_coeffs = Dict((constrid => varid) => 5.0)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.getcoefmatrix(form)[ClMP.getid(constr), ClMP.getid(var)] = 5.0
    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    @test ClMP.getcoefmatrix(form)[ClMP.getid(constr), ClMP.getid(var)] == 5.0
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!       
end
register!(unit_tests, "buffer", set_matrix_coeff)

function add_variable_and_set_matrix_coeff()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)
    constrid = ClMP.getid(constr)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    var2 = ClMP.setvar!(
        form, "var2", ClMP.OriginalVar, cost=3.0, lb=-2.0, ub=2.0, 
        kind=ClMP.Integ, inc_val=4.0
    )
    ClMP.getcoefmatrix(form)[ClMP.getid(constr), ClMP.getid(var2)] = 8.0

    expected_buffer = _empty_buffer()
    # change of the matrix is not buffered because it is a new variable and Coluna has
    # to create the whole column in the subsolver.
    expected_buffer.var_buffer.added = Set([ClMP.getid(var2)])

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", add_variable_and_set_matrix_coeff)

function set_matrix_coeff_and_deactivate_var_and_constr()
    form, var, constr = model_factory_for_buffer()
    varid = ClMP.getid(var)
    constrid = ClMP.getid(constr)

    expected_buffer = _empty_buffer()
    expected_buffer.var_buffer = ClMP.VarConstrBuffer{ClMP.VarId, ClMP.Variable}()
    expected_buffer.var_buffer.removed = Set([varid])
    expected_buffer.constr_buffer = ClMP.VarConstrBuffer{ClMP.ConstrId, ClMP.Constraint}()
    expected_buffer.constr_buffer.removed = Set([constrid])

    # matrix coefficient change is kept because it's too expensive to propagate
    # variable or column deletion in the matrix coeff buffer
    expected_buffer.reset_coeffs = Dict((constrid => varid) => 3.0)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.getcoefmatrix(form)[ClMP.getid(constr), ClMP.getid(var)] = 3.0
    ClMP.deactivate!(form, var)
    ClMP.deactivate!(form, constr)

    _test_buffer(form.buffer, expected_buffer)

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    @test ClMP.iscuractive(form, var) == false
    @test ClMP.iscuractive(form, constr) == false
    @test ClMP.getcoefmatrix(form)[ClMP.getid(constr), ClMP.getid(var)] == 3.0
    _test_buffer(form.buffer, _empty_buffer()) # empty buffer after sync_solver!        
end
register!(unit_tests, "buffer", set_matrix_coeff_and_deactivate_var_and_constr)

function change_objective_sense()
    form, var, constr = model_factory_for_buffer()
    
    expected_buffer = _empty_buffer()
    expected_buffer.changed_obj_sense = true

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.set_objective_sense!(form, false) # maximization

    _test_buffer(form.buffer, expected_buffer)
    @test ClMP.getobjsense(form) == ClMP.MaxSense

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    _test_buffer(form.buffer, _empty_buffer())
end
register!(unit_tests, "buffer", change_objective_sense)

function set_peren_lb_and_ub()
    form, var, constr = model_factory_for_buffer()

    expected_buffer = _empty_buffer()
    expected_buffer.changed_bound = Set{ClMP.VarId}([ClMP.getid(var)])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setperenlb!(form, var, 0.0)
    ClMP.setperenub!(form, var, 1.0)

    _test_buffer(form.buffer, expected_buffer)
end
register!(unit_tests, "buffer", set_peren_lb_and_ub)
   
function remove_variable()
    form, var, constr = model_factory_for_buffer()

    expected_buffer = _empty_buffer()
    expected_buffer.var_buffer.removed = Set([ClMP.getid(var)])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurcost!(form, var, 2.0)  # make sure we delete buffered changes
    delete!(form, var)

    _test_buffer(form.buffer, expected_buffer)
    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form) # make sure exception thrown
end
register!(unit_tests, "buffer", remove_variable)

function remove_constraint()
    form, var, constr = model_factory_for_buffer()

    expected_buffer = _empty_buffer()
    expected_buffer.constr_buffer.removed = Set([ClMP.getid(constr)])

    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form)
    ClMP.setcurrhs!(form, constr, 3.0) # make sure we delete buffered changes
    delete!(form, constr)

    #_test_buffer(form.buffer, expected_buffer)
    ClMP.sync_solver!(ClMP.getoptimizer(form, 1), form) # make sure exception thrown
end
register!(unit_tests, "buffer", remove_constraint)

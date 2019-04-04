function create_moi_optimizer(factory::JuMP.OptimizerFactory)
    # optimizer = factory() # Try to use direct mode to be faster
    # readline()
    optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), factory())
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer, MoiObjective(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return optimizer
end

function set_optimizer_obj(moi_optimizer::MOI.AbstractOptimizer,
                           new_obj::VarMemberDict)

    vec = [
        MOI.ScalarAffineTerm(cost, getmoi_index(id))
        for (id, cost) in new_obj
    ]
    objf = MOI.ScalarAffineFunction(vec, 0.0)
    MOI.set(form.moi_optimizer, MoiObjective(), objf)
    return
end

function update_cost_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                  id::Id{VarState})
    state = getstate(id)
    MOI.modify(
        optimizer, MoiObjective(),
        MOI.ScalarCoefficientChange{Float64}(getmoi_index(state), getcost(state))
    )
    return
end

function enforce_bounds_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                     id::Id{VarState})
    # @assert var.moi_def.bounds_index.value == -1 # commented because of primal heur
    state = getstate(id)
    moi_bounds = MOI.add_constraint(
        optimizer, MOI.SingleVariable(getmoi_index(state)),
        MOI.Interval(getlb(state), getub(state))
    )
    setmoibounds(state, moi_bounds)
    return
end

function enforce_var_kind_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                       id::Id{VarState})
    state = getstate(id)
    kind = getkind(state)
    if kind == Binary
        setmoikind(state, MOI.add_constraint(
            optimizer, MOI.SingleVariable(getmoi_index(state)), MOI.ZeroOne()
        ))
    elseif kind == Integ
        setmoikind(state, MOI.add_constraint(
            optimizer, MOI.SingleVariable(getmoi_index(state)), MOI.Integer()
        ))
    elseif kind == Continuous && getmoi_bdconstr(state) != nothing
        moi_bounds = getmoi_bdconstr(state)
        MOI.delete(optimizer, moi_bounds)
        setmoibounds(state, nothing)
        # new_moi_bounds = MOI.ConstraintIndex{MOI.ScalarAffineFunction,
        #                                        constr.set_type}(-1)
    end
    return
end

function add_variable_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                   id::Id{VarState})
    state = getstate(id)
    moi_index = MOI.add_variable(optimizer)
    setmoiindex(state, moi_index)
    update_cost_in_optimizer(optimizer, id)
    enforce_var_kind_in_optimizer(optimizer, id)
    if (getkind(state) != Binary)
        enforce_bounds_in_optimizer(optimizer, id)
    end
    return
end

function compute_moi_terms(membership::VarMemberDict)
    return [
        MOI.ScalarAffineTerm{Float64}(coeff, getmoi_index(getstate(id)))
        for (id, coeff) in membership
    ]
end

function add_constraint_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                     id::Id{ConstrState},
                                     var_membership::VarMemberDict)
    terms = compute_moi_terms(var_membership)
    f = MOI.ScalarAffineFunction(terms, 0.0)
    state = getstate(id)
    setmoi_index!(state, MOI.add_constraint(optimizer, f, getmoi_set(state)))
    return
end

function fill_primal_sol(moi_optimizer::MOI.AbstractOptimizer,
                         sol::VarMemberDict,
                         vars::VarDict)
    for (id,var) in vars
        moi_index = getmoi_index(getstate(id))
        val = MOI.get(moi_optimizer, MOI.VariablePrimal(), moi_index)
        @logmsg LogLevel(-4) string("Var ", getname(var_def[2]), " = ", val)
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            add!(sol, id, val)
        end
    end
    return
end

function fill_dual_sol(moi_optimizer::MOI.AbstractOptimizer,
                       sol::ConstrMemberDict,
                       constrs::ConstrDict)
    for (id, constr) in constrs
        val = 0.0
        moi_index = getmoi_index(getstate(id))
        try # This try is needed because of the erroneous assertion in LQOI
            val = MOI.get(moi_optimizer, MOI.ConstraintDual(), moi_index)
        catch err
            if (typeof(err) == AssertionError &&
                !(err.msg == "dual >= 0.0" || err.msg == "dual <= 0.0"))
                throw(err)
            end
        end
        # @logmsg LogLevel(-4) string("Constr dual ", constr.name, " = ",
        #                             constr.val)
        # @logmsg LogLevel(-4) string("Constr primal ", constr.name, " = ",
        #                             MOI.get(optimizer, MOI.ConstraintPrimal(),
        #                                     constr.moi_index))
        if val > 0.000001 || val < - 0.000001 # todo use a tolerance
            add!(sol, id, val)
        end
    end
    @show sol
    return
end

function call_moi_optimize_with_silence(optimizer::MOI.AbstractOptimizer)
    backup_stdout = stdout
    (rd_out, wr_out) = redirect_stdout()
    MOI.optimize!(optimizer)
    close(wr_out)
    close(rd_out)
    redirect_stdout(backup_stdout)
    return
end

function print_moi_constraints(optimizer::MOI.AbstractOptimizer)
    println("-------------- Printing MOI constraints")
    for (F,S) in MOI.get(optimizer, MOI.ListOfConstraints())
        println("Function type: ", F)
        for ci in MOI.get(optimizer, MOI.ListOfConstraintIndices{F,S}())
            println("Constraint ", ci.value)
        end
    end
    println("------------------------------------------")
end

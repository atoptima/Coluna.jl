function create_moi_optimizer(factory::JuMP.OptimizerFactory)
    # optimizer = factory() # Try to use direct mode to be faster
    # readline()
    optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), factory())
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer, MoiObjective(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return optimizer
end

function compute_moi_terms(membership::VarMemberDict)
    @show membership
    return [
        MOI.ScalarAffineTerm{Float64}(coef, getmoi_index(getstate(id)))
        for (id, coef) in membership
    ]
end

function set_optimizer_obj(moi_optimizer::MOI.AbstractOptimizer,
                           new_obj::VarMemberDict)

    terms = compute_moi_terms(new_obj)
    objf = MOI.ScalarAffineFunction(terms, 0.0)
    MOI.set(moi_optimizer, MoiObjective(), objf)
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

function add_constraint_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                     id::Id{ConstrState},
                                     var_membership::VarMemberDict)

    @show var_membership
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
            sol[id] = val
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
            sol[id] = val
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

function update_optimizer_obj_constant(optimizer::MOI.AbstractOptimizer,
                                       constant::Float64)
    of = MOI.get(optimizer,
                 MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    MOI.modify(
        optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarConstantChange(constant))
end

function remove_var_from_optimizer(optimizer::MOI.AbstractOptimizer,
                                   var_id::Id{VarState})
    state = getstate(var_id)
    @assert state.index != MOI.VariableIndex(-1)
    MOI.delete(optimizer, state.bd_constr_ref)
    state.bd_constr_ref = MoiBounds(-1)
    MOI.delete(optimizer, state.kind_constr_ref)
    state.kind_constr_ref = MoiVarKind(-1)
    MOI.delete(optimizer, state.index)
    state.index = MOI.VariableIndex(-1)
end

function remove_constr_from_optimizer(optimizer::MOI.AbstractOptimizer,
                                      constr_id::Id{ConstrState})

    state = getstate(constr_id)
    @assert state.index != MOI.ConstraintIndex(-1)
    MOI.delete(optimizer, state.index)
    state.index = MOI.ConstraintIndex{MOI.ScalarAffineFunction,
                                      state.set_type}(-1)
    state.set_type = nothing
end

function _show_function(io::IO, moi_model::MOI.ModelLike,
                        func::MOI.ScalarAffineFunction)
    for term in func.terms
        moi_index = term.variable_index
        coeff = term.coefficient
        name = MOI.get(moi_model, MOI.VariableName(), moi_index)
        if name == ""
            name = string("x", moi_index.value)
        end
        print(io, " + ", coeff, name)
    end
    return
end

function _show_function(io::IO, moi_model::MOI.ModelLike,
                        func::MOI.SingleVariable)
    moi_index = func.variable
    name = MOI.get(moi_model, MOI.VariableName(), moi_index)
    if name == ""
        name = string("x", moi_index.value)
    end
    print(io, " + ", name)
    return
end

get_moi_set_info(set::MOI.EqualTo) = ("==", set.value)
get_moi_set_info(set::MOI.GreaterThan) = (">=", set.lower)
get_moi_set_info(set::MOI.LessThan) = ("<=", set.upper)
get_moi_set_info(set::MOI.Integer) = ("is", "Integer")
get_moi_set_info(set::MOI.ZeroOne) = ("is", "Binary")
get_moi_set_info(set::MOI.Interval) = (
    "is bounded in", string("[", set.lower, ";", set.upper, "]")
)

function _show_set(io::IO, moi_model::MOI.ModelLike,
                   set::MOI.AbstractScalarSet)
    op, rhs = get_moi_set_info(set)
    print(io, " ", op, " ", rhs)
    return
end

function _show_constraint(io::IO, moi_model::MOI.ModelLike,
                          moi_index::MOI.ConstraintIndex)
    name = MOI.get(moi_model, MOI.ConstraintName(), moi_index)
    if name == ""
        name = string("constr_", moi_index.value)
    end
    print(io, name, " : ")
    func = MOI.get(moi_model, MOI.ConstraintFunction(), moi_index)
    _show_function(io, moi_model, func)
    set = MOI.get(moi_model, MOI.ConstraintSet(), moi_index)
    _show_set(io, moi_model, set)
    println(io, "")
    return
end

function _show_constraints(io::IO, moi_model::MOI.ModelLike)
    for (F, S) in MOI.get(moi_model, MOI.ListOfConstraints())
        F == MOI.SingleVariable && continue
        for moi_index in MOI.get(moi_model, MOI.ListOfConstraintIndices{F, S}())
            _show_constraint(io, moi_model, moi_index)
        end
    end
    for (F, S) in MOI.get(moi_model, MOI.ListOfConstraints())
        F !== MOI.SingleVariable && continue
        for moi_index in MOI.get(moi_model, MOI.ListOfConstraintIndices{MOI.SingleVariable,S}())
            _show_constraint(io, moi_model, moi_index)
        end
    end
    return
end

function _show_obj_fun(io::IO, moi_model::MOI.ModelLike)
    sense = MOI.get(moi_model, MOI.ObjectiveSense())
    sense == MOI.MIN_SENSE ? print(io, "Min") : print(io, "Max")
    obj = MOI.get(moi_model, MoiObjective())
    _show_function(io, moi_model, obj)
    println(io, "")
    return
end

function Base.show(io::IO, moi_optimizer::MOIU.CachingOptimizer)
    println(io, "MOI Optimizer {", typeof(moi_optimizer), "} = ")
    _show_obj_fun(io, moi_optimizer.model_cache)
    _show_constraints(io, moi_optimizer.model_cache)
    return
end


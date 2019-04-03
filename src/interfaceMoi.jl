function set_optimizer_obj(moi_optimizer::MOI.AbstractOptimizer,
                           new_obj::Membership{VarInfo})

    vec = [MOI.ScalarAffineTerm(cost, getmoiindex(id)) for (id, cost) in new_obj]
    objf = MOI.ScalarAffineFunction(vec, 0.0)
    MOI.set(form.moi_optimizer,
            MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objf)
end

function create_moi_optimizer(factory::JuMP.OptimizerFactory)
    # optimizer = factory() # Try to use direct mode to be faster
    # readline()
    optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), factory())
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return optimizer
end

function update_cost_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                  id::Id{VarInfo},
                                  cost::Float64)
    MOI.modify(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
               MOI.ScalarCoefficientChange{Float64}(getmoiindex(id), cost))
end

function enforce_initial_bounds_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                             id::Id{VarInfo},
                                             lb::Float64,
                                             ub::Float64)
    # @assert var.moi_def.bounds_index.value == -1 # commented because of primal heur
    moi_bounds = MOI.add_constraint(optimizer,
                                    MOI.SingleVariable(),
                                    MOI.Interval(lb, ub) )
    id.info.bd_constr_ref = moi_bounds
end

function enforce_var_kind_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                       id::Id,
                                       kind::VarKind)
    if kind == Binary
        id.info.moi_kind = MOI.add_constraint(
            optimizer, MOI.SingleVariable(getmoiindex(id), MOI.ZeroOne())
        )
    elseif kind == Integ
        id.info.moi_kind = MOI.add_constraint(
            optimizer, MOI.SingleVariable(getmoiindex(id), MOI.Integer())
        )
    end
end

function add_variable_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                   id::Id,
                                   cost::Float64,
                                   lb::Float64,
                                   ub::Float64,
                                   kind::VarKind,
                                   is_relaxed::Bool)
    index = MOI.add_variable(optimizer)
    setmoiindex(id, index)
    update_cost_in_optimizer(optimizer, id, cost)
    !is_relaxed && enforce_var_kind_in_optimizer(optimizer, id)
    if (kind != Binary || is_relaxed)
        enforce_initial_bounds_in_optimizer(optimizer, id, lb, ub)
    end
end

function fill_primal_sol(moi_optimizer::MOI.AbstractOptimizer,
                         sol::Membership{VarInfo},
                         vars::Manager{Id{VarInfo}, Variable})
    for (id,var) in vars
        moi_index = getmoiindex(getinfo(id))
        val = MOI.get(moi_optimizer, MOI.VariablePrimal(), moi_index)
        @logmsg LogLevel(-4) string("Var ", getname(var_def[2]), " = ", val)
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            add!(sol, id, val)
        end
    end
end

function fill_dual_sol(moi_optimizer::MOI.AbstractOptimizer,
                       sol::Membership{ConstrInfo},
                       constr::Manager{Id{ConstrInfo}, Constraint})
    for (id,constr) in constrs
        val = 0.0
        moi_index = getmoiindex(getinfo(id))
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
end

function call_moi_optimize_with_silence(optimizer::MOI.AbstractOptimizer)
    backup_stdout = stdout
    (rd_out, wr_out) = redirect_stdout()
    MOI.optimize!(optimizer)
    close(wr_out)
    close(rd_out)
    redirect_stdout(backup_stdout)
end

#==
function compute_constr_terms(membership::Membership{VarInfo})
    active = true
    return [
        MOI.ScalarAffineTerm{Float64}(var_val, var_index)
        for (var_val, var_index) in extract_terms(membership,active)
    ]
end


function add_constr_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                 constr::Constraint,
                                 var_membership::Membership{VarInfo},
                                 rhs::Float64)
    terms = compute_constr_terms(var_membership)
    f = MOI.ScalarAffineFunction(terms, 0.0)
    constr.index = MOI.add_constraint(
        optimizer, f, constr.set_type(rhs)
    )
end
==#

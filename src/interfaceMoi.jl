function set_optimizer_obj(form::Formulation,
                           new_obj::Dict{VarId, Float64}) 

    vec = [MOI.ScalarAffineTerm(cost, form.map_var_uid_to_index[var_uid]) for (var_uid, cost) in new_obj]
    objf = MOI.ScalarAffineFunction(vec, 0.0)
    MOI.set(form.moi_optimizer,
            MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), objf)
end

function initialize_formulation_optimizer(form::Formulation)
    optimizer = MOI.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                           optimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    form.moi_optimizer = optimizer
end

function update_cost_in_optimizer(form::Formulation,
                                  var_uid::VarId,
                                  cost::Float64)
    MOI.modify(form.moi_optimizer,
               MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
               MOI.ScalarCoefficientChange{Float64}(form.map_var_uid_to_index[var_uid], cost))
end

function enforce_initial_bounds_in_optimizer(form::Formulation,
                                             var_uid::VarId,
                                             lb::Float64,
                                             ub::Float64)
    # @assert var.moi_def.bounds_index.value == -1 # commented because of primal heur
    var_bounds[var_uid] = MOI.add_constraint(
        form.moi_optimizer,
        MOI.SingleVariable(form.map_var_uid_to_index[var_uid]),
        MOI.Interval(lb, ub))
end

function enforce_var_kind_in_optimizer(form::Formulation,
                                   var_uid::VarId,
                                   kind::Char)
    if kind == 'B'
         var_kinds[var_uid]  = MOI.add_constraint(
            optimizer, MOI.SingleVariable(form.map_var_uid_to_index[var_uid]), MOI.ZeroOne())
    elseif kind == 'I'
        var_kinds[var_uid] = MOI.add_constraint(
            optimizer, MOI.SingleVariable(form.map_var_uid_to_index[var_uid]), MOI.Integer())
    end
end

function add_variable_in_optimizer(form::Formulation,
                                   var_uid::VarId,
                                   cost::Float64,
                                   lb::Float64,
                                   ub::Float64,
                                   kind::Char,
                                   is_relaxed::Bool)
    index = MOI.add_variable(form.moi_optimizer)
    map_index_to_var_uid[index] = var_uid
    map_var_uid_to_index[var_uid] = index
    update_cost_in_optimizer(form.moi_optimizer, var_uid, cost)
    !is_relaxed && enforce_var_kind_in_optimizer(form.moi_optimizer, var_uid)
    if (kind != 'B' || is_relaxed)
        enforce_initial_bounds_in_optimizer(form.moi_optimizer, var_uid, lb, ub)
    end
end

function fill_primal_sol(form::Formulation,
                         membership::VarMembership,
                         var_list::Vector{VarId})
    for var_uid in var_list
        val = MOI.get(form.moi_optimizer, MOI.VariablePrimal(),
                      form.map_var_uid_to_index[var_uid])
        @logmsg LogLevel(-4) string("Var ", getname(form.vars[var_uid]), " = ", val)
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            add!(membership, var_uid, val)
        end
    end
end

function fill_dual_sol(form::Formulation,
                         membership::ConstrMembership,
                         constr_list::Vector{ConstrId})
    for constr_uid in constr_list
        val = 0.0
        try # This try is needed because of the erroneous assertion in LQOI
            val = MOI.get(form.moi_optimizer, MOI.ConstraintDual(),
                          form.map_constr_uid_to_index[constr_uid])
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
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            add!(membership, constr_uid, val)
        end
    end
end

function retrieve_primal_sol(form::Formulation)
    new_sol = VarMembership()
    new_obj_val = MOI.get(form.moi_optimizer, MOI.ObjectiveValue())
    #error("Following line does not work.")
    fill_primal_sol(form, new_sol, get_var_uids(form, _active_))
    primal_sol = PrimalSolution(new_obj_val, new_sol)
    @logmsg LogLevel(-4) string("Objective value: ", new_obj_val)
    return primal_sol
end

function retrieve_dual_sol(form::Formulation)
    # TODO check if supported by solver
    if MOI.get(form.moi_optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
        return nothing
    end
    new_sol = ConstrMembership()
    problem.obj_bound = MOI.get(optimizer, MOI.ObjectiveBound())
    fill_dual_sol(form, new_sol, get_constr_uids(form, _active_))
    dual_sol = DualSolution(-Inf, new_sol)
    return dual_sol
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
function compute_constr_terms(membership::VarMembership)
    active = true
    return [
        MOI.ScalarAffineTerm{Float64}(var_val, var_index)
        for (var_val, var_index) in extract_terms(membership,active)
    ]
end


function add_constr_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                 constr::Constraint,
                                 var_membership::VarMembership,
                                 rhs::Float64)
    terms = compute_constr_terms(var_membership)
    f = MOI.ScalarAffineFunction(terms, 0.0)
    constr.index = MOI.add_constraint(
        optimizer, f, constr.set_type(rhs)
    )
end
==#

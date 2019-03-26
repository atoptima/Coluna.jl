
function set_optimizer_obj(form::Formulation,
                           new_obj::Dict{VarId, Float64}) 

    vec = [MOI.ScalarAffineTerm(cost, form.map_var_uid_to_index[var_uid]) for (var_uid, cost) in new_obj]
    objf = MOI.ScalarAffineFunction(vec, 0.0)
    MOI.set(form.moi_optimizer,
            MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(), objf)
end


function initialize_formulation_optimizer(form::Formulation)
    optimizer = MOIU.MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                           optimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    form.moi_optimizer = optimizer
end


function update_cost_in_optimizer(form::Formulation,
                                  var_uid::VarId,
                                  cost::Float64)
    MOI.modify(form.moi_optimizer,
               MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
               MOI.ScalarCoefficientChange{Float}(form.map_var_uid_to_index[var_uid], cost))
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

function enforce_type_in_optimizer(form::Formulation,
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
    !is_relaxed && enforce_type_in_optimizer(form.moi_optimizer, var_uid)
    if (kind != 'B' || is_relaxed)
        enforce_initial_bounds_in_optimizer(form.moi_optimizer, var_uid, lb, ub)
    end
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

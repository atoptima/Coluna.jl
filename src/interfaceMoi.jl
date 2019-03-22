function initialize_formulation_optimizer(form::Formulation,
                                      optimizer::MOI.AbstractOptimizer)
    optimizer = MOIU.MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                           optimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    form.moi_optimizer = optimizer
end


function update_cost_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                  var::Variable,
                                  cost::Float64)
    MOI.modify(optimizer,
               MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
               MOI.ScalarCoefficientChange{Float}(var.index, cost))
end



function enforce_initial_bounds_in_optimizer(
    optimizer::MOI.AbstractOptimizer,
    var::Variable,
    lb::Float64,
    ub::Float64)
    # @assert var.moi_def.bounds_index.value == -1 # commented because of primal heur
    var.bounds_index = MOI.add_constraint(
        optimizer,
        MOI.SingleVariable(var_index),
        MOI.Interval(lb, ub))
end

function enforce_type_in_optimizer(
    optimizer::MOI.AbstractOptimizer, var::Variable,
                                   vc_type::Char)
    if vc_type == 'B'
        var.type_index = MOI.add_constraint(
            optimizer, MOI.SingleVariable(var.moi_def.var_index), MOI.ZeroOne())
    elseif vc_type == 'I'
        var.type_index = MOI.add_constraint(
            optimizer, MOI.SingleVariable(var.moi_def.var_index), MOI.Integer())
    end
end

function add_variable_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                   var::Variable,
                                   cost::Float64,
                                   lb::Float64,
                                   ub::Float64,
                                   vc_type::Char,
                                   is_relaxed::Bool)
    var.index = MOI.add_variable(optimizer)
    update_cost_in_optimizer(optimizer, var, cost)
    !is_relaxed && enforce_type_in_optimizer(optimizer, var)
    if (vc_type != 'B' || is_relaxed)
        enforce_initial_bounds_in_optimizer(optimizer, var, lb, ub)
    end
end

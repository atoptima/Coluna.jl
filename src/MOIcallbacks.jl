############################################################################################
# Set callbacks
############################################################################################
function MOI.set(model::Coluna.Optimizer, attr::MOI.UserCutCallback, callback_function)
    orig_form = get_original_formulation(model.inner)
    _register_callback!(orig_form, attr, callback_function)
    return
end

function MOI.set(model::Coluna.Optimizer, attr::MOI.LazyConstraintCallback, callback_function)
    orig_form = get_original_formulation(model.inner)
    _register_callback!(orig_form, attr, callback_function)
    return
end

############################################################################################
#  Pricing Callback                                                                        #
############################################################################################
function MOI.submit(
    model::Optimizer,
    cb::BD.PricingSolution{MathProg.PricingCallbackData},
    cost::Float64,
    variables::Vector{MOI.VariableIndex},
    values::Vector{Float64},
    custom_data::Union{Nothing, BD.AbstractCustomData} = nothing
)
    form = cb.callback_data.form
    solval = cost
    colunavarids = [_get_orig_varid_in_form(model, form, v) for v in variables]

    # setup variable
    setup_var_id = form.duty_data.setup_var
    push!(colunavarids, setup_var_id)
    push!(values, 1.0)
    solval += getcurcost(form, setup_var_id)

    sol = PrimalSolution(
        form, colunavarids, values, solval, FEASIBLE_SOL; 
        custom_data = custom_data
    )
    push!(cb.callback_data.primal_solutions, sol)
    return
end

function MOI.get(model::Optimizer, spid::BD.PricingSubproblemId{MathProg.PricingCallbackData})
    callback_data = spid.callback_data
    uid = getuid(callback_data.form)
    axis_index_value = model.annotations.ann_per_form[uid].axis_index_value
    return axis_index_value
end

function MOI.get(
    model::Optimizer, pvc::BD.PricingVariableCost{MathProg.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    form = pvc.callback_data.form
    return getcurcost(form, _get_orig_varid(model, x))
end

function MOI.get(
    model::Optimizer, pvlb::BD.PricingVariableLowerBound{MathProg.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    form = pvlb.callback_data.form
    return getcurlb(form, _get_orig_varid(model, x))
end

function MOI.get(
    model::Optimizer, pvub::BD.PricingVariableUpperBound{MathProg.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    form = pvub.callback_data.form
    return getcurub(form, _get_orig_varid(model, x))
end

############################################################################################
#  Robust Constraints Callback                                                             #
############################################################################################
function _register_callback!(form::Formulation, attr::MOI.UserCutCallback, sep::Function)
    set_robust_constr_generator!(form, Facultative, sep)
    return
end

function _register_callback!(form::Formulation, attr::MOI.LazyConstraintCallback, sep::Function)
    set_robust_constr_generator!(form, Essential, sep)
    return
end

function MOI.get(
    model::Optimizer, cvp::MOI.CallbackVariablePrimal{Algorithm.RobustCutCallbackContext},
    x::MOI.VariableIndex
)
    form = cvp.callback_data.form
    return get(cvp.callback_data.proj_sol_dict, _get_orig_varid(model, x), 0.0)
end

function MOI.submit(
    model::Optimizer, 
    cb::Union{MOI.UserCut{Algorithm.RobustCutCallbackContext}, MOI.LazyConstraint{Algorithm.RobustCutCallbackContext}},
    func::MOI.ScalarAffineFunction{Float64},
    set::Union{MOI.LessThan{Float64}, MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}},
    custom_data::Union{Nothing, BD.AbstractCustomData} = nothing
)
    form = cb.callback_data.form
    rhs = MathProg.convert_moi_rhs_to_coluna(set)
    sense = MathProg.convert_moi_sense_to_coluna(set)
    lhs = 0.0
    members = Dict{VarId, Float64}()
    for term in func.terms
        varid = _get_orig_varid_in_form(model, form, term.variable_index)
        members[varid] = term.coefficient
        lhs += term.coefficient * get(cb.callback_data.proj_sol_dict, varid, 0.0)
    end

    constr = setconstr!(
        form, "", MasterUserCutConstr;
        rhs = rhs,
        kind = cb.callback_data.constrkind,
        sense = sense,
        members = members,
        loc_art_var_abs_cost = cb.callback_data.env.params.local_art_var_cost,
        custom_data = custom_data
    )

    gap = lhs - rhs
    if sense == Less
        push!(cb.callback_data.viol_vals, max(0.0, gap))
    elseif sense == Greater
        push!(cb.callback_data.viol_vals, -min(0.0, gap))
    else
        push!(cb.callback_data.viol_vals, abs(gap))
    end
    return getid(constr)
end

MOI.supports(::Optimizer, ::MOI.UserCutCallback) = true
MOI.supports(::Optimizer, ::MOI.LazyConstraintCallback) = true

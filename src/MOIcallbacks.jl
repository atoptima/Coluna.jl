function MOI.submit(
    model::Optimizer,
    cb::BD.PricingSolution{MP.PricingCallbackData},
    cost::Float64,
    variables::Vector{MOI.VariableIndex},
    values::Vector{Float64}
)
    form = cb.callback_data.form 
    S = getobjsense(form)
    result = OptimizationResult(form)
    solval = cost

    colunavarids = [_get_orig_varid_in_form(model, form, v) for v in variables]

    # setup variable
    setup_var_id = [id for (id,v) in Iterators.filter(
        v -> (iscuractive(form, v.first) && iscurexplicit(form, v.first) && getduty(v.first) <= DwSpSetupVar),
        getvars(form)
    )][1]
    push!(colunavarids, setup_var_id)
    push!(values, 1.0)
    solval += getcurcost(form, setup_var_id)

    add_ip_primal_sol!(result, PrimalSolution(form, colunavarids, values, solval))
    setfeasibilitystatus!(result, FEASIBLE)
    setterminationstatus!(result, OPTIMAL)
    cb.callback_data.result = result
    return
end

function MOI.get(model::Optimizer, spid::BD.PricingSubproblemId{MP.PricingCallbackData})
    callback_data = spid.callback_data
    uid = getuid(callback_data.form)
    axis_index_value = model.annotations.ann_per_form[uid].axis_index_value
    return axis_index_value
end

function MOI.get(
    model::Optimizer, pvc::BD.PricingVariableCost{MP.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    form = pvc.callback_data.form
    return getcurcost(form, _get_orig_varid(model, x))
end

function MOI.get(
    model::Optimizer, pvlb::BD.PricingVariableLowerBound{MP.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    form = pvlb.callback_data.form
    return getcurlb(form, _get_orig_varid(model, x))
end

function MOI.get(
    model::Optimizer, pvub::BD.PricingVariableUpperBound{MP.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    form = pvub.callback_data.form
    return getcurub(form, _get_orig_varid(model, x))
end
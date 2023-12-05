############################################################################################
# Set callbacks
############################################################################################
function MOI.set(model::Coluna.Optimizer, attr::MOI.UserCutCallback, callback_function)
    model.has_usercut_cb = true
    orig_form = get_original_formulation(model.inner)
    _register_callback!(orig_form, attr, callback_function)
    return
end

function MOI.set(model::Coluna.Optimizer, attr::MOI.LazyConstraintCallback, callback_function)
    model.has_lazyconstraint_cb = true
    orig_form = get_original_formulation(model.inner)
    _register_callback!(orig_form, attr, callback_function)
    return
end

function MOI.set(model::Coluna.Optimizer, ::BD.PricingCallback, ::Nothing)
    model.has_pricing_cb = true
    # We register the pricing callback through the annotations.
    return
end

function MOI.set(model::Coluna.Optimizer, ::BD.InitialColumnsCallback, callback_function::Function)
    model.has_initialcol_cb = true
    problem = model.inner
    MathProg._register_initcols_callback!(problem, callback_function)
    return
end

############################################################################################
#  Pricing Callback                                                                        #
############################################################################################
function _submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
    form = cbdata.form
    solval = cost
    colunavarids = Coluna.MathProg.VarId[
        _get_varid_of_origvar_in_form(env, form, v) for v in variables
    ]

    # setup variable
    setup_var_id = form.duty_data.setup_var
    if !isnothing(setup_var_id)
        push!(colunavarids, setup_var_id)
        push!(values, 1.0)
        solval += getcurcost(form, setup_var_id)
    end

    if !isnothing(solval)
        sol = PrimalSolution(
            form, colunavarids, values, solval, FEASIBLE_SOL; 
            custom_data = custom_data
        )
        push!(cbdata.primal_solutions, sol)
    end
    return
end

function MOI.submit(
    model::Optimizer,
    cb::BD.PricingSolution{MathProg.PricingCallbackData},
    cost::Float64,
    variables::Vector{MOI.VariableIndex},
    values::Vector{Float64},
    custom_data::Union{Nothing, BD.AbstractCustomVarData} = nothing
)
    return _submit_pricing_solution(model.env, cb.callback_data, cost, variables, values, custom_data)
end

function _submit_dual_bound(cbdata, bound)
    setup_var_cur_cost = if !isnothing(cbdata.form.duty_data.setup_var)
        getcurcost(cbdata.form, cbdata.form.duty_data.setup_var)
    else
        0
    end

    if !isnothing(bound)
        cbdata.dual_bound = bound + setup_var_cur_cost
    else
        cbdata.dual_bound = nothing
    end

    cbdata.nb_times_dual_bound_set += 1
    return
end

function MOI.submit(
    ::Optimizer,
    cb::BD.PricingDualBound{MathProg.PricingCallbackData},
    bound
)
    return _submit_dual_bound(cb.callback_data, bound)
end

function MOI.get(model::Optimizer, spid::BD.PricingSubproblemId{MathProg.PricingCallbackData})
    callback_data = spid.callback_data
    uid = getuid(callback_data.form)
    axis_index_value = model.annotations.ann_per_form[uid].axis_index_value
    return axis_index_value
end

function _get_pricing_var_cost(env::Env, cbdata, x)
    form = cbdata.form
    return getcurcost(form, _get_orig_varid(env, x))
end

function MOI.get(
    model::Optimizer, pvc::BD.PricingVariableCost{MathProg.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    return _get_pricing_var_cost(model.env, pvc.callback_data, x)
end

function _get_pricing_var_lb(env::Env, cbdata, x)
    form = cbdata.form
    return  getcurlb(form, _get_orig_varid(env, x))
end

function MOI.get(
    model::Optimizer, pvlb::BD.PricingVariableLowerBound{MathProg.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    return _get_pricing_var_lb(model.env, pvlb.callback_data, x)
end

function _get_pricing_var_ub(env::Env, cbdata, x)
    form = cbdata.form
    return getcurub(form, _get_orig_varid(env, x))
end

function MOI.get(
    model::Optimizer, pvub::BD.PricingVariableUpperBound{MathProg.PricingCallbackData}, 
    x::MOI.VariableIndex
)
    return _get_pricing_var_ub(model.env, pvub.callback_data, x)
end

############################################################################################
#  Robust Constraints Callback                                                             #
############################################################################################
function _register_callback!(form::Formulation, ::MOI.UserCutCallback, sep::Function)
    set_robust_constr_generator!(form, Facultative, sep)
    return
end

function _register_callback!(form::Formulation, ::MOI.LazyConstraintCallback, sep::Function)
    set_robust_constr_generator!(form, Essential, sep)
    return
end

function MOI.get(
    model::Optimizer, cvp::MOI.CallbackVariablePrimal{Algorithm.RobustCutCallbackContext},
    x::MOI.VariableIndex
)
    return get(cvp.callback_data.proj_sol_dict, _get_orig_varid(model.env, x), 0.0)
end

function MOI.submit(
    model::Optimizer, 
    cb::Union{MOI.UserCut{Algorithm.RobustCutCallbackContext}, MOI.LazyConstraint{Algorithm.RobustCutCallbackContext}},
    func::MOI.ScalarAffineFunction{Float64},
    set::Union{MOI.LessThan{Float64}, MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}},
    custom_data::Union{Nothing, BD.AbstractCustomConstrData} = nothing
)
    form = cb.callback_data.form
    rhs = MathProg.convert_moi_rhs_to_coluna(set)
    sense = MathProg.convert_moi_sense_to_coluna(set)
    lhs = 0.0
    members = Dict{VarId, Float64}()

    # Robust terms
    for term in func.terms
        varid = _get_varid_of_origvar_in_form(model.env, form, term.variable)
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

    # Non-robust terms
    for (varid, var) in getvars(form)
        if !isnothing(var.custom_data)
            lhs += MathProg.computecoeff(var.custom_data, custom_data)
        end
    end

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

############################################################################################
#  Initial columns Callback                                                                        #
############################################################################################
function _submit_initial_solution(env, cbdata, variables, values, custom_data)
    @assert length(variables) == length(values)
    form = cbdata.form
    colunavarids = [_get_varid_of_origvar_in_form(env, form, v) for v in variables]
    cost = sum(value * getperencost(form, varid) for (varid, value) in Iterators.zip(colunavarids, values))
    return _submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
end

function MOI.submit(
    model::Optimizer,
    cb::BD.InitialColumn{MathProg.InitialColumnsCallbackData},
    variables::Vector{MOI.VariableIndex},
    values::Vector{Float64},
    custom_data::Union{Nothing, BD.AbstractCustomVarData} = nothing
)
    return _submit_initial_solution(model.env, cb.callback_data, variables, values, custom_data)
end

function MOI.get(model::Optimizer, spid::BD.PricingSubproblemId{MathProg.InitialColumnsCallbackData})
    callback_data = spid.callback_data
    uid = getuid(callback_data.form)
    axis_index_value = model.annotations.ann_per_form[uid].axis_index_value
    return axis_index_value
end
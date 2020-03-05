function MOI.submit(
    model::Optimizer,
    cb::BD.PricingSolution{MP.OracleData},
    cost::Float64,
    variables::Vector{MOI.VariableIndex},
    values::Vector{Float64}
)
    form = cb.oracle_data.form 
    S = getobjsense(form)
    result = OptimizationResult{S}()
    pb = PrimalBound(form, cost)
    result.primal_bound = pb

    colunavarids = [model.varmap[var] for var in variables]

    # setup variable
    setup_var_id = [id for (id,v) in Iterators.filter(
        v -> (iscuractive(form, v.first) && iscurexplicit(form, v.first) && getduty(v.first) <= DwSpSetupVar),
        getvars(form)
    )][1]
    push!(colunavarids, setup_var_id)
    push!(values, 1.0)
        
    push!(result.primal_sols, PrimalSolution(form, colunavarids, values, pb))
    setfeasibilitystatus!(result, FEASIBLE)
    setterminationstatus!(result, OPTIMAL)
    cb.oracle_data.result = result
    return
end

function MOI.get(model::Optimizer, spid::BD.OracleSubproblemId{MP.OracleData})
    oracle_data = spid.oracle_data
    uid = getuid(oracle_data.form)
    axis_index_value = model.annotations.ann_per_form[uid].axis_index_value
    return axis_index_value
end

function MOI.get(
    model::Optimizer, vc::BD.OracleVariableCost{MP.OracleData}, 
    x::MOI.VariableIndex
)
    oracle_data = vc.oracle_data
    form = oracle_data.form
    varid = model.varmap[x]
    return getcurcost(form, varid)
end

function MOI.get(
    model::Optimizer, vc::BD.OracleVariableLowerBound{MP.OracleData}, 
    x::MOI.VariableIndex
)
    oracle_data = vc.oracle_data
    form = oracle_data.form
    varid = model.varmap[x]
    return getcurlb(form, varid)
end

function MOI.get(
    model::Optimizer, vc::BD.OracleVariableUpperBound{MP.OracleData}, 
    x::MOI.VariableIndex
)
    oracle_data = vc.oracle_data
    form = oracle_data.form
    varid = model.varmap[x]
    return getcurub(form, varid)
end
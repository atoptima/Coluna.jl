function MOI.submit(
    model::Optimizer,
    cb::BD.PricingSolution{MP.OracleData},
    variables::Vector{MOI.VariableIndex},
    values::Vector{Float64}
)
    @show variables
    @show values
end

function MOI.get(model::Optimizer, spid::BD.OracleSubproblemId{MP.OracleData})
    oracle_data = spid.oracle_data
    uid = getuid(oracle_data.form)
    return uid
end

function MOI.get(
    model::Optimizer, vc::BD.OracleVariableCost{MP.OracleData}, 
    x::MOI.VariableIndex
)
    # TODO
    return 0.0
end
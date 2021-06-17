mutable struct ColumnInfo
    lambda_val::Float64
    x_vals::Dict{MOI.VariableIndex, Float64}
end

function getsolutions(model::Optimizer, k)
    solutions = Vector{ColumnInfo}()
    for (varid, val) in get_ip_primal_sols(model.result[2])[k]
        if getduty(varid) <= MasterCol
            origin_form_uid = getoriginformuid(varid)
            spform = get_dw_pricing_sps(model.inner.re_formulation)[origin_form_uid]
            x_vals = Dict{MOI.VariableIndex, Float64}()
            for (repid, repval) in @view getprimalsolmatrix(spform)[:, varid]
                if getduty(repid) <= DwSpPricingVar
                    x_vals[model.moi_varids[repid]] = repval * val
                end
            end
            push!(solutions, ColumnInfo(val, x_vals))
        end
    end
    return solutions
end

value(column_info::ColumnInfo) = column_info.lambda_val

function value(column_info::ColumnInfo, index::MOI.VariableIndex)
    haskey(column_info.x_vals, index) && return column_info.x_vals[index]
    return 0
end

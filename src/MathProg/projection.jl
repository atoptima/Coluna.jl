projection_is_possible(master::Formulation{DwMaster}) = true
function proj_cols_on_rep(sol::PrimalSolution, master::Formulation{DwMaster})
    projected_sol_vars = Vector{VarId}()
    projected_sol_vals = Vector{Float64}()

    for (varid, val) in sol
        duty = getduty(varid)
        if duty <= MasterPureVar
            push!(projected_sol_vars, varid)
            push!(projected_sol_vals, val)
        elseif duty <= MasterCol
            origin_form_uid = getoriginformuid(varid)
            spform = get_dw_pricing_sps(master.parent_formulation)[origin_form_uid]
            col = getprimalsolmatrix(spform)[:, varid]
            for (repid, repval) in col
                if getduty(repid) <= DwSpPricingVar || getduty(repid) <= DwSpSetupVar
                    push!(projected_sol_vars, repid)
                    push!(projected_sol_vals, repval * val)
                end
            end
        end
    end
    return PrimalSolution(master, projected_sol_vars, projected_sol_vals, getvalue(sol))
end

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution, master::Formulation{BendersMaster})
    return sol
end

projection_is_possible(master::Formulation{DwMaster}) = true

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{DwMaster}) where {Sense}
    projected_sol = Dict{VarId, Float64}()
    for (mc_id, mc_val) in sol
        origin_form_uid = getoriginformuid(mc_id)
        # TODO : enhance following
        spform = master 
        if origin_form_uid != 0 && origin_form_uid != 1 # if id = 1 this is the master
            spform = get_dw_pricing_sps(master.parent_formulation)[origin_form_uid]
        end
        # END TODO
        col = getprimalsolmatrix(spform)[:, mc_id]
        for (repid, repval) in col
            if getduty(repid) <= DwSpPricingVar || getduty(repid) <= DwSpSetupVar
                projected_sol[repid] = (get!(projected_sol, repid, 0.0)) + repval * mc_val
            end
        end        
    end
    return PrimalSolution(master, projected_sol, float(getbound(sol)))
end

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{BendersMaster}) where {Sense}
    return sol
end

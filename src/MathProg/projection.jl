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
<<<<<<< HEAD
        for (rep_id, rep_val) in col
            if getduty(rep_id) <= DwSpPricingVar || getduty(rep_id) <= DwSpSetupVar
                projected_sol[rep_id] = (get!(projected_sol, rep_id, 0.0)) + rep_val * mc_val
            end
        end        
=======
        for (rep_id, rep_val) in Iterators.filter(
            v -> getduty(v) <= DwSpPricingVar || getduty(v) <= DwSpSetupVar,
            col)
            projected_sol[rep_id] = (get!(projected_sol, rep_id, 0.0)) + rep_val * mc_val
        end
>>>>>>> master
    end
    return PrimalSolution(master, projected_sol, float(getbound(sol)))
end

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{BendersMaster}) where {Sense}
    return sol
end

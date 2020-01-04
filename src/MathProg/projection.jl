projection_is_possible(master::Formulation{DwMaster}) = true

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{DwMaster}) where {Sense}
    projected_sol = Dict{VarId, Float64}()
    for (mc_id, mc_val) in sol
        origin_form_uid = getoriginformuid(mc_id)
        @show mc_id
        @show origin_form_uid
        # TODO : enhance following
        spform = master 
        if origin_form_uid != 1
            spform = get_dw_pricing_sps(master.parent_formulation)[origin_form_uid]
        end
        # END TODO
        col = getprimalsolmatrix(spform)[:, mc_id]
        for (rep_id, rep_val) in Iterators.filter(_sp_var_rep_in_orig_, col)
            projected_sol[rep_id] = (get!(projected_sol, rep_id, 0.0)) + rep_val * mc_val
        end
    end
    return PrimalSolution(master, projected_sol, float(getbound(sol)))
end

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{BendersMaster}) where {Sense}
    return sol
end

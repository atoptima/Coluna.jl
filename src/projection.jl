projection_is_possible(master::Formulation{DwMaster}) = true

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{DwMaster}) where {Sense}
    projected_sol = Dict{VarId, Float64}()

    for (mc_id, mc_val) in sol
        origin_form_uid = getformuid(mc_id)
        spform = get_dw_pricing_sps(master)[origin_form_uid]
        for (rep_id, rep_val) in Iterators.filter(
                _rep_of_orig_var_, getprimalsolmatrix(spform)[:, mc_id]
            )
            projected_sol[rep_id] = (get!(projected_sol, rep_id, 0.0)) + rep_val * mc_val
        end
    end

    # TODO : add pure master variables

    return PrimalSolution(master, float(getbound(sol)), projected_sol)
end

projection_is_possible(master::Formulation{BendersMaster}) = false

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{BendersMaster}) where {Sense}
    return sol
end

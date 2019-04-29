function proj_cols_on_rep(sol::PrimalSolution{S}, master::Formulation) where {S}
    projected_sol = Dict{VarId, Float64}()
    partialsolmatrix = getpartialsolmatrix(master)
    for (mc_id, mc_val) in sol
        for (rep_id, rep_val) in partialsolmatrix[:, mc_id]
            projected_sol[rep_id] = (get!(projected_sol, rep_id, 0.0) + rep_val) * mc_val
        end
    end

    # TODO : add pure master variables

    return PrimalSolution(master, float(getbound(sol)), projected_sol)
end

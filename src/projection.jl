function proj_cols_on_rep(sol::PrimalSolution{S}, master::Formulation) where {S}
    projsol = Dict{VarId, Float64}()
    partialsolmatrix = getpartialsolmatrix(master)
    for (mast_id, mast_val) in sol
        for (rep_id, rep_val) in partialsolmatrix[mast_id, :]
            projsol[rep_id] = (get!(projsol, rep_id, 0.0) + rep_val) * mast_val
        end
    end

    # TODO : add pure master variables
    
    return PrimalSolution(S, float(getbound(sol)), projsol)
end
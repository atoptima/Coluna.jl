function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{DwMaster}) where {Sense}
    projected_sol = Dict{VarId, Float64}()
    primalspsolmatrix = getprimalsolmatrix(master)
    for (mc_id, mc_val) in sol
        for (rep_id, rep_val) in Iterators.filter(
                _rep_of_orig_var_, primalspsolmatrix[:, mc_id]
            )
            projected_sol[rep_id] = (get!(projected_sol, rep_id, 0.0)) + rep_val * mc_val
        end
    end

    # TODO : add pure master variables

    return PrimalSolution(master, float(getbound(sol)), projected_sol)
end

function proj_cols_on_rep(sol::PrimalSolution{Sense}, master::Formulation{BendersMaster}) where {Sense}
    return sol
end

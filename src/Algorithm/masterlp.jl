struct MasterLp <: AbstractAlgorithm end

struct MasterLpRecord <: AbstractAlgorithmResult
    incumbents::Incumbents
    proven_infeasible::Bool
end

function prepare!(algo::MasterLp, form, node)
    @logmsg LogLevel(-1) "Prepare MasterLp."
    return
end

function run!(algo::MasterLp, form, node)
    master = getmaster(form)

    incumbents = Incumbents(form.master.obj_sense)
    #update_ip_primal_sol!(incumbents, get_ip_primal_sol(node.incumbents))

    elapsed_time = @elapsed begin
        opt_result = TO.@timeit Coluna._to "LP restricted master" optimize!(master)
    end

    proven_infeasible = opt_result == MOI.INFEASIBLE || opt_result == MOI.INFEASIBLE_OR_UNBOUNDED

    primal_sols = getprimalsols(opt_result)
    dual_sols = getdualsols(opt_result)
    update_lp_primal_sol!(incumbents, primal_sols[1])
    update_lp_dual_sol!(incumbents, dual_sols[1])
    if isinteger(primal_sols[1]) && !contains(primal_sols[1], MasterArtVar)
        update_ip_primal_sol!(incumbents, primal_sols[1])
    end
    return MasterLpRecord(incumbents, proven_infeasible)
end

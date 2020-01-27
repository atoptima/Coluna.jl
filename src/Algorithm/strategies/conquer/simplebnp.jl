struct SimpleBnP <: AbstractConquerStrategy 
    colgen::ColumnGeneration
    mastipheur::MasterIpHeuristic
end

function SimpleBnP(
    ;colgen = ColumnGeneration(), mastipheur = MasterIpHeuristic()
)
    return SimpleBnP(colgen, mastipheur)
end

isverbose(strategy::SimpleBnP) = strategy.colgen.log_print_frequency > 0

function apply!(strategy::SimpleBnP, reform, node)
    colgen_rec = apply!(strategy.colgen, reform, node)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    #mip_rec = apply!(strategy.mastipheur, reform, node)
    return
end

struct RestrictedMasterResolve <: AbstractConquerStrategy 
    master_lp::MasterLp
end

function RestrictedMasterResolve()
    return RestrictedMasterResolve(MasterLp())
end

function apply!(strategy::RestrictedMasterResolve, reform, node)
    record = apply!(strategy.master_lp, reform, node)

    if isempty(reform.dw_pricing_subprs)
        update!(node.incumbents, record.incumbents) 
    else
        # we update only primal solutions, as dual ones are not valid for the node 
        # (as column generation is not executed)
        update_lp_primal_sol!(node.incumbents, get_lp_primal_sol(record.incumbents))
        update_ip_primal_sol!(node.incumbents, get_ip_primal_sol(record.incumbents))
    end

    if record.proven_infeasible
        node.status.proven_infeasible = true
    end
    return
end


struct BnPnPreprocess <: AbstractConquerStrategy 
    preprocess::Preprocess
    colgen::ColumnGeneration
    mastipheur::MasterIpHeuristic
end

isverbose(strategy::BnPnPreprocess) = strategy.colgen.log_print_frequency > 0

function BnPnPreprocess(
    ;preprocess = Preprocess(), colgen = ColumnGeneration(), 
    mastipheur = MasterIpHeuristic()
)
    return BnPnPreprocess(preprocess, colgen, mastipheur)
end

function apply!(strategy::BnPnPreprocess, reform, node)
    prepr_rec = apply!(strategy.preprocess, reform, node)
    if prepr_rec.proven_infeasible
       node.status.proven_infeasible = true
       return
    end
    colgen_rec = apply!(strategy.colgen, reform, node)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    mip_rec = apply!(strategy.mastipheur, reform, node)
    return
end

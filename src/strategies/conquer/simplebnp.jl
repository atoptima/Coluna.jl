struct SimpleBnP <: AbstractConquerStrategy end

function apply!(::Type{SimpleBnP}, reform, node, strategy_rec::StrategyRecord, params)
    colgen_rec = apply!(ColumnGeneration, reform, node, strategy_rec, params)
    if colgen_rec.proven_infeasible
        node.status.proven_infeasible = true
        return
    end
    ip_gap(colgen_rec.incumbents) <= 0 && return
    mip_rec = apply!(MasterIpHeuristic, reform, node, strategy_rec, params)
    return
end


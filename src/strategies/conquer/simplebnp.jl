struct SimpleBnP <: AbstractConquerStrategy end

function apply!(::Type{SimpleBnP}, reform, node, strategy_rec::StrategyRecord, params)
    colgen_rec = apply!(ColumnGeneration, reform, node, strategy_rec, params)
    if ip_gap(colgen_rec.incumbents) <= 0
        return
    end
    mip_rec = apply!(MasterIpHeuristic, reform, node, strategy_rec, params)
    return
end 
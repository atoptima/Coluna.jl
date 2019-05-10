struct SimpleBnP <: AbstractAlgorithmStrategy end

function apply!(::Type{SimpleBnP}, reform, node, record::StrategyRecord, params)
    colgen_record = apply!(ColumnGeneration, reform, node, record, params)
    db = get_ip_dual_bound(colgen_record.incumbents)
    pb = get_ip_primal_bound(colgen_record.incumbents)
    if gap(pb, db) <= 0
        record.do_branching = false
        return
    end
    mip_record = apply!(MasterIpHeuristic, reform, node, record, params)
    return
end 
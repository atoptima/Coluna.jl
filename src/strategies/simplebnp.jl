struct SimpleBnP <: AbstractStrategy end

function apply(::Type{SimpleBnP}, f, n, r::StrategyRecord, p)
    colgen_record = apply!(ColumnGeneration, f, n, r, nothing)
    db = get_ip_dual_bound(colgen_record.incumbents)
    pb = get_ip_primal_bound(colgen_record.incumbents)
    if gap(pb, db) <= 0
        return
    end
    mip_record = apply!(MasterIpHeuristic, f, n, r, nothing)
    generate_children = apply!(GenerateChildrenNode, f, n, r, nothing)
    return
end 
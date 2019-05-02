struct SimpleBnP <: AbstractStrategy end

function apply(::Type{SimpleBnP}, f, n, r::StrategyRecord, p)
    colgen_record = apply!(ColumnGeneration, f, n, r, nothing)
    mip_record = apply!(MasterIpHeuristic, f, n, r, nothing)
    generate_children = apply!(GenerateChildrenNode, f, n, r, nothing)
    return
end
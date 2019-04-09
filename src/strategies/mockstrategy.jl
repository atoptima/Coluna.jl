struct MockStrategy <: AbstractStrategy end

function apply(::Type{MockStrategy}, f, n, r::StrategyRecord, p)
    colgen_record = apply(ColumnGeneration, f, n, r, nothing)
    mip_record = apply(MasterIpHeuristic, f, n, r, nothing)
    return
end
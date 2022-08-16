function _store_records!(records::RecordsVector, model)
    storage = getstorage(model)
    records_of_model = AbstractNewRecord[]
    for storage_unit_type in Iterators.keys(storage.units)
        record = create_record(storage, storage_unit_type)
        push!(records_of_model, record)
    end
    push!(records, (getuid(model) => records_of_model))
    return
end

"""

"""
function store_records!(reform::Reformulation)
    records = Pair{Int, Vector{AbstractNewRecord}}[]
    _store_records!(records, reform)
    _store_records!(records, getmaster(reform))
    for form in Iterators.values(get_dw_pricing_sps(reform))
        _store_records!(records, form)
    end
    for form in Iterators.values(get_benders_sep_sps(reform))
        _store_records!(records, form)
    end
    return records
end

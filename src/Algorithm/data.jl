function store_records!(form::Formulation, records::RecordsVector)
    storagedict = form.storage.units
    storage = form.storage
    for (_, storagecont) in storagedict
        recordid = store_record!(storage, storagecont)
        push!(records, storagecont => recordid)
    end
    return
end

function store_records!(reform::Reformulation, records::RecordsVector)
    storagedict = reform.storage.units
    for (_, storagecont) in storagedict
        recordid = (storagecont)
        push!(records, (storagecont, recordid))
    end
    store_records!(getmaster(reform), records)
    for (_, form) in get_dw_pricing_sps(reform)
        store_records!(form, records)
    end
    for (_, form) in get_benders_sep_sps(reform)
        store_records!(form, records)
    end
    return
end

function store_records!(reform::Reformulation)
    TO.@timeit Coluna._to "Store records" begin
    records = RecordsVector()
    store_records!(reform, records)
    end 
    return records
end

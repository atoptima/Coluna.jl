
function ColunaBase.getunit(form::AbstractModel, pair)
    storagecont = get(form.storagedict, pair, nothing)
    storagecont === nothing && error("No storage unit for pair $pair in $(typeof(form)) with id $(getuid(form)).")
    return storagecont.storage_unit
end

function store_records!(form::Formulation, records::RecordsVector)
    storagedict = form.storagedict
    for (FullType, storagecont) in storagedict
        recordid = store_record!(storagecont)
        push!(records, storagecont => recordid)
    end
    return
end

function store_records!(reform::Reformulation, records::RecordsVector)
    storagedict = reform.storagedict
    for (FullType, storagecont) in storagedict
        recordid = store_record!(storagecont)
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

function ColunaBase.check_records_participation(form::Formulation)
    storagedict = form.storagedict
    for (FullType, storagecont) in storagedict
        check_records_participation(storagecont)
    end
end

function ColunaBase.check_records_participation(reform::Reformulation)
    storagedict = reform.storagedict
    for (FullType, storagecont) in storagedict
        check_records_participation(storagecont)
    end
    check_records_participation(getmaster(reform))
    for (_, form) in get_dw_pricing_sps(reform)
        check_records_participation(form)
    end
    for (_, form) in get_benders_sep_sps(reform)
        check_records_participation(form)
    end
    return
end

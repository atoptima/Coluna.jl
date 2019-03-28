struct Filter{T}
    mask::SparseVector{Bool,Int}
    container::T
    f::Function
    # Add info to know when to call dropzeros
end

getmask(f::Filter) = f.mask
getf(f::Filter) = f.f
getvm(f::Filter) = f.var_manager

function get_nz_ids(f::Filter)
    return findnz(f.mask)[1]
end

function Filter(container::C, f::Function, varconstrs::SparseVector{T,Int}
                ) where {C,T}
    mask = SparseVector{Bool,Int}(spzeros(Bool, MAX_SV_ENTRIES))
    for uid in findnz(varconstrs)[1]
        vc = getvc(container, uid)
        if f(vc)
            mask[uid] = true
        end
    end
    return Filter(mask, container, f)
end

function update_filter(filter::Filter, uid::Int)
    vc = getvc(filter.container, uid)
    if filter.f(vc)
        filter.mask[uid] = true
    end
end

function remove_element(filter::Filter, uid::Int)
    filter.mask[uid] = false
end

function update_mask(filter::Filter)
    # This will be useful to update the filter in the begining of an algorithm
    # that does not know what has changed in the container
    # filter.mask = filter.maks .& get_all(filter.container)
end

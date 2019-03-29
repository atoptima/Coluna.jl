# Define default filter functions

struct Filter{T}
    mask::SparseVector{Bool,Int}
    f::Function
    # Add info to know when to call dropzeros
end

function Filter(f::Function, varconstrs::SparseVector{T,Int}
                ) where {T <: AbstractVarConstr}
    mask = SparseVector{Bool,Int}(spzeros(Bool, MAX_SV_ENTRIES))
    for uid in findnz(varconstrs)[1]
        if f(varconstrs[uid])
            mask[uid] = true
        end
    end
    return Filter(mask, f)
end

getmask(f::Filter) = f.mask
getfunc(f::Filter) = f.f
get_nz_ids(f::Filter) = findnz(f.mask)[1]

# This function applies the mask defined in f over the VarConstrs in vcs
# Will be necessary to define some base methods that should be applied to T:
# At least Base.zero and Base.& should be implemented
apply_mask(f::Filter, vcs::SparseVector{T,Int}) where {T} = v.mask .& vcs

function update_mask(filter::Filter, vc::AbstractVarConstr)
    !filter.f(vc) && return
    filter.mask[getuid(vc)] = true
end

function remove_element(filter::Filter, uid::Int)
    filter.mask[uid] = false
end

function update_mask(filter::Filter, varconstrs::SparseVector{T,Int}
                     ) where {T <: AbstractVarConstr}
    # This will be useful to update the filter in the begining of an algorithm
    # that does not know what has changed in the container
    # filter.mask = filter.maks .& get_all(filter.container)
end

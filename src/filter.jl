mutable struct Filter
    used_mask::SparseVector{Bool,Int}
    active_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
    artificial_mask::SparseVector{Bool,Int}
    implicit_mask::SparseVector{Bool,Int}
end

Filter() = Filter(spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES))

activemask(f::Filter) = f.used_mask .& f.active_mask
staticmask(f::Filter) = f.used_mask .& f.static_mask
dynamicmask(f::Filter) = f.used_mask .& !f.static_mask
realmask(f::Filter) = f.used_mask .& !f.artificial_mask
artificalmask(f::Filter) = f.used_mask .& f.artificial_mask
implicitmask(f::Filter) = f.used_mask .& f.implicit_mask
explicitmask(f::Filter) = f.used_mask .& !f.implicit_mask
#selectivemask(f::Filter, active::Bool, static::Bool, artificial::Bool) = f.used_mask active ? .& f.active_mask : nothing  static ? .& f.static_mask : nothing  artificial ? .& f.artificial_mask : nothing

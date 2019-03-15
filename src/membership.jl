struct ConstrMembership
    member_coef_map::SparseVector{Float64,ConstrId}
end

struct VarMembership
    member_coef_map::SparseVector{Float64,VarId}
end

mutable struct VarManager 
    active_static_list::SparseVector{Int,VarId}
    active_dynamic_list::SparseVector{Int,VarId}
    unsuitable_static_list::SparseVector{Int,VarId}
    unsuitable_dynamic_list::SparseVector{Int,VarId}
end

mutable struct ConstrManager 
    active_static_list::SparseVector{Int,ConstrId}
    active_dynamic_list::SparseVector{Int,ConstrId}
    unsuitable_static_list::SparseVector{Int,ConstrId}
    unsuitable_dynamic_list::SparseVector{Int,ConstrId}
end




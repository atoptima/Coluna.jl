struct ElemDict{K,T}
    elements::Dict{K,T}
end

ElemDict{K,T}() where {K,T} = ElemDict{K,T}(Dict{K,T}())

Base.setindex!(d::ElemDict{K,T}, val::T, id::K) where {K,T} = d.elements[id] = val
Base.getindex(d::ElemDict{K,T}, i::K) where {K,T} = Base.getindex(d.elements, i)
Base.haskey(d::ElemDict{K,T}, i::K) where {K,T} = Base.haskey(d.elements, i)
Base.keys(d::ElemDict) = Base.keys(d.elements)
Base.values(d::ElemDict) = Base.values(d.elements)
Base.iterate(d::ElemDict) = iterate(d.elements)
Base.iterate(d::ElemDict, state) = iterate(d.elements, state)
Base.length(d::ElemDict) = length(d.elements)
Base.lastindex(d::ElemDict) = lastindex(d.elements)

function Base.filter(f::Function, elems::ElemDict{K,T}) where {K,T}
    return ElemDict{K,T}(filter(e -> f(e[2]), elems.elements))
end

function Base.Iterators.filter(f::Function, elems::ElemDict{K,T}) where {K,T}
    return Base.Iterators.filter(e -> f(e[2]), elems.elements)
end
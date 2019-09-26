struct ElemDict{VC <: AbstractVarConstr}
    elements::Dict{Id{VC}, VC}
end

ElemDict{VC}() where {VC <: AbstractVarConstr} = ElemDict{VC}(Dict{Id{VC}, VC}())
Base.setindex!(d::ElemDict{VC}, val::VC, id::Id{VC}) where {VC} = d.elements[id] = val
Base.getindex(d::ElemDict{VC}, i::Id{VC}) where {VC} = Base.getindex(d.elements, i)
Base.haskey(d::ElemDict{VC}, i::Id{VC}) where {VC} = Base.haskey(d.elements, i)
Base.keys(d::ElemDict) = Base.keys(d.elements)
Base.values(d::ElemDict) = Base.values(d.elements)
iterate(d::ElemDict) = iterate(d.elements)
iterate(d::ElemDict, state) = iterate(d.elements, state)
length(d::ElemDict) = length(d.elements)
lastindex(d::ElemDict) = lastindex(d.elements)

function Base.filter(f::Function, elems::ElemDict{VC}) where {VC}
    return ElemDict{VC}(filter(e -> f(e[2]), elems.elements))
end

function Base.Iterators.filter(f::Function, elems::ElemDict{VC}) where {VC}
    return Base.Iterators.filter(e -> f(e[2]), elems.elements)
end
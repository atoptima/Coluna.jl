struct ElemDict{VC <: AbstractVarConstr}
    elements::Dict{Id{VC}, VC}
end

function ElemDict{VC}() where {VC <: AbstractVarConstr}
    return ElemDict{VC}(Dict{Id{VC}, VC}())
end

function Base.setindex!(d::ElemDict{VC}, val::VC, id::Id{VC}) where {VC}
    d.elements[id] = val
end

function Base.getindex(d::ElemDict{VC}, id::Id{VC}) where {VC}
    Base.getindex(d.elements, id)
end

function Base.haskey(d::ElemDict{VC}, id::Id{VC}) where {VC}
    Base.haskey(d.elements, id)
end

function Base.keys(d::ElemDict)
    Base.keys(d.elements)
end

function Base.values(d::ElemDict)
    Base.values(d.elements)
end

iterate(d::ElemDict) = iterate(d.elements)
iterate(d::ElemDict, state) = iterate(d.elements, state)
length(d::ElemDict) = length(d.elements)
lastindex(d::ElemDict) = lastindex(d.elements)

function Base.filter(f::Function, elems::ElemDict{VC}) where {VC}
    return ElemDict{VC}(filter(e -> f(e[2]), elems.elements))
end
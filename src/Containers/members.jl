abstract type AbstractMembersContainer end

mutable struct MembersVector{I,K,T} <: AbstractMembersContainer
    elements::Dict{I,K} # holds a reference towards the container of elements (sorted by ID) to which we associate records
    records::Dict{I,T} # holds the records associated to elements that are identified by their ID
end

"""
    MembersVector{T}(elems::Dict{I,K})

Construct a `MembersVector` with indices of type `I`, elements of type `K`, and
records of type `T`.

The `MembersVector` maps each index to a tuple of element and record. This 
structure must be use like a `Vector{I,T}`. If the user looks for an index 
that that has an element associated but no record, `MembersVector` returns 
`zeros(T)`.
"""
function MembersVector{T}(elems::Dict{I,K}) where {I,K,T} 
    return MembersVector{I,K,T}(elems, Dict{I,T}())
end

function MembersVector{T}(elems::ElemDict{I,K}) where {I,K,T}
    return MembersVector{T}(elems.elements)
end


getrecords(vec::MembersVector) = vec.records


function Base.setindex!(vec::MembersVector{I,K,T}, val, id::I) where {I,K,T}
    vec.records[id] = val
end

function Base.get(vec::MembersVector{I,K,T}, id::I, default) where {I,K,T}
    Base.get(vec.records, id, default)
end

function Base.getindex(vec::MembersVector{I,K,MembersVector{J,L,T}}, id::I) where {I,J,K,L,T<:Number}
    Base.get(vec, id, Nothing)
end

function Base.getindex(vec::MembersVector{I,K,T}, id::I) where {I,K,T<:Number}
    Base.get(vec, id, zero(T))
end

function Base.haskey(vec::MembersVector{I,K,T}, id::I) where {I,K,T}
    Base.haskey(vec.records, id)
end


function Base.Iterators.filter(f::Function, vec::MembersVector{I,K,T}) where {I,K,T}
    return Base.Iterators.filter(
        e -> f(vec.elements[e[1]]) && e[2] != zero(T), vec.records
    )
end


Base.iterate(d::MembersVector) = iterate(d.records)
Base.iterate(d::MembersVector, state) = iterate(d.records, state)

function Base.show(io::IO, vec::MembersVector{I,J,K}) where {I,J,K}
    print(io, "[")
    for (id, val) in vec
        print(io, " ", id, " => " , val, " ")
    end
    print(io, "]")
end

## New matrix
struct MembersMatrix{I,J,T}
    cols_major::DynamicSparseArrays.MappedPackedCSC{I,J,T}
    rows_major::DynamicSparseArrays.MappedPackedCSC{J,I,T}
end

function MembersMatrix{I,J,T}() where {I,J,T}
    return MembersMatrix{I,J,T}(
        DynamicSparseArrays.MappedPackedCSC(I,J,T),
        DynamicSparseArrays.MappedPackedCSC(J,I,T)
    )
end

function Base.setindex!(m::MembersMatrix, val, row_id, col_id)
    m.cols_major[row_id, col_id] = val
    m.rows_major[col_id, row_id] = val
    return m
end

function Base.getindex(m::MembersMatrix, row_id, col_id)
    # TODO : check number of rows & cols
    return m.cols_major[row_id, col_id]
end

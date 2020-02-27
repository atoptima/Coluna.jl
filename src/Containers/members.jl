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

######## DELETE BELOW THIS LINE #########
    
struct OldMembersMatrix{I,K,J,L,T} <: AbstractMembersContainer
    #matrix_csc::DynamicSparseArrays.MappedPackedCSC{}
    #matrix_csr::DynamicSparseArrays.MappedPackedCSC{}
    cols::MembersVector{I,K,MembersVector{J,L,T}} # to rm
    rows::MembersVector{J,L,MembersVector{I,K,T}} # to rm
end

"""
    OldMembersMatrix{T}(columns_elems::Dict{I,K}, rows_elems::Dict{J,L})

Construct a matrix that contains records of type `T`. Rows have indices of type
`J` and elements of type `L`, and columns have indices of type `I` and elements
of type `K`.

`OldMembersMatrix` supports julia set and get operations.
"""
function OldMembersMatrix{T}(
    col_elems::Dict{I,K}, row_elems::Dict{J,L}
) where {I,K,J,L,T}
    cols = MembersVector{MembersVector{J,L,T}}(col_elems)
    rows = MembersVector{MembersVector{I,K,T}}(row_elems)
    OldMembersMatrix{I,K,J,L,T}(cols, rows)
end

function OldMembersMatrix{T}(
    col_elems::ElemDict{VC1}, row_elems::ElemDict{VC2}
) where {VC1,VC2,T}
    return OldMembersMatrix{T}(col_elems.elements, row_elems.elements)
end

function _getrecordvector!(
    vec::MembersVector{I,K,MembersVector{J,L,T}}, key::I, elems::Dict{J,L}, 
    create = true
) where {I,K,J,L,T}
    if !haskey(vec, key)
        membersvec = MembersVector{T}(elems)
        if create
            vec[key] = membersvec
        end
        return membersvec
    end
    vec[key]
end

function Base.setindex!(m::OldMembersMatrix, val, row_id, col_id)
    col = _getrecordvector!(m.cols, col_id, m.rows.elements)
    col[row_id] = val
    row = _getrecordvector!(m.rows, row_id, m.cols.elements)
    row[col_id] = val
    m
end

function Base.getindex(
    m::OldMembersMatrix{I,K,J,L,T}, row_id::J, ::Colon
) where {I,K,J,L,T}
    _getrecordvector!(m.rows, row_id, m.cols.elements, false)
end

function Base.getindex(
    m::OldMembersMatrix{I,K,J,L,T}, ::Colon, col_id::I
) where {I,K,J,L,T}
    _getrecordvector!(m.cols, col_id, m.rows.elements, false)
end

"""
    columns(membersmatrix)

Return a `MembersVector` that contains the columns.

When the matrix stores the coefficients of a formulation, the method returns
a `MembersVector` that contains `Variable` as elements. For each 
`Variable`, the record is the `MembersVector` that contains the coefficients of
the `Variable` in each `Constraint`.
"""
function columns(m::OldMembersMatrix)
    return m.cols
end

abstract type AbstractMembersContainer end

mutable struct MembersVector{I,K,T} <: AbstractMembersContainer
    elements::Dict{I, K}
    members::Dict{I, T}
end

MembersVector{I,K,T}(elems::Dict{I,K}) where {I,K,T} = MembersVector(elems, Dict{I,T}())

Base.eltype(vec::MembersVector{I,K,T}) where {I,K,T} = T
Base.ndims(vec::MembersVector) = 1

function Base.setindex!(vec::MembersVector{I,K,T}, val, id::I) where {I,K,T}
    vec.members[id] = val
end

function Base.get(vec::MembersVector{I,K,T}, id::I, default) where {I,K,T}
    Base.get(vec.members, id, default)
end

function Base.getindex(vec::MembersVector{I,K,T}, id::I) where {I,K,T}
    vec.members[id]
end

function Base.getindex(vec::MembersVector{I,K,T}, id::I) where {I,K,T<:Number}
    Base.get(vec, id, zero(T))
end

Base.getindex(vec::MembersVector, ::Colon) = vec

function Base.merge(op, vec1::MembersVector{I,K,T}, vec2::MembersVector{I,K,U}) where {I,K,T,U}
    (vec1.elements === vec2.elements) || error("elements are not the same.") # too much restrictive ?
    MembersVector(vec1.elements, Base.merge(op, vec1.members, vec2.members))
end

function Base.reduce(op, vec::MembersVector)
    Base.mapreduce(e -> e[2], op, vec.members)
end

function Base.:(==)(vec1::MembersVector, vec2::MembersVector)
    vec1.members == vec2.members
end

function Base.:(==)(vec1::Dict, vec2::MembersVector)
    vec1 == vec2.members
end

function Base.:(==)(vec1::MembersVector, vec2::Dict)
    vec1.members == vec2
end

function Base.:(!=)(vec1::MembersVector, vec2::MembersVector)
    vec1.members != vec2.members
end

function Base.haskey(vec::MembersVector{I,K,T}, id::I) where {I,K,T}
    Base.haskey(vec.members, id)
end

function Base.filter(f::Function, vec::MembersVector)
    MembersVector(vec.elements, Base.filter(e -> f(vec.elements[e[1]]), vec.members))
end

iterate(d::MembersVector) = iterate(d.members)
iterate(d::MembersVector, state) = iterate(d.members, state)
length(d::MembersVector) = length(d.members)
lastindex(d::MembersVector) = lastindex(d.members)

# =================================================================

struct MembersMatrix{I,K,J,L,T} <: AbstractMembersContainer
    #col_elements::Dict{I,K} # should be removed (because in cols)
    #row_elements::Dict{J,L}
    cols::MembersVector{I,K,MembersVector{J,L,T}}
    rows::MembersVector{J,L,MembersVector{I,K,T}}
end

function MembersMatrix{I,K,J,L,T}(col_elems::Dict{I,K}, row_elems::Dict{J,L}) where {I,K,J,L,T}
    cols = MembersVector{I,K,MembersVector{J,L,T}}(col_elems)
    rows = MembersVector{J,L,MembersVector{I,K,T}}(row_elems)
    MembersMatrix(cols, rows)
end

function _getmembersvector!(dict::MembersVector{I,K,MembersVector{J,L,T}}, key::I, elems::Dict{J,L}) where {I,K,J,L,T}
    if !haskey(dict, key)
        membersvec = MembersVector{J,L,T}(elems)
        dict[key] = membersvec
        return membersvec
    end
    dict[key]
end

function Base.setindex!(m::MembersMatrix, val, col_id, row_id)
    cols = _getmembersvector!(m.cols, col_id, m.cols.elements)
    cols[row_id] = val
    rows = _getmembersvector!(m.rows, row_id, m.rows.elements)
    rows[col_id] = val
    m
end

function Base.getindex(m::MembersMatrix, col_id, row_id)
    if length(m.cols) < length(m.rows) # improve ?
        return m.cols[col_id][row_id]
    else
        return m.rows[row_id][col_id]
    end
end

function Base.getindex(m::MembersMatrix, ::Colon, row_id)
    _getmembersvector!(m.rows, row_id, m.rows.elements)
end

function Base.getindex(m::MembersMatrix, col_id, ::Colon)
    _getmembersvector!(m.cols, col_id, m.cols.elements)
end

function setcolumn!(m::MembersMatrix, col_id, new_col::Dict)
    col = MembersVector(m.cols.elements, deepcopy(new_col))
    m.cols[col_id] = col
    for (row_id, val) in col
        row = _getmembersvector!(m.rows, row_id, m.rows.elements)
        row[col_id] = val
    end
    m
end

function setrow!(m::MembersMatrix, row_id, new_row::Dict)
    row = MembersVector(m.row_elements, deepcopy(new_row))
    m.rows[row_id] = row
    for (col_id, val) in row
        col = _getmembersvector!(m.cols, col_id, m.cols.elements)
        col[row_id] = val
    end
    m
end

function columns(m::MembersMatrix)
    return m.cols
end

function rows(m::MembersMatrix)
    return m.rows
end
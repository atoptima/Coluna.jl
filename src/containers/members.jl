abstract type AbstractMembersContainer end

mutable struct MembersVector{I, T} <: AbstractMembersContainer
    members::Dict{I, T}
end

MembersVector{I,T}() where {I,T} = MembersVector(Dict{I,T}())

Base.eltype(vec::MembersVector{I,T}) where {I,T} = T
Base.ndims(vec::MembersVector) = 1

function Base.setindex!(vec::MembersVector{I,T}, val, id::I) where {I,T}
    vec.members[id] = val
end

function Base.get(vec::MembersVector{I,T}, id::I, default) where {I,T}
    Base.get(vec.members, id, default)
end

function Base.getindex(vec::MembersVector{I,T}, id::I) where {I,T}
    vec.members[id]
end

function Base.getindex(vec::MembersVector{I,T}, id::I) where {I,T<:Number}
    Base.get(vec, id, zero(T))
end

Base.getindex(vec::MembersVector, ::Colon) = vec

function Base.merge(op, vec1::MembersVector{I,T}, vec2::MembersVector{I,U}) where {I,T,U}
    MembersVector(Base.merge(op, vec1.members, vec2.members))
end

function Base.reduce(op, vec::MembersVector)
    Base.mapreduce(e -> e[2], op, vec.members)
end

function Base.:(==)(vec1::MembersVector, vec2::MembersVector)
    vec1.members == vec2.members
end

function Base.:(!=)(vec1::MembersVector, vec2::MembersVector)
    vec1.members != vec2.members
end

iterate(d::MembersVector) = iterate(d.members)
iterate(d::MembersVector, state) = iterate(d.members, state)
length(d::MembersVector) = length(d.members)
lastindex(d::MembersVector) = lastindex(d.members)

# =================================================================

struct MembersMatrix{I,K,J,L,T} <: AbstractMembersContainer
    cols_elements::Dict{I,K}
    rows_elements::Dict{J,L}
    cols::Dict{I, MembersVector{J,T}}
    rows::Dict{J, MembersVector{I,T}}
end

function MembersMatrix{I,K,J,L,T}(cols_elems, rows_elems) where {I,K,J,L,T}
    cols = Dict{I, MembersVector{J,T}}()
    rows = Dict{J, MembersVector{I,T}}()
    MembersMatrix(cols_elems, rows_elems, cols, rows)
end

function _getmembersvector!(dict::Dict{I, MembersVector{J,T}}, key::I) where {I,J,T}
    if !haskey(dict, key)
        membersvec = MembersVector{J,T}()
        dict[key] = membersvec
        return membersvec
    end
    dict[key]
end

function Base.setindex!(m::MembersMatrix, val, col_id, row_id)
    cols = _getmembersvector!(m.cols, col_id)
    cols[row_id] = val
    rows = _getmembersvector!(m.rows, row_id)
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
    _getmembersvector!(m.rows, row_id)
end

function Base.getindex(m::MembersMatrix, col_id, ::Colon)
    _getmembersvector!(m.cols, col_id)
end

function setcolumn!(m::MembersMatrix, col_id, new_col::MembersVector)
    col = deepcopy(new_col)
    m.cols[col_id] = col
    for (row_id, val) in col
        row = _getmembersvector!(m.rows, row_id)
        row[col_id] = val
    end
    m
end

function setrow!(m::MembersMatrix, row_id, new_row::MembersVector)
    row = deepcopy(new_row)
    m.rows[row_id] = row
    for (col_id, val) in row
        col = _getmembersvector!(m.cols, col_id)
        col[row_id] = val
    end
    m
end

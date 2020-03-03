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
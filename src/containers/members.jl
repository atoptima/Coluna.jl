abstract type AbstractMembersContainer end

mutable struct MembersVector{I,K,T} <: AbstractMembersContainer
    elements::Dict{I, K} # holds a reference towards the container of elements (sorted by ID) to which we associate records
    records::Dict{I, T} # holds the records associated to elements that are identified by their ID
end

"""
    MembersVector{T}(elems::Dict{I,K})

Construct a `MembersVector` with indices of type `I`, elements of type `K`, and
records of type `T`.

The `MembersVector` maps each index to a tuple of element and record. This 
structure is used like a `Container{I,T}`. Thus, accessing to the container at 
a given index returns the record associated to the index. If an index has no 
record, `MembersVector` returns `zeros(T)`.

Elements allow functions to do operations on the records according to them.
Overloaded `Base` functions `reduce` and `filter` are provided to process on 
records according to elements.

# Example
We want to associate variables and coefficients to store a constraint. 
For this, we create a `MembersVector`

```julia-repl
julia> vars_in_formulation = Dict{VarId, Variable}( ... )
julia> MembersVector{Float64}(vars_in_formulation)
```

where `vars_in_formulation` is a dictionnary that contains all the existing
variables in the formulation.
"""
function MembersVector{T}(elems::Dict{I,K}) where {I,K,T} 
    MembersVector{I,K,T}(elems, Dict{I,T}())
end

getrecords(vec::MembersVector) = vec.records
getelements(vec::MembersVector) = vec.elements
getelement(vec::MembersVector{I}, i::I) where {I,K,T} = vec.elements[i]

Base.eltype(vec::MembersVector{I,K,T}) where {I,K,T} = T
Base.ndims(vec::MembersVector) = 1

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

Base.getindex(vec::MembersVector, ::Colon) = vec

"""
    merge(op, vec1::MembersVector{I,K,T}, vec2::MembersVector{I,K,T})

Return a new `MembersVector` in which the records are equal to 
`op(vec1.records, vec2.records)`.
Note that elements of `vec1` and `vec2` must be identical.
"""
function Base.merge(op, vec1::MembersVector{I,K,T}, vec2::MembersVector{I,K,U}) where {I,K,T,U}
    (vec1.elements === vec2.elements) || error("elements are not the same.") # too much restrictive ?
    MembersVector(vec1.elements, Base.merge(op, vec1.records, vec2.records))
end

"""
    reduce(op, vec)

Reduce the array of records of `vec` to a value using operation `op`.
"""
function Base.reduce(op, vec::MembersVector)
    Base.mapreduce(e -> e[2], op, vec.records)
end

function Base.:(==)(vec1::MembersVector, vec2::MembersVector)
    vec1.records == vec2.records
end

function Base.:(==)(vec1::Dict, vec2::MembersVector)
    vec1 == vec2.records
end

function Base.:(==)(vec1::MembersVector, vec2::Dict)
    vec1.records == vec2
end

function Base.:(!=)(vec1::MembersVector, vec2::MembersVector)
    vec1.records != vec2.records
end

function Base.haskey(vec::MembersVector{I,K,T}, id::I) where {I,K,T}
    Base.haskey(vec.records, id)
end

"""
    filter(function, vec)

Return a `MembersVector` without the records for which `function` with the
element associated with the record as input returns false.

# Example

Given a `vec::MembersVector` that associates variables with coefficients, we 
want the coefficients of integer variables :

```julia-repl
julia> filter(var -> integer(var), vec)
```

where function `integer(var)` returns true if variable `var` is integer.
"""
function Base.filter(f::Function, vec::MembersVector)
    MembersVector(vec.elements, Base.filter(e -> f(vec.elements[e[1]]), vec.records))
end

function Base.keys(vec::MembersVector)
    Base.keys(vec.records)
end

function Base.copy(vec::V) where {V <: MembersVector}
    return V(vec.elements, deepcopy(vec.records))
end

iterate(d::MembersVector) = iterate(d.records)
iterate(d::MembersVector, state) = iterate(d.records, state)
length(d::MembersVector) = length(d.records)
lastindex(d::MembersVector) = lastindex(d.records)

function Base.show(io::IO, vec::MembersVector{I,J,K}) where {I,J <: AbstractVarConstr,K}
    print(io, "[")
    for (id, val) in vec
        print(io, " ", id, " => (", getname(getelement(vec, id)), ", " , val, ")  ")
    end
    print(io, "]")
end


struct MembersMatrix{I,K,J,L,T} <: AbstractMembersContainer
    cols::MembersVector{I,K,MembersVector{J,L,T}}
    rows::MembersVector{J,L,MembersVector{I,K,T}}
end

"""
    MembersMatrix{T}(columns_elems::Dict{I,K}, rows_elems::Dict{J,L})

Construct a matrix that contains records of type `T`. Rows have indices of type
`J`and elements of type `L`, and columns have indices of type `I` and elements
of type `K`.

`MembersMatrix` supports julia set and get operations.
"""
function MembersMatrix{T}(col_elems::Dict{I,K}, row_elems::Dict{J,L}
                      ) where {I,K,J,L,T}
    cols = MembersVector{MembersVector{J,L,T}}(col_elems)
    rows = MembersVector{MembersVector{I,K,T}}(row_elems)
    MembersMatrix{I,K,J,L,T}(cols, rows)
end

function _getrecordvector!(dict::MembersVector{I,K,MembersVector{J,L,T}}, key::I, elems::Dict{J,L}, create = true) where {I,K,J,L,T}
    if !haskey(dict, key)
        membersvec = MembersVector{T}(elems)
        if create
            dict[key] = membersvec
        end
        return membersvec
    end
    dict[key]
end

function _setcolumn!(m::MembersMatrix{I,K,J,L,T}, col_id::I, col::Dict{J,T}) where {I,K,J,L,T}
    new_col = MembersVector(m.rows.elements, col)
    _setcolumn!(m, col_id, new_col)
end

function _setcolumn!(m::MembersMatrix{I,K,J,L,T}, col_id::I, col::MembersVector{J,L,T}) where {I,K,J,L,T}
    @assert m.rows.elements == col.elements
    m.cols[col_id] = col
    for (row_id, val) in col
        row = _getrecordvector!(m.rows, row_id, m.cols.elements)
        row[col_id] = val
    end
    m
end

function _setrow!(m::MembersMatrix{I,K,J,L,T}, row_id::J, row::Dict{I,T}) where {I,K,J,L,T}
    new_row = MembersVector(m.cols.elements, row)
    _setrow!(m, row_id, new_row)
end

function _setrow!(m::MembersMatrix{I,K,J,L,T}, row_id::J, row::MembersVector{I,K,T}) where {I,K,J,L,T}
    @assert m.cols.elements == row.elements
    m.rows[row_id] = row
    for (col_id, val) in row
        col = _getrecordvector!(m.cols, col_id, m.rows.elements)
        col[row_id] = val
    end
    m
end

function Base.setindex!(m::MembersMatrix, val, row_id, col_id)
    col = _getrecordvector!(m.cols, col_id, m.rows.elements)
    col[row_id] = val
    row = _getrecordvector!(m.rows, row_id, m.cols.elements)
    row[col_id] = val
    m
end

function Base.setindex!(m::MembersMatrix, row, row_id, ::Colon)
    _setrow!(m, row_id, row)
end

function Base.setindex!(m::MembersMatrix, col, ::Colon, col_id)
    _setcolumn!(m, col_id, col)
end

function Base.getindex(m::MembersMatrix{I,K,J,L,T}, row_id::J, col_id::I) where {I,K,J,L,T}
    if length(m.cols) < length(m.rows) # improve ?
        col = m.cols[col_id]
        col === Nothing && return zero(T)
        return col[row_id]
    else
        row = m.rows[row_id]
        row === Nothing && return zero(T)
        return row[col_id]
    end
end

function Base.getindex(m::MembersMatrix{I,K,J,L,T}, row_id::J, ::Colon) where {I,K,J,L,T}
    _getrecordvector!(m.rows, row_id, m.cols.elements, false)
end

function Base.getindex(m::MembersMatrix{I,K,J,L,T}, ::Colon, col_id::I) where {I,K,J,L,T}
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
function columns(m::MembersMatrix)
    return m.cols
end

"""
    rows(membersmatrix)

Return a `MembersVector`that contains the rows.

When the matrix stores the coefficients of a formulation, the method returns
a `MembersVector` that contains `Constraint` as elements. For each 
`Constraint`, the record is the `MembersVector` that contains the coefficients 
of each `Variable` in the `Constraint`.
"""
function rows(m::MembersMatrix)
    return m.rows
end
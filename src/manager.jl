abstract type AbstractMembersContainer end

mutable struct MembersVector{I,K,T} <: AbstractMembersContainer
    elements::Dict{I, K} # holds a reference towards the container of elements (sorted by ID) to which we associate records
    records::Dict{I, T} # holds the records associated to elements that are identified by their ID
end

get_records(vec::MembersVector) = vec.records

get_elements(vec::MembersVector) = vec.elements

get_element(vec::MembersVector{I}, i::I) where {I,K,T} = vec.elements[i]

MembersVector{I,K,T}(elems::Dict{I,K}) where {I,K,T} = MembersVector(elems, Dict{I,T}())

#MembersVector{I,K,T}() where {I,K,T} = MembersVector( Dict{I, K}(), Dict{I,T}() )

Base.eltype(vec::MembersVector{I,K,T}) where {I,K,T} = T

Base.ndims(vec::MembersVector) = 1

function Base.setindex!(vec::MembersVector{I,K,T}, val, id::I) where {I,K,T}
    vec.records[id] = val
end

function Base.get(vec::MembersVector{I,K,T}, id::I, default) where {I,K,T}
    Base.get(vec.records, id, default)
end

function Base.getindex(vec::MembersVector{I,K,T}, id::I) where {I,K,T}
    vec.records[id]
end

function Base.getindex(vec::MembersVector{I,K,T}, id::I) where {I,K,T<:Number}
    Base.get(vec, id, zero(T))
end

Base.getindex(vec::MembersVector, ::Colon) = vec

function Base.merge(op, vec1::MembersVector{I,K,T}, vec2::MembersVector{I,K,U}) where {I,K,T,U}
    (vec1.elements === vec2.elements) || error("elements are not the same.") # too much restrictive ?
    MembersVector(vec1.elements, Base.merge(op, vec1.records, vec2.records))
end

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

function Base.filter(f::Function, vec::MembersVector)
    MembersVector(vec.elements, Base.filter(e -> f(vec.elements[e[1]]), vec.records))
end

function Base.keys(vec::MembersVector)
    Base.keys(vec.records)
end

iterate(d::MembersVector) = iterate(d.records)
iterate(d::MembersVector, state) = iterate(d.records, state)
length(d::MembersVector) = length(d.records)
lastindex(d::MembersVector) = lastindex(d.records)

function Base.show(io::IO, vec::MembersVector{I,J,K}) where {I,J <: AbstractVarConstr,K}
    print(io, "[")
    for (id, val) in vec
        print(io, " ", id, " => (", get_name(get_element(vec, id)), ", " , val, ")  ")
    end
    print(io, "]")
end

# =================================================================

struct MembersMatrix{I,K,J,L,T} <: AbstractMembersContainer
    cols::MembersVector{I,K,MembersVector{J,L,T}}
    rows::MembersVector{J,L,MembersVector{I,K,T}}
end

function MembersMatrix{I,K,J,L,T}(col_elems::Dict{I,K}, row_elems::Dict{J,L}) where {I,K,J,L,T}
    cols = MembersVector{I,K,MembersVector{J,L,T}}(col_elems)
    rows = MembersVector{J,L,MembersVector{I,K,T}}(row_elems)
    MembersMatrix(cols, rows)
end

#function MembersMatrix{I,K,J,L,T}() where {I,K,J,L,T}
#    MembersMatrix(MembersVector{I,K,MembersVector{J,L,T}}(), MembersVector{J,L,MembersVector{I,K,T}}())
#end

function _getrecordvector!(dict::MembersVector{I,K,MembersVector{J,L,T}}, key::I, elems::Dict{J,L}, create = true) where {I,K,J,L,T}
    if !haskey(dict, key)
        membersvec = MembersVector{J,L,T}(elems)
        if create
            dict[key] = membersvec
        end
        return membersvec
    end
    dict[key]
end

function setcolumn!(m::MembersMatrix{I,K,J,L,T}, col_id::I, col::Dict{J,T}) where {I,K,J,L,T}
    new_col = MembersVector(m.rows.elements, col)
    setcolumn!(m, col_id, new_col)
end

function setcolumn!(m::MembersMatrix{I,K,J,L,T}, col_id::I, col::MembersVector{J,L,T}) where {I,K,J,L,T}
    @assert m.rows.elements == col.elements
    m.cols[col_id] = col
    for (row_id, val) in col
        row = _getrecordvector!(m.rows, row_id, m.cols.elements)
        row[col_id] = val
    end
    m
end

function setrow!(m::MembersMatrix{I,K,J,L,T}, row_id::J, row::Dict{I,T}) where {I,K,J,L,T}
    new_row = MembersVector(m.cols.elements, row)
    setrow!(m, row_id, new_row)
end

function setrow!(m::MembersMatrix{I,K,J,L,T}, row_id::J, row::MembersVector{I,K,T}) where {I,K,J,L,T}
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
    setrow!(m, row_id, row)
end

function Base.setindex!(m::MembersMatrix, col, ::Colon, col_id)
    setcolumn!(m, col_id, col)
end

function Base.getindex(m::MembersMatrix, row_id, col_id)
    if length(m.cols) < length(m.rows) # improve ?
        return m.cols[col_id][row_id]
    else
        return m.rows[row_id][col_id]
    end
end

function Base.getindex(m::MembersMatrix, row_id, ::Colon)
    _getrecordvector!(m.rows, row_id, m.cols.elements, false)
end

function Base.getindex(m::MembersMatrix, ::Colon, col_id)
    _getrecordvector!(m.cols, col_id, m.rows.elements, false)
end

function columns(m::MembersMatrix)
    return m.cols
end

function rows(m::MembersMatrix)
    return m.rows
end

# =================================================================
const VarDict = Dict{VarId,Variable}
const ConstrDict = Dict{ConstrId,Constraint}
const VarConstrDict = Union{VarDict,ConstrDict}
const VarMembership = MembersVector{VarId,Variable,Float64}
const ConstrMembership = MembersVector{ConstrId,Constraint,Float64}
const MembMatrix = MembersMatrix{VarId,Variable,ConstrId,Constraint,Float64}

struct FormulationManager
    vars::VarDict
    constrs::ConstrDict
    coefficients::MembMatrix # rows = constraints, cols = variables
    partial_sols::MembMatrix # rows = variables, cols = solutions
    expressions::MembMatrix  # rows = expressions, cols = variables
end

function FormulationManager()
    vars = VarDict()
    constrs = ConstrDict()
    
    return FormulationManager(vars,
                              constrs,
                              MembMatrix(vars,constrs),
                              MembMatrix(vars,constrs),
                              MembMatrix(vars,constrs))
end

haskey(m::FormulationManager, id::Id{Variable}) = haskey(m.vars, id)
haskey(m::FormulationManager, id::Id{Constraint}) = haskey(m.constrs, id)

function add_var!(m::FormulationManager, var::Variable)
    haskey(m.vars, var.id) && error(string("Variable of id ", var.id, " exists"))
    m.vars[var.id] = var
    return var
end

function add_constr!(m::FormulationManager, constr::Constraint)
    haskey(m.constrs, constr.id) && error(string("Constraint of id ", constr.id, " exists"))
    m.constrs[constr.id] = constr
    return constr
end

getvar(m::FormulationManager, id::VarId) = m.vars[id]

get_constr(m::FormulationManager, id::ConstrId) = m.constrs[id]

get_vars(m::FormulationManager) = m.vars

get_constrs(m::FormulationManager) = m.constrs

get_coefficient_matrix(m::FormulationManager) = m.coefficients

function Base.show(io::IO, m::FormulationManager)
    println(io, "FormulationManager :")
    println(io, "> variables : ")
    for (id, var) in m.vars
        println(io, "  ", id, " => ", var)
    end
    println(io, "> constraints : ")
    for (id, constr) in m.constrs
        println(io, " ", id, " => ", constr)
    end
    return
end


# =================================================================


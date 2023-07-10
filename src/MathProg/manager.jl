const VarMembership = Dict{VarId, Float64}
const ConstrMembership = Dict{ConstrId, Float64}
const ConstrConstrMatrix = DynamicSparseArrays.DynamicSparseMatrix{ConstrId,ConstrId,Float64}
const VarConstrDualSolMatrix = DynamicSparseArrays.DynamicSparseMatrix{VarId,ConstrId,Tuple{Float64,ActiveBound}}
const VarVarMatrix = DynamicSparseArrays.DynamicSparseMatrix{VarId,VarId,Float64}

# Define the semaphore of the dynamic sparse matrix using MathProg.Id as index
DynamicSparseArrays.semaphore_key(I::Type{Id{VC}}) where VC = I(Duty{VC}(0), -1, -1, -1, -1)

# We wrap the coefficient matrix because we need to buffer the changes.
struct CoefficientMatrix{C,V,T}
    matrix::DynamicSparseArrays.DynamicSparseMatrix{C,V,T}
    buffer::FormulationBuffer
end

function CoefficientMatrix{C,V,T}(buffer) where {C,V,T}
    return CoefficientMatrix{C,V,T}(dynamicsparse(C,V,T), buffer)
end

const ConstrVarMatrix = CoefficientMatrix{ConstrId,VarId,Float64}

function Base.setindex!(m::CoefficientMatrix{C,V,T}, val, row::C, col::V) where {C,V,T}
    setindex!(m.matrix, val, row, col)
    if row ∉ m.buffer.constr_buffer.added && col ∉ m.buffer.var_buffer.added
        change_matrix_coeff!(m.buffer, row, col, val)
    end
    return
end

function Base.getindex(m::CoefficientMatrix{C,V,T}, row, col) where {C,V,T}
    return getindex(m.matrix, row, col)
end

DynamicSparseArrays.closefillmode!(m::CoefficientMatrix) = closefillmode!(m.matrix)

Base.view(m::CoefficientMatrix{C,V,T}, row::C, ::Colon) where {C,V,T} = view(m.matrix, row, :)
Base.view(m::CoefficientMatrix{C,V,T}, ::Colon, col::V) where {C,V,T} = view(m.matrix, :, col)
Base.transpose(m::CoefficientMatrix) = transpose(m.matrix)


# The formulation manager is an internal data structure that contains & manager
# all the elements which constitute a MILP formulation: variables, constraints,
# objective constant (costs stored in variables), coefficient matrix, 
# cut generators (that contain cut callbacks)...
mutable struct FormulationManager
    vars::Dict{VarId, Variable}
    constrs::Dict{ConstrId, Constraint}
    objective_constant::Float64
    coefficients::ConstrVarMatrix # rows = constraints, cols = variables
    fixed_vars::Set{VarId}
    robust_constr_generators::Vector{RobustConstraintsGenerator}
    custom_families_id::Dict{DataType,Int}
end

function FormulationManager(buffer; custom_families_id = Dict{BD.AbstractCustomData,Int}())
    vars = Dict{VarId, Variable}()
    constrs = Dict{ConstrId, Constraint}()
    return FormulationManager(
        vars,
        constrs,
        0.0,
        ConstrVarMatrix(buffer),
        Set{VarId}(),
        RobustConstraintsGenerator[],
        custom_families_id
    )
end

# Internal method to store a Variable in the formulation manager.
function _addvar!(m::FormulationManager, var::Variable)
    if haskey(m.vars, var.id)
        error(string(
            "Variable of id ", var.id, " exists. Its name is ", m.vars[var.id].name,
            " and you want to add a variable named ", var.name, "."
        ))
    end
    m.vars[var.id] = var
    return
end

# Internal method to fix a variable in the formulation manager.
function _fixvar!(m::FormulationManager, var::Variable)
    push!(m.fixed_vars, getid(var))
    return
end

function _unfixvar!(m::FormulationManager, var::Variable)
    delete!(m.fixed_vars, getid(var))
    return
end

_fixedvars(m::FormulationManager) = m.fixed_vars

# Internal methods to store a Constraint in the formulation manager.
function _addconstr!(m::FormulationManager, constr::Constraint)
    if haskey(m.constrs, constr.id)
        error(string(
            "Constraint of id ", constr.id, " exists. Its name is ", m.constrs[constr.id].name,
            " and you want to add a constraint named ", constr.name, "."
        ))
    end
    m.constrs[constr.id] = constr
    return
end

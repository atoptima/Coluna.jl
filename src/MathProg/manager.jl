const DynSparseVector{I} = DynamicSparseArrays.PackedMemoryArray{I, Float64}

const VarMembership = Dict{VarId, Float64}
const ConstrMembership = Dict{ConstrId, Float64}
const ConstrConstrMatrix = DynamicSparseArrays.DynamicSparseMatrix{ConstrId,ConstrId,Float64}
const ConstrVarMatrix = DynamicSparseArrays.DynamicSparseMatrix{ConstrId,VarId,Float64}
const VarConstrDualSolMatrix = DynamicSparseArrays.DynamicSparseMatrix{VarId,ConstrId,Tuple{Float64,ActiveBound}}
const VarVarMatrix = DynamicSparseArrays.DynamicSparseMatrix{VarId,VarId,Float64}

# Define the semaphore of the dynamic sparse matrix using MathProg.Id as index
DynamicSparseArrays.semaphore_key(::Type{I}) where {I <: Id} = zero(I)

# The formulation manager is an internal data structure that contains & manager
# all the elements which constitute a MILP formulation: variables, constraints,
# objective constant (costs stored in variables), coefficient matrix, 
# cut generators (that contain cut callbacks)...
mutable struct FormulationManager
    vars::Dict{VarId, Variable}
    constrs::Dict{ConstrId, Constraint}
    single_var_constrs::Dict{SingleVarConstrId, SingleVarConstraint}
    single_var_constrs_per_var::Dict{VarId, Dict{SingleVarConstrId, SingleVarConstraint}} # ids of the constraint of type : single variable >= bound
    objective_constant::Float64
    coefficients::ConstrVarMatrix # rows = constraints, cols = variables
    dual_sols::ConstrConstrMatrix # cols = dual solutions with constrid, rows = constrs
    dual_sols_varbounds::VarConstrDualSolMatrix # cols = dual solutions with constrid, rows = variables
    dual_sol_rhss::DynSparseVector{ConstrId} # dual solutions with constrid map to their rhs
    robust_constr_generators::Vector{RobustConstraintsGenerator}
    custom_families_id::Dict{DataType,Int}
end

function FormulationManager(; custom_families_id = Dict{BD.AbstractCustomData,Int}())
    vars = Dict{VarId, Variable}()
    constrs = Dict{ConstrId, Constraint}()
    return FormulationManager(
        vars,
        constrs,
        Dict{SingleVarConstrId, SingleVarConstraint}(),
        Dict{VarId, Dict{SingleVarConstrId, SingleVarConstraint}}(),
        0.0,
        dynamicsparse(ConstrId, VarId, Float64),
        dynamicsparse(ConstrId, ConstrId, Float64; fill_mode = false),
        dynamicsparse(VarId, ConstrId, Tuple{Float64, ActiveBound}; fill_mode = false),
        dynamicsparsevec(ConstrId[], Float64[]),
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

# Internal methods to store a Constraint or a SingleVarConstraint in the 
# formulation manager.
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

function _addconstr!(m::FormulationManager, constr::SingleVarConstraint)
    if !haskey(m.single_var_constrs_per_var, constr.varid)
        m.single_var_constrs_per_var[constr.varid] = Dict{ConstrId, SingleVarConstraint}()
    end
    if haskey(m.single_var_constrs_per_var[constr.varid], constr.id)
        name = m.single_var_constrs_per_var[constr.varid][constr.id].name
        error(string(
            "Constraint of id ", constr.id, "exists. Its name is ", name,
            " and you want to add a constraint named ", constr.name, "."
        ))
    end
    m.single_var_constrs[constr.id] = constr
    m.single_var_constrs_per_var[constr.varid][constr.id] = constr
    return
end

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

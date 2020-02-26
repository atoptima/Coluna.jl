const DynSparseVector{I} = DynamicSparseArrays.PackedMemoryArray{I, Float64} 

const VarDict = ElemDict{Id{Variable}, Variable}
const VarDataDict = Dict{Id{Variable}, VarData}
const ConstrDict = ElemDict{Id{Constraint}, Constraint}
const ConstrDataDict = Dict{Id{Constraint}, ConstrData}
const VarMembership = MembersVector{VarId,Variable,Float64}
const ConstrMembership = MembersVector{ConstrId,Constraint,Float64}

const ConstrVarMatrix = MembersMatrix{ConstrId,VarId,Float64}
const VarVarMatrix = MembersMatrix{VarId,VarId,Float64}

# Define the semaphore of the dynamic sparse matrix using MathProg.Id as index
DynamicSparseArrays.semaphore_key(::Type{I}) where {I <: Id} = zero(I)

const ConstrConstrMatrix = OldMembersMatrix{ConstrId,Constraint,ConstrId,Constraint,Float64}
const PrimalSolution{S} = Solution{Primal, S, Id{Variable}, Float64}
const DualSolution{S} = Solution{Dual, S, Id{Constraint}, Float64}
const PrimalBound{S} = Bound{Primal, S}
const DualBound{S} = Bound{Dual, S}

struct FormulationManager
    vars::VarDict
    constrs::ConstrDict
    var_datas::VarDataDict
    constr_datas::ConstrDataDict
    coefficients::ConstrVarMatrix # rows = constraints, cols = variables
    expressions::VarVarMatrix # cols = variables, rows = expressions
    primal_sols::VarVarMatrix # cols = primal solutions with varid, rows = variables 
    primal_sol_costs::DynSparseVector{VarId} # primal solutions with varid map to their cost
    dual_sols::ConstrConstrMatrix # cols = dual solutions with constrid, rows = constrs
    dual_sol_rhss::ConstrMembership # dual solutions with constrid map to their rhs
end

function FormulationManager()
    vars = VarDict()
    constrs = ConstrDict()
    return FormulationManager(
        vars,
        constrs,
        VarDataDict(),
        ConstrDataDict(),
        ConstrVarMatrix(),
        VarVarMatrix(),
        VarVarMatrix(),
        dynamicsparsevec(VarId[], Float64[]),
        OldMembersMatrix{Float64}(constrs,constrs),
        MembersVector{Float64}(constrs)
    )
end

haskey(m::FormulationManager, id::Id{Variable}) = haskey(m.vars, id)
haskey(m::FormulationManager, id::Id{Constraint}) = haskey(m.constrs, id)

function _addvar!(m::FormulationManager, var::Variable)
    haskey(m.vars, var.id) && error(string("Variable of id ", var.id, " exists"))
    m.vars[var.id] = var
    m.var_datas[var.id] = VarData(var.perene_data)
    return 
end


function _addconstr!(m::FormulationManager, constr::Constraint)
    haskey(m.constrs, constr.id) && error(string("Constraint of id ", constr.id, " exists"))
    m.constrs[constr.id] = constr
    m.constr_datas[constr.id] = ConstrData(constr.perene_data)
    return 
end

getvar(m::FormulationManager, id::VarId) = m.vars[id]
getconstr(m::FormulationManager, id::ConstrId) = m.constrs[id]
getvars(m::FormulationManager) = m.vars
getvardatas(m::FormulationManager) = m.vardatas
getconstrs(m::FormulationManager) = m.constrs
getcoefmatrix(m::FormulationManager) = m.coefficients
getexpressionmatrix(m::FormulationManager) = m.expressions
getprimalsolmatrix(m::FormulationManager) = m.primal_sols
getprimalsolcosts(m::FormulationManager) = m.primal_sol_costs
getdualsolmatrix(m::FormulationManager) =  m.dual_sols
getdualsolrhss(m::FormulationManager) =  m.dual_sol_rhss

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

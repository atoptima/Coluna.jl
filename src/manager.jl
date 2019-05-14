const VarDict = Dict{VarId,Variable}
const ConstrDict = Dict{ConstrId,Constraint}
const VarConstrDict = Union{VarDict,ConstrDict}
const VarMembership = MembersVector{VarId,Variable,Float64}
const ConstrMembership = MembersVector{ConstrId,Constraint,Float64}
const MembMatrix = MembersMatrix{VarId,Variable,ConstrId,Constraint,Float64}
const VarMatrix = MembersMatrix{VarId,Variable,VarId,Variable,Float64}
const ConstrMatrix = MembersMatrix{ConstrId,Constraint,ConstrId,Constraint,Float64}

struct FormulationManager
    vars::VarDict
    constrs::ConstrDict
    coefficients::MembMatrix # rows = constraints, cols = variables
    expressions::VarMatrix  # rows = expressions, cols = variables
    primal_sp_sols::VarMatrix # rows = sp vars, cols = DW master columns 
    dual_sp_sols::ConstrMatrix # rows = sp constrs, cols = Bend master cuts
end

function FormulationManager()
    vars = VarDict()
    constrs = ConstrDict()
    
    return FormulationManager(vars,
                              constrs,
                              MembersMatrix{Float64}(vars,constrs),
                              MembersMatrix{Float64}(vars,vars),
                              MembersMatrix{Float64}(vars,vars),
                              MembersMatrix{Float64}(constrs,constrs))
end

haskey(m::FormulationManager, id::Id{Variable}) = haskey(m.vars, id)

haskey(m::FormulationManager, id::Id{Constraint}) = haskey(m.constrs, id)

function addvar!(m::FormulationManager, var::Variable)
    haskey(m.vars, var.id) && error(string("Variable of id ", var.id, " exists"))
    m.vars[var.id] = var
    return var
end

function addprimalspsol!(m::FormulationManager, var::Variable)
     ### check if primalspsol exists should take place here along the coeff update
    return var
end

function adddualspsol!(m::FormulationManager, constr::Constraint)
     ### check if primalspsol exists should take place here along the coeff update
    return constr
end

function addconstr!(m::FormulationManager, constr::Constraint)
    haskey(m.constrs, constr.id) && error(string("Constraint of id ", constr.id, " exists"))
    m.constrs[constr.id] = constr
    return constr
end

getvar(m::FormulationManager, id::VarId) = m.vars[id]

getconstr(m::FormulationManager, id::ConstrId) = m.constrs[id]

getvars(m::FormulationManager) = m.vars

getconstrs(m::FormulationManager) = m.constrs

getcoefmatrix(m::FormulationManager) = m.coefficients

getexpressionmatrix(m::FormulationManager) = m.expressions

getprimalspsolmatrix(m::FormulationManager) = m.primal_sp_sols

getdualspsolmatrix(m::FormulationManager) = m.dual_sp_sols


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


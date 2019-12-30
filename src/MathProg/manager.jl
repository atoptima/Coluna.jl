const DynSparseVector{I} = PackedMemoryArray{I, Float64} 

const VarDict = ElemDict{Id{Variable}, Variable}
const ConstrDict = ElemDict{Id{Constraint}, Constraint}
const VarMembership = MembersVector{VarId,Variable,Float64}
const ConstrMembership = MembersVector{ConstrId,Constraint,Float64}
const VarVarMatrix = MembersMatrix{VarId,Variable,VarId,Variable,Float64}
const VarConstrMatrix = MembersMatrix{VarId,Variable,ConstrId,Constraint,Float64}
const ConstrVarMatrix = MembersMatrix{ConstrId,Constraint,VarId,Variable,Float64}
const ConstrConstrMatrix = MembersMatrix{ConstrId,Constraint,ConstrId,Constraint,Float64}

struct FormulationManager
    vars::VarDict
    constrs::ConstrDict
    var_costs::DynSparseVector{VarId}
    var_lbs::DynSparseVector{VarId}
    var_ubs::DynSparseVector{VarId}
    coefficients::VarConstrMatrix # cols = variables, rows = constraints
    expressions::VarVarMatrix # cols = variables, rows = expressions
    primal_sols::VarVarMatrix # cols = primal solutions with varid, rows = variables 
    primal_sol_costs::VarMembership # primal solutions with varid map to their cost
    dual_sols::ConstrConstrMatrix # cols = dual solutions with constrid, rows = constrs
    dual_sol_rhss::ConstrMembership # dual solutions with constrid map to their rhs
end

function FormulationManager()
    vars = VarDict()
    constrs = ConstrDict()
    
    return FormulationManager(vars,
                              constrs,
                              dynamicsparsevec(VarId[], Float64[]),
                              dynamicsparsevec(VarId[], Float64[]),
                              dynamicsparsevec(VarId[], Float64[]),
                              MembersMatrix{Float64}(vars,constrs),
                              MembersMatrix{Float64}(vars,vars),
                              MembersMatrix{Float64}(vars,vars),
                              MembersVector{Float64}(vars),
                              MembersMatrix{Float64}(constrs,constrs),
                              MembersVector{Float64}(constrs)
                              )
end

haskey(m::FormulationManager, id::Id{Variable}) = haskey(m.vars, id)
haskey(m::FormulationManager, id::Id{Constraint}) = haskey(m.constrs, id)

function addvar!(m::FormulationManager, var::Variable)
    haskey(m.vars, var.id) && error(string("Variable of id ", var.id, " exists"))
    m.vars[var.id] = var
    return var
end

function addprimalsol!(m::FormulationManager, 
                       sol::PrimalSolution{S},
                       sol_id::VarId
                       ) where {S<:AbstractObjSense}
    cost = 0.0
    for (var_id, var_val) in sol
        var = m.vars[var_id]
        cost += getperenecost(var) * var_val
        if getduty(var) <= DwSpSetupVar || getduty(var) <= DwSpPricingVar
            m.primal_sols[var_id, sol_id] = var_val
        end
    end
    m.primal_sol_costs[sol_id] = cost

    return sol_id
end

function adddualsol!(m::FormulationManager,
                     dualsol::DualSolution{S},
                     dualsol_id::ConstrId
                     ) where {S<:AbstractObjSense}

    rhs = 0.0
    for (constr_id, constr_val) in dualsol
        constr = m.constrs[constr_id]
        rhs += getperenerhs(constr) * constr_val 
        if getduty(constr) <= AbstractBendSpMasterConstr
            m.dual_sols[constr_id, dualsol_id] = constr_val
        end
    end
    m.dual_sol_rhss[dualsol_id] = rhs
    
    return dualsol_id
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

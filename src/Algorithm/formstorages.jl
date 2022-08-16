"""
    VarState

Used in formulation records
"""
struct VarState
    cost::Float64
    lb::Float64
    ub::Float64
end

function apply_data!(form::Formulation, var::Variable, var_state::VarState)
    # Bounds
    if getcurlb(form, var) != var_state.lb || getcurub(form, var) != var_state.ub
        @logmsg LogLevel(-2) string("Reseting bounds of variable ", getname(form, var))
        setcurlb!(form, var, var_state.lb)
        setcurub!(form, var, var_state.ub)
        @logmsg LogLevel(-3) string("New lower bound is ", getcurlb(form, var))
        @logmsg LogLevel(-3) string("New upper bound is ", getcurub(form, var))
    end
    # Cost
    if getcurcost(form, var) != var_state.cost
        @logmsg LogLevel(-2) string("Reseting cost of variable ", getname(form, var))
        setcurcost!(form, var, var_state.cost)
        @logmsg LogLevel(-3) string("New cost is ", getcurcost(form, var))
    end
    return
end

"""
    ConstrState

Used in formulation records
"""
struct ConstrState
    rhs::Float64
end

function apply_data!(form::Formulation, constr::Constraint, constr_state::ConstrState)
    # Rhs
    if getcurrhs(form, constr) != constr_state.rhs
        @logmsg LogLevel(-2) string("Reseting rhs of constraint ", getname(form, constr))
        setcurrhs!(form, constr, constr_state.rhs)
        @logmsg LogLevel(-3) string("New rhs is ", getcurrhs(form, constr))
    end
    return
end


"""
    MasterBranchConstrsUnit

Unit for master branching constraints. 
Can be restored using MasterBranchConstrsRecord.    
"""
struct MasterBranchConstrsUnit <: AbstractNewStorageUnit end

mutable struct MasterBranchConstrsRecord <: AbstractNewRecord
    constrs::Dict{ConstrId,ConstrState}
end

ClB.new_storage_unit(::Type{MasterBranchConstrsUnit}, _) = MasterBranchConstrsUnit()

function ClB.new_record(::Type{MasterBranchConstrsRecord}, id::Int, form::Formulation, unit::MasterBranchConstrsUnit)
    @logmsg LogLevel(-2) "Storing branching constraints"
    record = MasterBranchConstrsRecord(Dict{ConstrId,ConstrState}())
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterBranchingConstr && 
           iscuractive(form, constr) && isexplicit(form, constr)
            
            constrstate = ConstrState(getcurrhs(form, constr))
            record.constrs[id] = constrstate
        end
    end
    return record
end

ClB.record_type(::Type{MasterBranchConstrsUnit}) = MasterBranchConstrsRecord
ClB.storage_unit_type(::Type{MasterBranchConstrsRecord}) = MasterBranchConstrsUnit

function ClB.restore_from_record!(
    form::Formulation, ::MasterBranchConstrsUnit, record::MasterBranchConstrsRecord
)
    @logmsg LogLevel(-2) "Restoring branching constraints"
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterBranchingConstr && isexplicit(form, constr)
            @logmsg LogLevel(-4) "Checking " getname(form, constr)
            if haskey(record.constrs, id) 
                if !iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Activating branching constraint", getname(form, constr))
                    activate!(form, constr)
                else    
                    @logmsg LogLevel(-2) string("Leaving branching constraint", getname(form, constr))
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, constr, record.constrs[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Deactivating branching constraint", getname(form, constr))
                    deactivate!(form, constr)
                end
            end    
        end
    end
end

"""
    MasterColumnsUnit

Unit for branching constraints of a formulation. 
Can be restored using a MasterColumnsRecord.    
"""
struct MasterColumnsUnit <: AbstractNewStorageUnit end

mutable struct MasterColumnsRecord <: AbstractNewRecord
    cols::Dict{VarId,VarState}
end

ClB.new_storage_unit(::Type{MasterColumnsUnit}, _) = MasterColumnsUnit()

function ClB.new_record(::Type{MasterColumnsRecord}, id::Int, form::Formulation, unit::MasterColumnsUnit)
    @logmsg LogLevel(-2) "Storing master columns"
    record = MasterColumnsRecord(Dict{VarId,ConstrState}())
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && 
           iscuractive(form, var) && isexplicit(form, var)
            
            varstate = VarState(getcurcost(form, var), getcurlb(form, var), getcurub(form, var))
            record.cols[id] = varstate
        end
    end
    return record
end

ClB.record_type(::Type{MasterColumnsUnit}) = MasterColumnsRecord
ClB.storage_unit_type(::Type{MasterColumnsRecord}) = MasterColumnsUnit

function ClB.restore_from_record!(
    form::Formulation, ::MasterColumnsUnit, state::MasterColumnsRecord
)
    @logmsg LogLevel(-2) "Restoring master columns"
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && isexplicit(form, var)
            @logmsg LogLevel(-4) "Checking " getname(form, var)
            if haskey(state.cols, id) 
                if !iscuractive(form, var) 
                    @logmsg LogLevel(-4) string("Activating column", getname(form, var))
                    activate!(form, var)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, var, state.cols[id])
            else
                if iscuractive(form, var) 
                    @logmsg LogLevel(-4) string("Deactivating column", getname(form, var))
                    deactivate!(form, var)
                end
            end    
        end
    end
end

"""
    MasterCutsUnit

Unit for cutting planes of a formulation. 
Can be restored using a MasterCutsRecord.    
"""
struct MasterCutsUnit <: AbstractNewStorageUnit end

MasterCutsUnit(::Formulation) = MasterCutsUnit()

mutable struct MasterCutsRecord <: AbstractNewRecord
    cuts::Dict{ConstrId,ConstrState}
end

ClB.new_storage_unit(::Type{MasterCutsUnit}, _) = MasterCutsUnit()

function ClB.new_record(::Type{MasterCutsRecord}, id::Int, form::Formulation, unit::MasterCutsUnit)
    @logmsg LogLevel(-2) "Storing master cuts"
    record = MasterCutsRecord(Dict{ConstrId,ConstrState}())
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterCutConstr && 
           iscuractive(form, constr) && isexplicit(form, constr)
            
            constrstate = ConstrState(getcurrhs(form, constr))
            record.cuts[id] = constrstate
        end
    end
    return record
end

ClB.record_type(::Type{MasterCutsUnit}) = MasterCutsRecord
ClB.storage_unit_type(::Type{MasterCutsRecord}) = MasterCutsUnit

function ClB.restore_from_record!(
    form::Formulation, ::MasterCutsUnit, state::MasterCutsRecord
)
    @logmsg LogLevel(-2) "Storing master cuts"
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterCutConstr && isexplicit(form, constr)
            @logmsg LogLevel(-4) "Checking " getname(form, constr)
            if haskey(state.cuts, id) 
                if !iscuractive(form, constr) 
                    @logmsg LogLevel(-4) string("Activating cut", getname(form, constr))
                    activate!(form, constr)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, constr, state.cuts[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-4) string("Deactivating cut", getname(form, constr))
                    deactivate!(form, constr)
                end
            end    
        end
    end
end



##### UNCOVERED CODE BELOW #####

# """
#     StaticVarConstrUnit

# Unit for static variables and constraints of a formulation.
# Can be restored using a StaticVarConstrRecord.    
# """

# struct StaticVarConstrUnit <: AbstractStorageUnit end

# StaticVarConstrUnit(::Formulation) = StaticVarConstrUnit()

# mutable struct StaticVarConstrRecord <: AbstractRecord
#     constrs::Dict{ConstrId,ConstrState}
#     vars::Dict{VarId,VarState}
# end

# # TO DO: we need to keep here only the difference with the initial data

# function Base.show(io::IO, record::StaticVarConstrRecord)
#     print(io, "[vars:")
#     for (id, var) in record.vars
#         print(io, " ", MathProg.getuid(id))
#     end
#     print(io, ", constrs:")
#     for (id, constr) in record.constrs
#         print(io, " ", MathProg.getuid(id))
#     end
#     print(io, "]")
# end

# function StaticVarConstrRecord(form::Formulation, unit::StaticVarConstrUnit)
#     @logmsg LogLevel(-2) string("Storing static vars and consts")
#     record = StaticVarConstrRecord(Dict{ConstrId,ConstrState}(), Dict{VarId,VarState}())
#     for (id, constr) in getconstrs(form)
#         if isaStaticDuty(getduty(id)) && iscuractive(form, constr) && isexplicit(form, constr)            
#             constrstate = ConstrState(getcurrhs(form, constr))
#             record.constrs[id] = constrstate
#         end
#     end
#     for (id, var) in getvars(form)
#         if isaStaticDuty(getduty(id)) && iscuractive(form, var) && isexplicit(form, var)            
#             varstate = VarState(getcurcost(form, var), getcurlb(form, var), getcurub(form, var))
#             record.vars[id] = varstate
#         end
#     end
#     return record
# end

# function ColunaBase.restore_from_record!(
#     form::Formulation, unit::StaticVarConstrUnit, record::StaticVarConstrRecord
# )
#     @logmsg LogLevel(-2) "Restoring static vars and consts"
#     for (id, constr) in getconstrs(form)
#         if isaStaticDuty(getduty(id)) && isexplicit(form, constr)
#             @logmsg LogLevel(-4) "Checking " getname(form, constr)
#             if haskey(record.constrs, id) 
#                 if !iscuractive(form, constr) 
#                     @logmsg LogLevel(-2) string("Activating constraint", getname(form, constr))
#                     activate!(form, constr)
#                 end
#                 @logmsg LogLevel(-4) "Updating data"
#                 apply_data!(form, constr, record.constrs[id])
#             else
#                 if iscuractive(form, constr) 
#                     @logmsg LogLevel(-2) string("Deactivating constraint", getname(form, constr))
#                     deactivate!(form, constr)
#                 end
#             end    
#         end
#     end
#     for (id, var) in getvars(form)
#         if isaStaticDuty(getduty(id)) && isexplicit(form, var)
#             @logmsg LogLevel(-4) "Checking " getname(form, var)
#             if haskey(record.vars, id) 
#                 if !iscuractive(form, var) 
#                     @logmsg LogLevel(-4) string("Activating variable", getname(form, var))
#                     activate!(form, var)
#                 end
#                 @logmsg LogLevel(-4) "Updating data"
#                 apply_data!(form, var, record.vars[id])
#             else
#                 if iscuractive(form, var) 
#                     @logmsg LogLevel(-4) string("Deactivating variable", getname(form, var))
#                     deactivate!(form, var)
#                 end
#             end    
#         end
#     end
# end

# ColunaBase.record_type(::Type{StaticVarConstrUnit}) = StaticVarConstrRecord



# Seems like uncovered but used ...

"""
    PartialSolutionUnit

Unit for partial solution of a formulation.
Can be restored using a PartialSolutionRecord.    
"""

# TO DO : to replace dictionaries by PrimalSolution
# issues to see : 1) PrimalSolution is parametric; 2) we need a solution concatenation functionality

mutable struct PartialSolutionUnit <: AbstractNewStorageUnit
    solution::Dict{VarId,Float64}
end

# the record is the same as the record here
mutable struct PartialSolutionRecord <: AbstractNewRecord
    solution::Dict{VarId,Float64}
end

ClB.new_storage_unit(::Type{PartialSolutionUnit}, _) = PartialSolutionUnit(Dict{VarId,Float64}())

function ClB.new_record(::Type{PartialSolutionRecord}, _::Int, _, unit::PartialSolutionUnit)
    @logmsg LogLevel(-2) "Storing partial solution"
    return PartialSolutionRecord(copy(unit.solution))
end

ClB.record_type(::Type{PartialSolutionUnit}) = PartialSolutionRecord
ClB.storage_unit_type(::Type{PartialSolutionRecord}) = PartialSolutionUnit

function ClB.restore_from_record!(
    ::Formulation, unit::PartialSolutionUnit, record::PartialSolutionRecord
)
    @logmsg LogLevel(-2) "Restoring partial solution"
    unit.solution = copy(record.solution)
end

# Remove methods below.
function add_to_solution!(unit::PartialSolutionUnit, varid::VarId, value::Float64)
    cur_value = get(unit.solution, varid, 0.0)
    unit.solution[varid] = cur_value + value
    return
end

function get_primal_solution(unit::PartialSolutionUnit, form::Formulation)
    varids = collect(keys(unit.solution))
    vals = collect(values(unit.solution))
    solcost = 0.0
    for (varid, value) in unit.solution
        solcost += getcurcost(form, varid) * value
    end
    return PrimalSolution(form, varids, vals, solcost, UNKNOWN_FEASIBILITY)
end    

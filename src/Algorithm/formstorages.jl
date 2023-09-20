"""
    VarState

Used in formulation records
"""
struct VarState
    cost::Float64
    lb::Float64
    ub::Float64
    partial_sol_value::Float64
end

function apply_state!(form::Formulation, var::Variable, var_state::VarState)
    # TODO: remove
    # To avoid warnings when changing variable bounds.
    var.curdata.is_in_partial_sol = false

    if getcurlb(form, var) != var_state.lb
        setcurlb!(form, var, var_state.lb)
    end
    if getcurub(form, var) != var_state.ub
        setcurub!(form, var, var_state.ub)
    end
    if getcurcost(form, var) != var_state.cost
        setcurcost!(form, var, var_state.cost)
    end
    if MathProg.get_value_in_partial_sol(form, var) != var_state.partial_sol_value
        if var_state.partial_sol_value == 0
            var.curdata.is_in_partial_sol = false
        else
            var.curdata.is_in_partial_sol = true
        end
        MathProg.set_value_in_partial_solution!(form, var, var_state.partial_sol_value)
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

function apply_state!(form::Formulation, constr::Constraint, constr_state::ConstrState)
    if getcurrhs(form, constr) != constr_state.rhs
        setcurrhs!(form, constr, constr_state.rhs)
    end
    return
end


"""
    MasterBranchConstrsUnit

Unit for master branching constraints. 
Can be restored using MasterBranchConstrsRecord.    
"""
struct MasterBranchConstrsUnit <: AbstractRecordUnit end

mutable struct MasterBranchConstrsRecord <: AbstractRecord
    constrs::Dict{ConstrId,ConstrState}
end

struct MasterBranchConstrsKey <: AbstractStorageUnitKey end

key_from_storage_unit_type(::Type{MasterBranchConstrsUnit}) = MasterBranchConstrsKey()
record_type_from_key(::MasterBranchConstrsKey) = MasterBranchConstrsRecord

ClB.storage_unit(::Type{MasterBranchConstrsUnit}, _) = MasterBranchConstrsUnit()

function ClB.record(::Type{MasterBranchConstrsRecord}, id::Int, form::Formulation, unit::MasterBranchConstrsUnit)
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
                apply_state!(form, constr, record.constrs[id])
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
struct MasterColumnsUnit <: AbstractRecordUnit end

mutable struct MasterColumnsRecord <: AbstractRecord
    cols::Dict{VarId,VarState}
end

struct MasterColumnsKey <: AbstractStorageUnitKey end

key_from_storage_unit_type(::Type{MasterColumnsUnit}) = MasterColumnsKey()
record_type_from_key(::MasterColumnsKey) = MasterColumnsRecord

ClB.storage_unit(::Type{MasterColumnsUnit}, _) = MasterColumnsUnit()

function ClB.record(::Type{MasterColumnsRecord}, id::Int, form::Formulation, unit::MasterColumnsUnit)
    record = MasterColumnsRecord(Dict{VarId,ConstrState}())
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && isexplicit(form, var) && iscuractive(form, var)
            varstate = VarState(
                getcurcost(form, var),
                getcurlb(form, var),
                getcurub(form, var),
                MathProg.get_value_in_partial_sol(form, var)
            )
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
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && isexplicit(form, var)
            if haskey(state.cols, id) 
                if !iscuractive(form, var)
                    activate!(form, var)
                end
                apply_state!(form, var, state.cols[id])
            else
                if iscuractive(form, var) 
                    deactivate!(form, var)
                end
            end    
        end
    end
    return
end

"""
    MasterCutsUnit

Unit for cutting planes of a formulation. 
Can be restored using a MasterCutsRecord.    
"""
struct MasterCutsUnit <: AbstractRecordUnit end

MasterCutsUnit(::Formulation) = MasterCutsUnit()

mutable struct MasterCutsRecord <: AbstractRecord
    cuts::Dict{ConstrId,ConstrState}
end

struct MasterCutsKey <: AbstractStorageUnitKey end

key_from_storage_unit_type(::Type{MasterCutsUnit}) = MasterCutsKey()
record_type_from_key(::MasterCutsKey) = MasterCutsRecord

ClB.storage_unit(::Type{MasterCutsUnit}, _) = MasterCutsUnit()

function ClB.record(::Type{MasterCutsRecord}, id::Int, form::Formulation, unit::MasterCutsUnit)
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
                apply_state!(form, constr, state.cuts[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-4) string("Deactivating cut", getname(form, constr))
                    deactivate!(form, constr)
                end
            end    
        end
    end
end

"""
    StaticVarConstrUnit

Unit for static variables and constraints of a formulation.
Can be restored using a StaticVarConstrRecord.    
"""

struct StaticVarConstrUnit <: AbstractRecordUnit end

StaticVarConstrUnit(::Formulation) = StaticVarConstrUnit()

mutable struct StaticVarConstrRecord <: AbstractRecord
    constrs::Dict{ConstrId,ConstrState}
    vars::Dict{VarId,VarState}
end

# TO DO: we need to keep here only the difference with the initial data

struct StaticVarConstrKey <: AbstractStorageUnitKey end

key_from_storage_unit_type(::Type{StaticVarConstrUnit}) = StaticVarConstrKey()
record_type_from_key(::StaticVarConstrKey) = StaticVarConstrRecord

ClB.storage_unit(::Type{StaticVarConstrUnit}, _) = StaticVarConstrUnit()

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

function ClB.record(::Type{StaticVarConstrRecord}, id::Int, form::Formulation, unit::StaticVarConstrUnit)
    @logmsg LogLevel(-2) string("Storing static vars and consts")
    record = StaticVarConstrRecord(Dict{ConstrId,ConstrState}(), Dict{VarId,VarState}())
    for (id, constr) in getconstrs(form)
        if isaStaticDuty(getduty(id)) && iscuractive(form, constr) && isexplicit(form, constr) 
            constrstate = ConstrState(getcurrhs(form, constr))
            record.constrs[id] = constrstate
        end
    end
    for (id, var) in getvars(form)
        if isaStaticDuty(getduty(id)) && isexplicit(form, var) && iscuractive(form, var)          
            varstate = VarState(
                getcurcost(form, var), 
                getcurlb(form, var), 
                getcurub(form, var),
                MathProg.get_value_in_partial_sol(form, var)
            )
            record.vars[id] = varstate
        end
    end
    return record
end

ClB.record_type(::Type{StaticVarConstrUnit}) = StaticVarConstrRecord
ClB.storage_unit_type(::Type{StaticVarConstrRecord}) = StaticVarConstrUnit

function ClB.restore_from_record!(
    form::Formulation, ::StaticVarConstrUnit, record::StaticVarConstrRecord
)
    @logmsg LogLevel(-2) "Restoring static vars and consts"
    for (id, constr) in getconstrs(form)
        if isaStaticDuty(getduty(id)) && isexplicit(form, constr)
            @logmsg LogLevel(-4) "Checking " getname(form, constr)
            if haskey(record.constrs, id) 
                if !iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Activating constraint", getname(form, constr))
                    activate!(form, constr)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_state!(form, constr, record.constrs[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Deactivating constraint", getname(form, constr))
                    deactivate!(form, constr)
                end
            end    
        end
    end
    for (id, var) in getvars(form)
        if isaStaticDuty(getduty(id)) && isexplicit(form, var)
            @logmsg LogLevel(-4) "Checking " getname(form, var)
            if haskey(record.vars, id) 
                if !iscuractive(form, var) #&& !isfixed(form, var)
                    @logmsg LogLevel(-4) string("Activating variable", getname(form, var))
                    activate!(form, var)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_state!(form, var, record.vars[id])
            else
                if iscuractive(form, var) 
                    @logmsg LogLevel(-4) string("Deactivating variable", getname(form, var))
                    deactivate!(form, var)
                end
            end    
        end
    end
end

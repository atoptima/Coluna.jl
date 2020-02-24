# using ..Coluna # to comment when merging to the master branch

"""
    AbstractRecord

    Record is a used to recover the state of a storage or a formulation in a different node of a search tree
"""
abstract type AbstractRecord end

struct EmptyRecord <: AbstractRecord end

# function getrootrecord(storage::AbstractStorage)::AbstractRecord
#     return EmptyRecord()
# end 

"""
    prepare!(Storage, Record)

    This function recovers the state of Storage using Record    
"""
prepare!(storage::AbstractStorage, ::Nothing) = nothing

function prepare!(storage::AbstractStorage, record::AbstractRecord) 
    storagetype = typeof(storage)
    recordtype = typeof(record)
    error("Method prepare!(storage, record) which takes is not implemented for storage $storagetype.
           and for record $recordtype")
end

prepare!(storage::EmptyStorage, record::EmptyRecord) = nothing

"""
    record(Storage)::Record

    This function records the state of Storage to Record. By default, the record is empty.
"""
function record(storage::AbstractStorage)::AbstractRecord
    return EmptyRecord()
end 

struct VarState
    cost::Float64
    lb::Float64
    ub::Float64
end

struct ConstrState
    rhs::Float64
end

# TO DO : to rewrite ReformulationRecord
struct ReformulationRecord
    active_vars::Dict{VarId, VarState}
    active_constrs::Dict{ConstrId, ConstrState}
end
ReformulationRecord() = ReformulationRecord(Dict{VarId, VarState}(), Dict{ConstrId, ConstrState}())

mutable struct FormulationStatus
    need_to_prepare::Bool
    proven_infeasible::Bool
end
FormulationStatus() = FormulationStatus(true, false)

function add_to_recorded!(reform::Reformulation, record::ReformulationRecord)
    @logmsg LogLevel(0) "Recording master info."
    add_to_recorded!(getmaster(reform), record)
    for (spuid, spform) in get_dw_pricing_sps(reform)
        @logmsg LogLevel(0) string("Recording sp ", spuid, " info.")
        add_to_recorded!(spform, record)
    end
    return
end

function add_to_recorded!(form::Formulation, record::ReformulationRecord)
    for (id, var) in getvars(form)
        if getcurisactive(form, var) && getcurisexplicit(form, var)
            varstate = VarState(getcurcost(form, var), getcurlb(form, var), getcurub(form, var))
            record.active_vars[id] = varstate
        end
    end
    for (id, constr) in getconstrs(form)
        if getcurisactive(form, constr) && getcurisexplicit(form, constr)
            constrstate = ConstrState(getcurrhs(form, constr))
            record.active_constrs[id] = constrstate
        end
    end
    return
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

function apply_data!(form::Formulation, constr::Constraint, constr_state::ConstrState)
    # Rhs
    if getcurrhs(form, constr) != constr_state.rhs
        @logmsg LogLevel(-2) string("Reseting rhs of constraint ", getname(form, constr))
        setrhs!(form, constr, constr_state.rhs)
        @logmsg LogLevel(-3) string("New rhs is ", getcurrhs(form, constr))
    end
    return
end

function reset_var_constr!(form::Formulation, active_var_constrs, var_constrs_in_formulation)
    for (id, vc) in var_constrs_in_formulation
        @logmsg LogLevel(-4) "Checking " getname(form, vc)
        # vc should NOT be active but is active in formulation
        if !haskey(active_var_constrs, id) && getcurisactive(form, vc)
            @logmsg LogLevel(-4) "Deactivating"
            deactivate!(form, id)
            continue
        end
        # vc should be active in formulation
        if haskey(active_var_constrs, id)
            # But var_constr is currently NOT active in formulation
            if !getcurisactive(form, vc)
                @logmsg LogLevel(-4) "Activating"
                activate!(form, vc)
            end
            # After making sure that var activity is up-to-date
            @logmsg LogLevel(-4) "Updating data"
            apply_data!(form, vc, active_var_constrs[id])
        end
    end
    return
end

function prepare!(form::Formulation, record::ReformulationRecord)
    @logmsg LogLevel(-2) "Checking variables"
    reset_var_constr!(form, record.active_vars, getvars(form))
    @logmsg LogLevel(-2) "Checking constraints"
    reset_var_constr!(form, record.active_constrs, getconstrs(form))
    return
end

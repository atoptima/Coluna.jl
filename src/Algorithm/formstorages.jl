"""
    VarState

    Used in formulation storages
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

    Used in formulation storages
"""

struct ConstrState
    rhs::Float64
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

"""
    BranchingConstrsStorage

    Storage for branching constraints of a formulation. 
    Consists of EmptyStorage and BranchingConstrState.    
"""

mutable struct BranchingConstrsState <: AbstractStorageState
    constrs::Dict{ConstrId, ConstrState}
end

function BranchingConstrsState(form::Formulation, storage::EmptyStorage)
    @logmsg LogLevel(-2) "Storing branching constraints"
    state = BranchingConstrState(Dict{ConstrId, ConstrState}())
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterBranchingConstr && 
           iscuractive(form, constr) && iscurexplicit(form, constr)
            
            constrstate = ConstrState(getcurrhs(form, constr))
            state.constrs[id] = constrstate
        end
    end
    return state
end

function restorefromstate!(
    form::Formulation, storage::EmptyStorage, state::BranchingConstrsState
)
    @logmsg LogLevel(-2) "Restoring branching constraints"
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterBranchingConstr && iscurexplicit(form, constr)
            @logmsg LogLevel(-4) "Checking " getname(form, constr)
            if haskey(state.constrs, id) 
                if !iscuractive(form, constr) 
                    @logmsg LogLevel(-4) "Activating"
                    activate!(form, constr)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, constr, state.constrs[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-4) "Deactivating"
                    deactivate!(form, id)
                end
            end    
        end
    end
end

BranchingConstrsStorage = (EmptyStorage, BranchingConstrsState)

"""
    MasterColumnsStorage

    Storage for branching constraints of a formulation. 
    Consists of EmptyStorage and BranchingConstrState.    
"""

mutable struct MasterColumnsState <: AbstractStorageState
    cols::Dict{VarId, VarState}
end

function MasterColumnsState(form::Formulation, storage::EmptyStorage)
    @logmsg LogLevel(-2) "Storing master columns"
    state = MasterColumnsState(Dict{VarId, ConstrState}())
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && 
           iscuractive(form, var) && iscurexplicit(form, var)
            
            varstate = VarState(getcurrhs(form, var))
            state.cols[id] = varstate
        end
    end
    return state
end

function restorefromstate!(
    form::Formulation, storage::EmptyStorage, state::MasterColumnsState
)
    @logmsg LogLevel(-2) "Restoring master columns"
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && iscurexplicit(form, var)
            @logmsg LogLevel(-4) "Checking " getname(form, var)
            if haskey(state.constrs, id) 
                if !iscuractive(form, var) 
                    @logmsg LogLevel(-4) "Activating"
                    activate!(form, var)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, var, state.constrs[id])
            else
                if iscuractive(form, var) 
                    @logmsg LogLevel(-4) "Deactivating"
                    deactivate!(form, id)
                end
            end    
        end
    end
end

MasterColumnsStorage = (EmptyStorage, MasterColumnsState)

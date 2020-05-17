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
    MasterBranchConstrsStorage

    Storage for master branching constraints. 
    Consists of EmptyStorage and MasterBranchConstrsStorageState.    
"""

mutable struct MasterBranchConstrsStorageState <: AbstractStorageState
    constrs::Dict{ConstrId, ConstrState}
end

function Base.show(io::IO, state::MasterBranchConstrsStorageState)
    print(io, "[")
    for (id, constr) in state.constrs
        print(io, " ", MathProg.getuid(id))
    end
    print(io, "]")
end

function MasterBranchConstrsStorageState(form::Formulation, storage::EmptyStorage)
    @logmsg LogLevel(-2) "Storing branching constraints"
    state = MasterBranchConstrsStorageState(Dict{ConstrId, ConstrState}())
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterBranchingConstr && 
           iscuractive(form, constr) && isexplicit(form, constr)
            
            constrstate = ConstrState(getcurrhs(form, constr))
            state.constrs[id] = constrstate
        end
    end
    return state
end

function restorefromstate!(
    form::Formulation, storage::EmptyStorage, state::MasterBranchConstrsStorageState
)
    @logmsg LogLevel(-2) "Restoring branching constraints"
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterBranchingConstr && isexplicit(form, constr)
            @logmsg LogLevel(-4) "Checking " getname(form, constr)
            if haskey(state.constrs, id) 
                if !iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Activating branching constraint", getname(form, constr))
                    activate!(form, constr)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, constr, state.constrs[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Deactivating branching constraint", getname(form, constr))
                    deactivate!(form, id)
                end
            end    
        end
    end
end

const MasterBranchConstrsStorage = (EmptyStorage => MasterBranchConstrsStorageState)

"""
    MasterColumnsStorage

    Storage for branching constraints of a formulation. 
    Consists of EmptyStorage and MasterColumnsState.    
"""

mutable struct MasterColumnsState <: AbstractStorageState
    cols::Dict{VarId, VarState}
end

function Base.show(io::IO, state::MasterColumnsState)
    print(io, "[")
    for (id, val) in state.cols
        print(io, " ", MathProg.getuid(id))
    end
    print(io, "]")
end

function MasterColumnsState(form::Formulation, storage::EmptyStorage)
    @logmsg LogLevel(-2) "Storing master columns"
    state = MasterColumnsState(Dict{VarId, ConstrState}())
    for (id, var) in getvars(form)
        if getduty(id) <= MasterCol && 
           iscuractive(form, var) && isexplicit(form, var)
            
            varstate = VarState(getcurcost(form, var), getcurlb(form, var), getcurub(form, var))
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
                    deactivate!(form, id)
                end
            end    
        end
    end
end

const MasterColumnsStorage = (EmptyStorage => MasterColumnsState)

"""
    MasterCutsStorage

    Storage for cutting planes of a formulation. 
    Consists of EmptyStorage and MasterCutsState.    
"""

mutable struct MasterCutsState <: AbstractStorageState
    cuts::Dict{ConstrId, ConstrState}
end

function Base.show(io::IO, state::MasterCutsState)
    print(io, "[")
    for (id, constr) in state.cuts
        print(io, " ", MathProg.getuid(id))
    end
    print(io, "]")
end

function MasterCutsState(form::Formulation, storage::EmptyStorage)
    @logmsg LogLevel(-2) "Storing master cuts"
    state = BranchingConstrsState(Dict{ConstrId, ConstrState}())
    for (id, constr) in getconstrs(form)
        if getduty(id) <= AbstractMasterCutConstr && 
           iscuractive(form, constr) && isexplicit(form, constr)
            
            constrstate = ConstrState(getcurrhs(form, constr))
            state.cuts[id] = constrstate
        end
    end
    return state
end

function restorefromstate!(
    form::Formulation, storage::EmptyStorage, state::MasterCutsState
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
                    deactivate!(form, id)
                end
            end    
        end
    end
end

const MasterCutsStorage = (EmptyStorage => MasterCutsState)

"""
    StaticVarConstrStorage

    Storage for static variables and constraints of a formulation.
    Consists of EmptyStorage and StaticVarConstrStorageState.    
"""

mutable struct StaticVarConstrStorageState <: AbstractStorageState
    constrs::Dict{ConstrId, ConstrState}
    vars::Dict{ConstrId, ConstrState}
end

#TO DO: we need to keep here only the difference with the initial data

function Base.show(io::IO, state::StaticVarConstrStorageState)
    print(io, "[vars:")
    for (id, var) in state.vars
        print(io, " ", MathProg.getuid(id))
    end
    print(io, ", constrs:")
    for (id, constr) in state.constrs
        print(io, " ", MathProg.getuid(id))
    end
    print(io, "]")
end

function StaticVarConstrStorageState(form::Formulation, storage::EmptyStorage)
    @logmsg LogLevel(-2) string("Storing static vars and consts")
    state = BranchingConstrsState(Dict{ConstrId, ConstrState}(), Dict{ConstrId, VarState}())
    for (id, constr) in getconstrs(form)
        if !(getduty(id) <= AbstractMasterCutConstr) && 
           !(getduty(id) <= AbstractMasterBranchingConstr) &&
           iscuractive(form, constr) && isexplicit(form, constr)
            
            constrstate = ConstrState(getcurrhs(form, constr))
            state.constrs[id] = constrstate
        end
    end
    for (id, var) in getvars(form)
        if !(getduty(id) <= MasterCol) && 
           iscuractive(form, var) && isexplicit(form, var)
            
            varstate = VarState(getcurcost(form, var), getcurlb(form, var), getcurub(form, var))
            state.vars[id] = varstate
        end
    end
    return state
end

function restorefromstate!(
    form::Formulation, storage::EmptyStorage, state::StaticVarConstrStorageState
)
    @logmsg LogLevel(-2) "Restoring static vars and consts"
    for (id, constr) in getconstrs(form)
        if !(getduty(id) <= AbstractMasterCutConstr) && 
           !(getduty(id) <= AbstractMasterBranchingConstr) && isexplicit(form, constr)
            @logmsg LogLevel(-4) "Checking " getname(form, constr)
            if haskey(state.constrs, id) 
                if !iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Activating constraint", getname(form, constr))
                    activate!(form, constr)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, constr, state.constrs[id])
            else
                if iscuractive(form, constr) 
                    @logmsg LogLevel(-2) string("Deactivating constraint", getname(form, constr))
                    deactivate!(form, id)
                end
            end    
        end
    end
    for (id, var) in getvars(form)
        if !(getduty(id) <= MasterCol) && isexplicit(form, var)
            @logmsg LogLevel(-4) "Checking " getname(form, var)
            if haskey(state.vars, id) 
                if !iscuractive(form, var) 
                    @logmsg LogLevel(-4) string("Activating variable", getname(form, var))
                    activate!(form, var)
                end
                @logmsg LogLevel(-4) "Updating data"
                apply_data!(form, var, state.vars[id])
            else
                if iscuractive(form, var) 
                    @logmsg LogLevel(-4) string("Deactivating variable", getname(form, var))
                    deactivate!(form, id)
                end
            end    
        end
    end
end

const StaticVarConstrStorage = (EmptyStorage => StaticVarConstrStorageState)

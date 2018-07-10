
type VarMpFormIndexStatus{V<:Variable}
    variable::V
    statusinbasicsol::Int
end

type ConstrMpFormIndexStatus{C<:Constraint}
    constraint::C
    statusinbasicsol::Int
end

type LpBasisRecord
    name::String
    varsinbasis::Vector{VarMpFormIndexStatus}
    const:rsinbasis::Vector{ConstrMpFormIndexStatus}
end

LpBasisRecord(name::String) = LpBasisRecord(name, Vector{VarMpFormIndexStatus}(), Vector{ConstrMpFormIndexStatus}())
LpBasisRecord() = LpBasisRecord("basis")

function clear(basis::LpBasisRecord; removemarksinvars=true, removemarksinconstrs=true)::Void
    if removemarksinvars
        for var in varsinbasis
            var.isinfoupdated = false
        end
        empty!(basis.varsinbasis)
    end

    if removemarksinconstrs
        for constr in constrinbasis
            constr.isinfoupdated = false
        end
        empty!(basis.constrsinbasis)
    end
    return
end

# needed for partial solution
type VariableSolInfo{V<:Variable}
    variable::V
    value::Float
end

function applyvarinfo(varsolinfo::VariableSolInfo)::Void
    variable = varsolinfo.variable
    value = varsolinfo.value
    problem = variable.problem
    updatepartialsolution(problem,variable,value)
end

# TODO: impl properly the var/constr manager
abstract type AbstractVarIndexManager end
abstract type AbstractConstrIndexManager end

type SimpleVarIndexManager <: AbstractVarIndexManager
    activestaticlist::Vector{Variable}
    activedynamiclist::Vector{Variable}
    unsuitablestaticlist::Vector{Variable}
    unsuitabledynamiclist::Vector{Variable}
end

SimpleVarIndexManager() = SimpleVarIndexManager(Vector{Variable}(), Vector{Variable}(), Vector{Variable}(), Vector{Variable}())

function addinvarmanager(varmanager::SimpleVarIndexManager, var::Variable)
    if var.status == Active && var.flag == 's'
        list = varmanager.activestaticlist
    elseif var.status == Active && var.flag == 'd'
        list = activedynamiclist
    elseif var.status == Unsuitable && var.flag == 's'
        list = unsuitablestaticlist
    elseif var.status == Unsuitable && var.flag == 'd'
        list = inactivedynamiclist
    else
        error("Status $(var.status) and flag $(var.flag) are not supported")
    end
    push!(list, var)
    var.index = length(list)
end

type SimpleConstrIndexManager <: AbstractConstrIndexManager
    activestaticlist::Vector{Constraint}
    activedynamiclist::Vector{Constraint}
    unsuitablestaticlist::Vector{Constraint}
    unsuitabledynamiclist::Vector{Constraint}
end

SimpleConstrIndexManager() = SimpleConstrIndexManager(Vector{Constraint}(), Vector{Constraint}(), Vector{Constraint}(), Vector{Constraint}())

function addinconstrmanager(constrmanager::SimpleConstrIndexManager, constr::Constraint)
    if constr.status == Active && constr.flag == 's'
        list = constrmanager.activestaticlist
    elseif constr.status == Active && constr.flag == 'd'
        list = activedynamiclist
    elseif constr.status == Unsuitable && constr.flag == 's'
        list = unsuitablestaticlist
    elseif constr.status == Unsuitable && constr.flag == 'd'
        list = inactivedynamiclist
    else
        error("Status $(constr.status) and flag $(constr.flag) are not supported")
    end
    push!(list, constr)
    constr.index = length(list)
end

abstract type Problem end

type CompactProblem{VM <: AbstractVarIndexManager, 
                    CM <: AbstractConstrIndexManager} <: Problem

    # probInfeasiblesFlag::Bool

    # objvalueordermagnitude::Float
    probisbuilt::Bool

    optimizer::MOI.AbstractOptimizer
    # primalFormulation::LPform

    varmanager::VM
    constrmanager::CM

    inprimallpsol::Set{Variable}
    # inprimalipsol::Set{Variable}
    nonzeroredcostvars::Set{Variable}
    indualsol::Set{Constraint}

    partialsolutionvalue::Float
    partialsolution::Dict{Variable,Float}

    # nbofrecordedsol::Int
    recordedsol::Vector{Solution}

    # needed for new preprocessing
    preprocessedconstrslist::Vector{Constraint}
    preprocessedvarslist::Vector{Variable}

    counter::VarConstrCounter
    varconstrvec::Vector{VarConstr}

    # added for more efficiency and to fix bug
    # after columns are cleaned we can t ask for red costs
    # before the MIPSolver solves the master again.
    # It is put to true in retrieveRedCosts()
    # It is put to false in resetSolution()
    isRetrievedRedCosts::Bool
end

function Problem{VM,CM}(useroptimizer::MOI.AbstractOptimizer) where {VM <: AbstractVarIndexManager, CM <: AbstractConstrIndexManager}

    optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), useroptimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    MOI.set!(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(), f)
    MOI.set!(optimizer, MOI.ObjectiveSense(), MOI.MinSense)

    Problem(false, optimizer, VM(), CM(), Set{Variable}(), Set{Variable}(), Set{Constraint}(), 0.0,
            Dict{Variable,Float}(), Vector{Solution}(), Vector{Constraint}(), Vector{Variable}(),
            VarConstrCounter(0), Vector{VarConstr}(), false)
end

const SimpleProblem = Problem{SimpleVarIndexManager,SimpleConstrIndexManager}

### addvariable changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the variable
function addvariable(problem::Problem, var::Variable)
    addinvarmanager(problem.varmanager, var)
    var.moiindex = MOI.addvariable!(problem.optimizer)
    push!(problem.varconstrvec, var)
    MOI.modify!(problem.optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), 
                MOI.ScalarCoefficientChange{Float}(var.moiindex, var.costrhs))
    MOI.addconstraint!(problem.optimizer, MOI.SingleVariable(var.moiindex), 
                       MOI.Interval(var.lowerbound, var.upperbound))
end

### addconstraint changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the constraint
function addconstraint(problem::Problem, constr::Constraint)
    addinconstrmanager(problem.constrmanager, constr)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    constr.moiindex = MOI.addconstraint!(problem.optimizer, f, constr.settype(constr.costrhs))
    push!(problem.varconstrvec, constr)
end

function addmembership(var::Variable, constr::Constraint, coef::Float)
    var.membercoefmap[var.vc_ref] = coef
    constr.membercoefmap[constr.vc_ref] = coef
    MOI.modify!(var.problem.optimizer,  constr.moiindex, 
                MOI.ScalarCoefficientChange{Float}(var.moiindex, coef))
end

function addmembership(var::SubProbVar, constr::MasterConstr, coef::Float)
    var.masterconstrcoefmap[var.vc_ref] = coef
    constr.subprobvarcoefmap[constr.vc_ref] = coef
end

# function addmembership(var::MasterVar, constr::MasterConstr, coef::Float)
#     var.membercoefmap[var.vc_ref] = coef
#     constr.membercoefmap[constr.vc_ref] = coef
#     MOI.modify!(var.problem.optimizer,  constr.moiindex, 
#                 MOI.ScalarCoefficientChange{Float}(var.moiindex, coef))
# end

function optimize(problem::Problem)
    MOI.optimize!(problem.optimizer)
end

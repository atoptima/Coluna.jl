############################################################################################
# Duties for a Formulation
############################################################################################
# These contain data specific to a type of formulation.
# For example, the pool of primal solution generated from a Dantzig-Wolfe subproblem.

abstract type AbstractFormDuty end
abstract type AbstractMasterDuty <: AbstractFormDuty end
abstract type AbstractSpDuty <: AbstractFormDuty end

"Formulation provided by the user."
struct Original <: AbstractFormDuty end

"Master of a formulation decomposed using Dantzig-Wolfe."
struct DwMaster <: AbstractMasterDuty end

"Master of a formulation decomposed using Benders."
struct BendersMaster <: AbstractMasterDuty end

mutable struct DwSp <: AbstractSpDuty
    setup_var::Union{VarId,Nothing}
    lower_multiplicity_constr_id::Union{ConstrId,Nothing}
    upper_multiplicity_constr_id::Union{ConstrId,Nothing}
    column_var_kind::VarKind

    # Pool of solutions to the Dantzig-Wolfe subproblem.
    pool::Pool
end

"A pricing subproblem of a formulation decomposed using Dantzig-Wolfe."
function DwSp(setup_var, lower_multiplicity_constr_id, upper_multiplicity_constr_id, column_var_kind)
    return DwSp(
        setup_var, lower_multiplicity_constr_id, upper_multiplicity_constr_id,
        column_var_kind,
        Pool()
    )
end
mutable struct BendersSp <: AbstractSpDuty
    slack_to_first_stage::Dict{VarId,VarId}
    second_stage_cost_var::Union{VarId,Nothing}
    pool::DualSolutionPool
end

"A Benders subproblem of a formulation decomposed using Benders."
BendersSp() = BendersSp(Dict{VarId,VarId}(), nothing, DualSolutionPool())

############################################################################################
# Duties tree for a Variable
############################################################################################
@exported_nestedenum begin
    Duty{Variable}
    AbstractOriginalVar <= Duty{Variable}
    OriginalVar <= AbstractOriginalVar
    AbstractMasterVar <= Duty{Variable}
    AbstractOriginMasterVar <= AbstractMasterVar
    MasterPureVar <= AbstractOriginMasterVar
    MasterBendFirstStageVar <= AbstractOriginMasterVar
    AbstractAddedMasterVar <= AbstractMasterVar
    MasterCol <= AbstractAddedMasterVar
    MasterArtVar <= AbstractAddedMasterVar
    MasterBendSecondStageCostVar <= AbstractAddedMasterVar
    AbstractImplicitMasterVar <= AbstractMasterVar
    AbstractMasterRepDwSpVar <= AbstractImplicitMasterVar
    MasterRepPricingVar <= AbstractMasterRepDwSpVar
    MasterRepPricingSetupVar <= AbstractMasterRepDwSpVar
    AbstractDwSpVar <= Duty{Variable}
    DwSpPricingVar <= AbstractDwSpVar
    DwSpSetupVar <= AbstractDwSpVar
    DwSpPrimalSol <= AbstractDwSpVar
    AbstractBendSpVar <= Duty{Variable}
    AbstractBendSpSlackMastVar <= AbstractBendSpVar
    BendSpSlackFirstStageVar <= AbstractBendSpSlackMastVar
    BendSpPosSlackFirstStageVar <= BendSpSlackFirstStageVar
    BendSpNegSlackFirstStageVar <= BendSpSlackFirstStageVar
    BendSpSlackSecondStageCostVar <= AbstractBendSpSlackMastVar
    BendSpSecondStageArtVar <= AbstractBendSpSlackMastVar
    BendSpSepVar <= AbstractBendSpVar
    BendSpFirstStageRepVar <= AbstractBendSpVar
    BendSpCostRepVar <= AbstractBendSpVar
end

############################################################################################
# Duties tree for a Constraint
############################################################################################
@exported_nestedenum begin
    Duty{Constraint}
    AbstractOriginalConstr <= Duty{Constraint}
    OriginalConstr <= AbstractOriginalConstr
    AbstractMasterConstr <= Duty{Constraint}
    AbstractMasterOriginConstr <= AbstractMasterConstr
    MasterPureConstr <= AbstractMasterOriginConstr
    MasterMixedConstr <= AbstractMasterOriginConstr
    AbstractMasterAddedConstr <= AbstractMasterConstr
    MasterConvexityConstr <= AbstractMasterAddedConstr
    AbstractMasterCutConstr <= AbstractMasterConstr
    MasterBendCutConstr <= AbstractMasterCutConstr
    MasterUserCutConstr <= AbstractMasterCutConstr
    AbstractMasterBranchingConstr <= AbstractMasterConstr
    MasterBranchOnOrigVarConstr <= AbstractMasterBranchingConstr
    AbstractDwSpConstr <= Duty{Constraint}
    DwSpPureConstr <= AbstractDwSpConstr
    AbstractBendSpConstr <= Duty{Constraint}
    AbstractBendSpMasterConstr <= AbstractBendSpConstr
    BendSpSecondStageCostConstr <= AbstractBendSpMasterConstr
    BendSpTechnologicalConstr <= AbstractBendSpMasterConstr
    BendSpPureConstr <= AbstractBendSpConstr
    BendSpDualSol <= AbstractBendSpConstr
end

############################################################################################
# Methods to get extra information about duties
############################################################################################
function isaStaticDuty(duty::NestedEnum)
    return duty <= OriginalVar ||
           duty <= MasterPureVar ||
           duty <= MasterArtVar ||
           duty <= MasterBendSecondStageCostVar ||
           duty <= MasterBendFirstStageVar ||
           duty <= MasterRepPricingVar ||
           duty <= MasterRepPricingSetupVar ||
           duty <= DwSpPricingVar ||
           duty <= DwSpSetupVar ||
           duty <= DwSpPrimalSol ||
           duty <= BendSpSepVar ||
           duty <= BendSpSlackFirstStageVar ||
           duty <= BendSpSlackSecondStageCostVar ||
           duty <= OriginalConstr ||
           duty <= MasterPureConstr ||
           duty <= MasterMixedConstr ||
           duty <= MasterConvexityConstr ||
           duty <= DwSpPureConstr ||
           duty <= BendSpPureConstr ||
           duty <= BendSpDualSol ||
           duty <= BendSpSecondStageCostConstr ||
           duty <= BendSpTechnologicalConstr
end

function isaDynamicDuty(duty::NestedEnum)
    return duty <= MasterCol ||
           duty <= MasterBranchOnOrigVarConstr ||
           duty <= MasterBendCutConstr ||
           duty <= MasterBranchOnOrigVarConstr
end

function isanOriginalRepresentatives(duty::NestedEnum)
    return duty <= MasterPureVar ||
           duty <= MasterRepPricingVar
end

function isanArtificialDuty(duty::NestedEnum)
    return duty <= MasterArtVar || duty <= BendSpSecondStageArtVar
end

function isaNonUserDefinedDuty(duty::NestedEnum)
    return duty <= MasterArtVar ||
           duty <= MasterRepPricingSetupVar ||
           duty <= MasterCol ||
           duty <= DwSpSetupVar ||
           duty <= MasterConvexityConstr
end
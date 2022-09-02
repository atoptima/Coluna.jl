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
    setup_var::Union{VarId, Nothing}
    lower_multiplicity::Int
    upper_multiplicity::Int
    column_var_kind::VarKind

    # Pool of solutions to the Dantzig-Wolfe subproblem.
    ## Coluna representation of solutions (filtered by `_sol_repr_for_pool`).
    ## [colid, varid] = value
    primalsols_pool::VarVarMatrix
    # Hash table to quickly find identical solutions
    hashtable_primalsols_pool::HashTable{VarId,VarId}
    ## Perennial cost of solutions
    costs_primalsols_pool::Dict{VarId, Float64}
    ## Custom representation of solutions
    custom_primalsols_pool::Dict{VarId, BD.AbstractCustomData}
end

"A pricing subproblem of a formulation decomposed using Dantzig-Wolfe."
function DwSp(setup_var, lower_multiplicity, upper_multiplicity, column_var_kind)
    return DwSp(
        setup_var, lower_multiplicity, upper_multiplicity, column_var_kind,
        dynamicsparse(VarId, VarId, Float64; fill_mode = false),
        HashTable{VarId, VarId}(),
        Dict{VarId, Float64}(),
        Dict{VarId, BD.AbstractCustomData}()
    )
end

struct BendersSp <: AbstractSpDuty 
    slack_to_first_stage::Dict{VarId, VarId}
end

"A Benders subproblem of a formulation decomposed using Benders."
BendersSp() = BendersSp(Dict{VarId, VarId}())

############################################################################################
# Duties tree for a Variable
############################################################################################
@exported_nestedenum begin
    Duty{Variable}
        AbstractOriginalVar <= Duty{Variable}
            OriginalVar <= AbstractOriginalVar
            #OriginalExpression <= AbstractOriginalVar
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
            #DwSpPureVar <= AbstractDwSpVar
            DwSpPrimalSol <= AbstractDwSpVar
        AbstractBendSpVar <= Duty{Variable}
            AbstractBendSpSlackMastVar <= AbstractBendSpVar
                BendSpSlackFirstStageVar <= AbstractBendSpSlackMastVar
                    BendSpPosSlackFirstStageVar <= BendSpSlackFirstStageVar
                    BendSpNegSlackFirstStageVar <= BendSpSlackFirstStageVar
                BendSpSlackSecondStageCostVar <= AbstractBendSpSlackMastVar
            BendSpSepVar <= AbstractBendSpVar
            #BendSpPureVar <= AbstractBendSpVar
            BendSpPrimalSol <= AbstractBendSpVar
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
                #MasterSecondStageCostConstr <= AbstractMasterAddedConstr
            #AbstractMasterImplicitConstr <= AbstractMasterConstr
                #AbstractMasterRepBendSpConstr <= AbstractMasterImplicitConstr
                    #MasterRepBendSpSecondStageCostConstr <= AbstractMasterRepBendSpConstr
                    #MasterRepBendSpTechnologicalConstr <= AbstractMasterRepBendSpConstr
            AbstractMasterCutConstr <= AbstractMasterConstr
                MasterBendCutConstr <= AbstractMasterCutConstr
                MasterUserCutConstr <= AbstractMasterCutConstr
            AbstractMasterBranchingConstr <= AbstractMasterConstr
                MasterBranchOnOrigVarConstr <= AbstractMasterBranchingConstr
        AbstractDwSpConstr <= Duty{Constraint}
            DwSpPureConstr <= AbstractDwSpConstr
            # <= AbstractDwSpConstr
            #DwSpRepMastBranchConstr <= AbstractDwSpConstr
        #AbstractBendSpPureConstr <= Duty{Constraint}
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
    #duty <= OriginalExpression ||
    duty <= MasterPureVar ||
    duty <= MasterArtVar ||
    duty <= MasterBendSecondStageCostVar ||
    duty <= MasterBendFirstStageVar ||
    duty <= MasterRepPricingVar ||
    duty <= MasterRepPricingSetupVar ||
    duty <= DwSpPricingVar ||
    duty <= DwSpSetupVar ||
    #duty <= DwSpPureVar ||
    duty <= DwSpPrimalSol ||
    duty <= DwSpDualSol ||
    duty <= BendSpSepVar ||
    #duty <= BendSpPureVar ||
    duty <= BendSpSlackFirstStageVar  ||
    duty <= BendSpSlackSecondStageCostVar ||
    duty <= OriginalConstr ||
    duty <= MasterPureConstr ||
    duty <= MasterMixedConstr ||
    duty <= MasterConvexityConstr ||
    #duty <= MasterSecondStageCostConstr ||
    duty <= DwSpPureConstr ||
    duty <= BendSpPureConstr ||
    duty <= BendSpDualSol ||
    duty <= BendSpPrimalSol ||
    duty <= BendSpSecondStageCostConstr ||
    duty <= BendSpTechnologicalConstr
end

function isaDynamicDuty(duty::NestedEnum)
    duty <= MasterCol ||
    duty <= MasterBranchOnOrigVarConstr ||
    duty <= MasterBendCutConstr ||
    duty <= MasterBranchOnOrigVarConstr
    #duty <= DwSpRepMastBranchConstr ||
    #duty <= DwSpRepMastBranchConstr
end

function isanOriginalRepresentatives(duty::NestedEnum)
    duty <= MasterPureVar ||
    duty <= MasterRepPricingVar
end

function isanArtificialDuty(duty::NestedEnum)
    return duty <= MasterArtVar
end
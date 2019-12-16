abstract type AbstractVarConstr end
abstract type AbstractVarConstrId end
abstract type AbstractState end
abstract type AbstractFormulation end
abstract type AbstractProblem end
abstract type AstractMoiDef end
abstract type AbstractMembership end
abstract type AbstractNode end
abstract type AbstractVcData end
abstract type AbstractObjSense end
abstract type AbstractBound <: Number end
abstract type AbstractOptimizer end

"""
    AbstractStrategy

A strategy is a type used to define Coluna's behaviour in its algorithmic parts.
"""
abstract type AbstractStrategy end
"""
    AbstractAlgorithm

An algorithm is a 'text-book' algorithm applied to a formulation in a node.
"""
abstract type AbstractAlgorithm end

struct MinSense <: AbstractObjSense end
struct MaxSense <: AbstractObjSense end

abstract type AbstractDuty end

## Duties : 
@nestedenum begin
    AbstractVarDuty
        AbstractOriginalVar <= AbstractVarDuty
            OriginalVar <= AbstractOriginalVar
            OriginalExpression <= AbstractOriginalVar
        AbstractMasterVar <= AbstractVarDuty
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
        AbstractDwSpVar <= AbstractVarDuty
            DwSpPricingVar <= AbstractDwSpVar
            DwSpSetupVar <= AbstractDwSpVar
            DwSpPureVar <= AbstractDwSpVar 
        AbstractBendSpVar <= AbstractVarDuty
            AbstractBendSpSlackMastVar <= AbstractBendSpVar
                BendSpSlackFirstStageVar <= AbstractBendSpSlackMastVar
                BendSpSlackSecondStageCostVar <= AbstractBendSpSlackMastVar
            BendSpSepVar <= AbstractBendSpVar
            BendSpPureVar <= AbstractBendSpVar
        UndefinedVarDuty <= AbstractVarDuty
end

@nestedenum begin
    AbstractConstrDuty
            AbstractOriginalConstr <= AbstractConstrDuty
                OriginalConstr <= AbstractOriginalConstr 
            AbstractMasterConstr <= AbstractConstrDuty
                AbstractMasterOriginConstr <= AbstractMasterConstr
                    MasterPureConstr <= AbstractMasterOriginConstr 
                    MasterMixedConstr <= AbstractMasterOriginConstr
                AbstractMasterAddedConstr <= AbstractMasterConstr
                    MasterConvexityConstr <= AbstractMasterAddedConstr
                    MasterSecondStageCostConstr <= AbstractMasterAddedConstr
                AbstractMasterImplicitConstr <= AbstractMasterConstr
                    AbstractMasterRepBendSpConstr <= AbstractMasterImplicitConstr
                        MasterRepBendSpSecondStageCostConstr <= AbstractMasterRepBendSpConstr
                        MasterRepBendSpTechnologicalConstr <= AbstractMasterRepBendSpConstr
                AbstractMasterCutConstr <= AbstractMasterConstr
                    MasterBendCutConstr <= AbstractMasterCutConstr
                AbstractMasterBranchingConstr <= AbstractMasterConstr
                MasterBranchOnOrigVarConstr <= AbstractMasterBranchingConstr
            AbstractDwSpConstr <= AbstractConstrDuty
                DwSpPureConstr <= AbstractDwSpConstr
                DwSpRepMastBranchConstr <= AbstractDwSpConstr
            AbstractBendSpPureConstr <= AbstractConstrDuty
            AbstractBendSpConstr <= AbstractConstrDuty
                AbstractBendSpMasterConstr <= AbstractBendSpConstr
                    BendSpSecondStageCostConstr <= AbstractBendSpMasterConstr
                    BendSpTechnologicalConstr <= AbstractBendSpMasterConstr
                BendSpPureConstr <= AbstractBendSpConstr
            UndefinedConstrDuty <= AbstractConstrDuty
end

abstract type AbstractFormDuty end
# First level of duties 
abstract type AbstractMasterDuty <: AbstractFormDuty end
abstract type AbstractSpDuty <: AbstractFormDuty end

# Concrete duties for Formulation
"Formulation provided by the user."
struct Original <: AbstractFormDuty end

"Master of formulation decomposed using Dantzig-Wolfe."
struct DwMaster <: AbstractMasterDuty end

"Master of formulation decomposed using Benders."
struct BendersMaster <: AbstractMasterDuty end

"A pricing subproblem of formulation decomposed using Dantzig-Wolfe."
struct DwSp <: AbstractSpDuty end

"A Benders subproblem of formulation decomposed using Benders."
struct BendersSp <: AbstractSpDuty end

#BendSpRepFirstStageVar <= AbstractBendSpRepMastVar
#BendSpRepSecondStageCostVar <= AbstractBendSpRepMastVar

#BendersSpVar <= AbstractVarDuty
#BlockGenSpVar <= AbstractVarDuty
#MastRepBlockSpVar <= AbstractVarDuty

# Types of algorithm

abstract type AbstractAlg end

# TODO : See with Ruslan for algorithm types tree

# abstract type AbstractNodeAlg <: AbstractAlg end
# abstract type AbstractSetupNodeAlg <: AbstractNodeAlg end
# abstract type AbstractPreprocessNodeAlg <: AbstractNodeAlg end
# abstract type AbstractEvalNodeAlg <: AbstractNodeAlg end
# abstract type AbstractRecordInfoNodeAlg <: AbstractNodeAlg end
# abstract type AbstractPrimalHeurNodeAlg <: AbstractNodeAlg end
# abstract type AbstractGenChildrenNodeAlg <: AbstractNodeAlg end

@enum FormulationPhase HybridPhase PurePhase1 PurePhase2 
@enum VarSense Positive Negative Free
@enum VarKind Continuous Binary Integ
@enum ConstrKind Core Facultative SubSystem
@enum ConstrSense Greater Less Equal
@enum VcSelectionCriteria Static Dynamic Delayed Artificial Implicit Explicit
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

const FormId = Int
const VcUid = Int
const FormUid = Int
const ProcessUid = Int

function isaStaticDuty(duty::NestedEnum)
    return duty <= OriginalVar ||
    duty <= OriginalExpression ||
    duty <= MasterPureVar ||
    duty <= MasterArtVar ||
    duty <= MasterBendSecondStageCostVar ||
    duty <= MasterBendFirstStageVar || 
    duty <= MasterRepPricingVar || 
    duty <= MasterRepPricingSetupVar || 
    duty <= DwSpPricingVar ||
    duty <= DwSpSetupVar || 
    duty <= DwSpPureVar || 
    duty <= BendSpSepVar || 
    duty <= BendSpPureVar || 
    duty <= BendSpSlackFirstStageVar  ||
    duty <= BendSpSlackSecondStageCostVar || 
    duty <= OriginalConstr ||
    duty <= MasterPureConstr || 
    duty <= MasterMixedConstr || 
    duty <= MasterConvexityConstr ||
    duty <= MasterSecondStageCostConstr ||
    duty <= DwSpPureConstr || 
    duty <= BendSpPureConstr || 
    duty <= BendSpSecondStageCostConstr ||
    duty <= BendSpTechnologicalConstr
end

function isaDynamicDuty(duty::NestedEnum)
    duty <= MasterCol ||
    duty <= MasterBranchOnOrigVarConstr ||
    duty <= MasterBendCutConstr ||
    duty <= MasterBranchOnOrigVarConstr ||
    duty <= DwSpRepMastBranchConstr || 
    duty <= DwSpRepMastBranchConstr
end

function isaOriginalRepresentatives(duty::NestedEnum)
    duty <= MasterPureVar ||
    duty <= MasterRepPricingVar
end

function isaArtificialDuty(duty::NestedEnum) 
    return duty <= MasterArtVar
end




############################################################################
######################## MathOptInterface shortcuts ########################
############################################################################
# Objective function
const MoiObjective = MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}

# Constraint
const MoiConstrIndex = MOI.ConstraintIndex
MoiConstrIndex{F,S}() where {F,S} = MOI.ConstraintIndex{F,S}(-1)
MoiConstrIndex() = MOI.ConstraintIndex{
    MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}
}()

# Variable
const MoiVarIndex = MOI.VariableIndex
MoiVarIndex() = MOI.VariableIndex(-1)

# Bounds on variables
const MoiVarBound = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}

# Variable kinds
const MoiInteger = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Integer}
const MoiBinary = MOI.ConstraintIndex{MOI.SingleVariable,MOI.ZeroOne}
const MoiVarKind = Union{MoiInteger,MoiBinary}
MoiVarKind() = MoiInteger(-1)

# Helper functions to transform MOI types in Coluna types
getsense(::MOI.LessThan{T}) where {T} = Less
getsense(::MOI.GreaterThan{T}) where {T} = Greater
getsense(::MOI.EqualTo{T}) where {T} = Equal
getrhs(set::MOI.LessThan{T}) where {T} = set.upper
getrhs(set::MOI.GreaterThan{T}) where {T} = set.lower
getrhs(set::MOI.EqualTo{T}) where {T} = set.value
getkind(::MOI.ZeroOne) = Binary
getkind(::MOI.Integer) = Integ
function get_moi_set(constr_set::ConstrSense)
    constr_set == Less && return MOI.LessThan
    constr_set == Greater && return MOI.GreaterThan
    return MOI.EqualTo
end
############################################################################

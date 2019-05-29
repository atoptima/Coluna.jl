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

## Duties : 
abstract type AbstractDuty end 
abstract type AbstractVarConstrDuty <: AbstractDuty end
abstract type AbstractVarDuty <: AbstractVarConstrDuty end
abstract type AbstractConstrDuty <: AbstractVarConstrDuty end
abstract type AbstractFormDuty <: AbstractDuty end

# First level of specification on VarDuty
abstract type AbstractOriginalVar <: AbstractVarDuty end
abstract type AbstractMasterVar <: AbstractVarDuty end
abstract type AbstractOriginMasterVar <: AbstractMasterVar end
abstract type AbstractAddedMasterVar <: AbstractMasterVar end
abstract type AbstractImplicitMasterVar <: AbstractMasterVar end
abstract type AbstractMasterRepDwSpVar <: AbstractImplicitMasterVar end
abstract type AbstractDwSpVar <: AbstractVarDuty end
abstract type AbstractBendSpVar <: AbstractVarDuty end
abstract type AbstractBendSpRepMastVar <: AbstractBendSpVar end

# Concrete types for VarDuty
struct OriginalVar <: AbstractOriginalVar end
struct OriginalExpression <: AbstractOriginalVar end

struct MasterPureVar <: AbstractOriginMasterVar end 
struct MasterCol <: AbstractAddedMasterVar end
struct MasterArtVar <: AbstractAddedMasterVar end
struct MasterBendSecondStageCostVar <: AbstractAddedMasterVar end
struct MasterBendFirstStageVar <: AbstractOriginMasterVar end
struct MasterRepPricingVar <: AbstractMasterRepDwSpVar end
struct MasterRepPricingSetupVar <: AbstractMasterRepDwSpVar end

struct DwSpPricingVar <: AbstractDwSpVar end
struct DwSpSetupVar <: AbstractDwSpVar end
struct DwSpPureVar <: AbstractDwSpVar end 

struct BendSpSepVar <: AbstractBendSpVar end
struct BendSpPureVar <: AbstractBendSpVar end
struct BendSpRepFirstStageVar  <: AbstractBendSpRepMastVar end
struct BendSpRepSecondStageCostVar <: AbstractBendSpRepMastVar end

struct UndefinedVarDuty <: AbstractVarDuty end

#struct BendersSpVar <: AbstractVarDuty end
#struct BlockGenSpVar <: AbstractVarDuty end
#struct MastRepBlockSpVar <: AbstractVarDuty end

# First level of specification on ConstrDuty
abstract type AbstractOriginalConstr <: AbstractConstrDuty end
abstract type AbstractMasterConstr <: AbstractConstrDuty end
abstract type AbstractMasterOriginConstr <: AbstractMasterConstr end
abstract type AbstractMasterAddedConstr <: AbstractMasterConstr end
abstract type AbstractMasterCutConstr <: AbstractMasterConstr end
abstract type AbstractMasterBranchingConstr <: AbstractMasterConstr end
abstract type AbstractDwSpConstr <: AbstractConstrDuty end
abstract type AbstractBendSpConstr <: AbstractConstrDuty end

# Concrete duties for Constraints
struct OriginalConstr <: AbstractOriginalConstr end

struct MasterPureConstr <: AbstractMasterOriginConstr end 
struct MasterMixedConstr <: AbstractMasterOriginConstr end 
struct MasterConvexityConstr <: AbstractMasterAddedConstr end
struct MasterSecondStageCostConstr <: AbstractMasterAddedConstr end
struct MasterBendCutConstr <: AbstractMasterCutConstr end
struct MasterBranchOnOrigVarConstr <: AbstractMasterBranchingConstr end

struct DwSpPureConstr <: AbstractDwSpConstr end
struct DwSpRepMastBranchConstr <: AbstractDwSpConstr end

struct BendSpPureConstr <: AbstractBendSpConstr end
struct BendSpSecondStageCostConstr <: AbstractBendSpConstr end
struct BendSpTechnologicalConstr <: AbstractBendSpConstr end


struct UndefinedConstrDuty <: AbstractConstrDuty end

# Concrete duties for Formulation
"Formulation provided by the user."
struct Original <: AbstractFormDuty end

"Master of formulation decomposed using Dantzig-Wolfe."
struct DwMaster <: AbstractFormDuty end

"Master of formulation decomposed using Benders."
struct BendersMaster <: AbstractFormDuty end

"A pricing subproblem of formulation decomposed using Dantzig-Wolfe."
struct DwSp <: AbstractFormDuty end

"A Benders subproblem of formulation decomposed using Benders."
struct BendersSp <: AbstractFormDuty end

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

@enum VarSense Positive Negative Free
@enum VarKind Continuous Binary Integ
@enum ConstrKind Core Facultative SubSystem
@enum ConstrSense Greater Less Equal
@enum VcSelectionCriteria Static Dynamic Delayed Artificial Implicit Explicit
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

const FormId = Int

const StaticDuty = Union{
    Type{OriginalVar},
    Type{OriginalExpression},
    Type{MasterPureVar},
    Type{MasterArtVar},
    Type{MasterBendSecondStageCostVar},
    Type{MasterBendFirstStageVar}, 
    Type{MasterRepPricingVar}, 
    Type{MasterRepPricingSetupVar}, 
    Type{DwSpPricingVar},
    Type{DwSpSetupVar}, 
    Type{DwSpPureVar}, 
    Type{BendSpSepVar}, 
    Type{BendSpPureVar}, 
    Type{BendSpRepFirstStageVar },
    Type{BendSpRepSecondStageCostVar}, 
    Type{OriginalConstr},
    Type{MasterPureConstr}, 
    Type{MasterMixedConstr}, 
    Type{MasterConvexityConstr},
    Type{MasterSecondStageCostConstr},
    Type{DwSpPureConstr}, 
    Type{BendSpPureConstr}, 
    Type{BendSpSecondStageCostConstr},
    Type{BendSpTechnologicalConstr}
}

const DynamicDuty = Union{
    Type{MasterCol},
    Type{MasterBranchOnOrigVarConstr},
    Type{MasterBendCutConstr},
    Type{MasterBranchOnOrigVarConstr},
    Type{DwSpRepMastBranchConstr}, 
    Type{DwSpRepMastBranchConstr}
}

const OriginalRepresentatives = Union{
    Type{MasterPureVar},
    Type{MasterRepPricingVar}
}
const ArtificialDuty = Union{Type{MasterArtVar}}




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

abstract type AbstractVarConstr end
abstract type AbstractVarConstrId end
abstract type AbstractState end
abstract type AbstractFormulation end
abstract type AbstractProblem end
abstract type AbstractMoiDef end
abstract type AbstractCounter end
abstract type AbstractMembership end
abstract type AbstractNode end

## Duties : 
abstract type AbstractDuty end 
abstract type AbstractVarConstrDuty <: AbstractDuty end
abstract type AbstractVarDuty <: AbstractDuty end
abstract type AbstractConstrDuty <: AbstractDuty end
abstract type AbstractFormDuty <: AbstractDuty end

# First level of specification on VarDuty
abstract type AbstractOriginalVar <: AbstractVarDuty end
abstract type AbstractMasterVar <: AbstractVarDuty end
abstract type AbstractDwSpVar <: AbstractVarDuty end

# Concrete types for VarDuty
struct OriginalVar <: AbstractOriginalVar end
struct OriginalExpression <: AbstractOriginalVar end
struct PureMastVar <: AbstractMasterVar end
struct MasterCol <: AbstractMasterVar end
struct MastArtVar <: AbstractMasterVar end
struct MastRepPricingSpVar <: AbstractMasterVar end
struct MastRepPricingSetupSpVar <: AbstractMasterVar end # Cannot subtype a concrete type
struct MastRepBendSpVar <: AbstractMasterVar end
struct PricingSpVar <: AbstractDwSpVar end
struct PricingSpSetupVar <: AbstractDwSpVar end # Cannot subtype a concrete type
struct PricingSpPureVar <: AbstractDwSpVar end
struct UndefinedVarDuty <: AbstractVarDuty end

#struct BendersSpVar <: AbstractVarDuty end
#struct BlockGenSpVar <: AbstractVarDuty end
#struct MastRepBlockSpVar <: AbstractVarDuty end

# First level of specification on ConstrDuty
abstract type AbstractOriginalConstr <: AbstractConstrDuty end
abstract type AbstractMasterConstr <: AbstractConstrDuty end
abstract type AbstractDwSpConstr <: AbstractConstrDuty end

# Concrete types for VarDuty
struct OriginalConstr <: AbstractOriginalConstr end
struct MasterPureConstr <: AbstractMasterConstr end
struct MasterConstr <: AbstractMasterConstr end
struct MasterConvexityConstr <: AbstractMasterConstr end
struct MasterBranchConstr <: AbstractMasterConstr end
struct PricingSpPureConstr <: AbstractDwSpConstr end
struct PricingSpRepMastBranchConstr <: AbstractDwSpConstr end
struct UndefinedConstrDuty <: AbstractConstrDuty end

# Concrete types for FormDuty
struct Original <: AbstractFormDuty end
struct DwMaster <: AbstractFormDuty end
struct BendersMaster <: AbstractFormDuty end
struct DwSp <: AbstractFormDuty end
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
@enum Status Active Unsuitable
@enum ObjSense Min Max
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

const FormId = Int

const MoiSetType = Union{MOI.AbstractSet, Nothing}
const MoiObjective = MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}
const MoiVarBound = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}
const MoiVarKind = MOI.ConstraintIndex{MOI.SingleVariable,T} where T <: Union{MOI.Integer,MOI.ZeroOne}
const MoiConstrIndex = Union{MOI.ConstraintIndex, Nothing}
const MoiVarIndex = Union{MOI.VariableIndex, Nothing}
const MoiVarConstrIndex = Union{MoiVarIndex, MoiConstrIndex}

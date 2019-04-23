abstract type AbstractVarConstr end
abstract type AbstractVarConstrId end
abstract type AbstractState end
abstract type AbstractFormulation end
abstract type AbstractProblem end
abstract type AbstractMoiDef end
abstract type AbstractMembership end
abstract type AbstractNode end
abstract type AbstractVcData end
abstract type AbstractObjSense end
abstract type AbstractBound <: Number end

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
abstract type AbstractDwSpVar <: AbstractVarDuty end
abstract type AbstractPricingSpVar <: AbstractDwSpVar end
abstract type AbstractMastRepSpVar <: AbstractDwSpVar end

# Concrete types for VarDuty
struct OriginalVar <: AbstractOriginalVar end
struct OriginalExpression <: AbstractOriginalVar end
struct PureMastVar <: AbstractMasterVar end
struct MasterCol <: AbstractMasterVar end
struct MastArtVar <: AbstractMasterVar end
struct MastRepPricingSpVar <: AbstractMastRepSpVar end
struct MastRepPricingSetupSpVar <: AbstractMastRepSpVar end # Cannot subtype a concrete type
struct MastRepBendSpVar <: AbstractMastRepSpVar end
struct PricingSpVar <: AbstractPricingSpVar end
struct PricingSpSetupVar <: AbstractPricingSpVar end # Cannot subtype a concrete type
struct PricingSpPureVar <: AbstractDwSpVar end
struct UndefinedVarDuty <: AbstractVarDuty end

#struct BendersSpVar <: AbstractVarDuty end
#struct BlockGenSpVar <: AbstractVarDuty end
#struct MastRepBlockSpVar <: AbstractVarDuty end

# First level of specification on ConstrDuty
abstract type AbstractOriginalConstr <: AbstractConstrDuty end
abstract type AbstractMasterConstr <: AbstractConstrDuty end
abstract type AbstractDwSpConstr <: AbstractConstrDuty end
abstract type AbstractMasterRepOriginalConstr <: AbstractMasterConstr end

# Concrete types for AbstractConstrDuty
struct OriginalConstr <: AbstractOriginalConstr end
struct MasterPureConstr <: AbstractMasterConstr end
struct MasterConstr <: AbstractMasterRepOriginalConstr end
struct MasterConvexityConstr <: AbstractMasterConstr end
struct MasterBranchConstr <: AbstractMasterRepOriginalConstr end
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
# @enum Status Active Unsuitable
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

const FormId = Int

#######################################################################
const MoiObjective = MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}

const MoiConstrIndex = MOI.ConstraintIndex
MoiConstrIndex{F,S}() where {F,S} = MOI.ConstraintIndex{F,S}(-1)
MoiConstrIndex() = MOI.ConstraintIndex{
    MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}
}()

const MoiVarIndex = MOI.VariableIndex
MoiVarIndex() = MOI.VariableIndex(-1)

const MoiVarBound = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}

const MoiInteger = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Integer}
const MoiBinary = MOI.ConstraintIndex{MOI.SingleVariable,MOI.ZeroOne}
const MoiVarKind = Union{MoiInteger,MoiBinary}
MoiVarKind() = MoiInteger(-1)

# Helpers
get_sense(::MOI.LessThan{T}) where {T} = Less
get_sense(::MOI.GreaterThan{T}) where {T} = Greater
get_sense(::MOI.EqualTo{T}) where {T} = Equal
get_rhs(set::MOI.LessThan{T}) where {T} = set.upper
get_rhs(set::MOI.GreaterThan{T}) where {T} = set.lower
get_rhs(set::MOI.EqualTo{T}) where {T} = set.value
get_kind(::MOI.ZeroOne) = Binary
get_kind(::MOI.Integer) = Integ
function get_moi_set(constr_set::ConstrSense)
    constr_set == Less && return MOI.LessThan
    constr_set == Greater && return MOI.GreaterThan
    return MOI.EqualTo
end
#######################################################################

const StaticDuty = Union{
    OriginalVar, OriginalExpression, PureMastVar, MastRepPricingSpVar,
    MastRepPricingSetupSpVar, PricingSpVar, PricingSpSetupVar, PricingSpPureVar,
    OriginalConstr, MasterPureConstr, MasterConstr, MasterConvexityConstr,
    PricingSpPureConstr
}

const DynamicDuty = Union{
    Type{MasterCol}, Type{MasterBranchConstr},
    Type{PricingSpRepMastBranchConstr}
}

const ArtificialDuty = Union{Type{MastArtVar}}

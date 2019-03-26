abstract type AbstractVarConstr end
#abstract type AbstractVarDuty end
#abstract type AbstractConstrDuty end

abstract type AbstractFormulation end

abstract type AbstractModel end

abstract type AbstractMoiDef end

abstract type AbstractCounter end


@enum VarSense Positive Negative Free
@enum VarKind Continuous Binary Integ
@enum ConstrKind Core Facultative SubSystem 
@enum ConstrSense Greater Less Equal
@enum Flag Static Dynamic Delayed Artificial Implicit
@enum Status Active Unsuitable
@enum ObjSense Min Max
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

@enum VarDuty OriginalVar OriginalExpression PureMastVar MasterCol MastArtVar MastRepPricingSpVar PricingSpSetupVar  PricingSpVar  PricingSpPureVar MastRepBendSpVar BendersSpVar BlockGenSpVar MastRepBlockSpVar

@enum ConstrDuty OriginalConstr BranchingConstr MastPureConstr MasterConstr MastConvexityConstr PricingSpPureConstr  MasterBranch PricingSpRepMastBranchC

const VarId = Int
const ConstrId = Int
const FormId = Int

const MoiVarBound = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}
const MoiVarKind = MOI.ConstraintIndex{MOI.SingleVariable,T} where T <: Union{MOI.Integer,MOI.ZeroOne}
const MoiConstrIndex = Union{MOI.ConstraintIndex, Nothing}
const MoiVarIndex = Union{MOI.VariableIndex, Nothing}

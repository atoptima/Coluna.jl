abstract type AbstractVarConstr end
#abstract type AbstractVarDuty end
#abstract type AbstractConstrDuty end

abstract type AbstractFormulation end

abstract type AbstractModel end

abstract type AbstractMoiDef end

abstract type AbstractCounter end


@enum VarSense Positive Negative Free
@enum VarType Continuous Binary Integ
@enum ConstrSense Greater Less Equal
@enum ConstrType Core Facultative SubSytem PureMaster SubprobConvexity
@enum Flag Static Dynamic Artifical Implicit
@enum Status Active Unsuitable
@enum ObjSense Min Max
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

@enum VarDuty OriginalVar OriginalExpression PureMastVar MastCol MastArtVar MastRepPricingSpVar PricingSpSetupVar  PricingSpVar  PricingSpPureVar MastRepBendSpVar BendersSpVar BlockGenSpVar MastRepBlockSpVar

@enum ConstrDuty OriginalConstr BranchingConstr MastPureConstr MasterConstr MastConvexityConstr PricingSpPureConstr  MasterBranch PricingSpRepMastBranchC

const VarId = Int
const ConstrId = Int
const FormId = Int

const MoiBounds = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}
const MoiVcType = MOI.ConstraintIndex{MOI.SingleVariable,T} where T <: Union{MOI.Integer,MOI.ZeroOne}

const VarMembership = SparseVector{Float64, VarId}
const ConstrMembership = SparseVector{Float64, ConstrId}

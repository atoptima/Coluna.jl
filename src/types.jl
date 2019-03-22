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
@enum Flag Static Dynamic Artifical
@enum Status Active Unsuitable
@enum ObjSense Min Max
@enum SolutionMethod DirectMip DantzigWolfeDecomposition BendersDecomposition

@enum VarDuty OriginalVar PureMastVar MastCol MastArtVar MastRepPricingSpVar PricingSpSetupV  PricingSpVar MastRepBendSpVar BendersSpVar BlockGenSpVar MastRepBlockSpVar

@enum ConstrDuty OriginalConstr BranchingConstr MastPureConstr MasterConstr MastConvexityConstr MasterBranch PricingSpRepMastBranchC

const VarId = Int
const ConstrId = Int
const FormId = Int

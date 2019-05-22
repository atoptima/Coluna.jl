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
"""
    AbstractStrategy

A strategy is a type used to define Coluna's behaviour in its algorithmic parts.
"""
abstract type AbstractStrategy end
"""
    AbstractAlgorithm

An algorithm is an 'text-book' algorithm applied to a formulation in a node.
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
abstract type AbstractDwSpVar <: AbstractVarDuty end
abstract type AbstractBendSpVar <: AbstractVarDuty end
abstract type AbstractPricingSpVar <: AbstractDwSpVar end
abstract type AbstractMastRepDwSpVar <: AbstractMasterVar end
abstract type AbstractBendSpRepVar <: AbstractBendSpVar end

# Concrete types for VarDuty
"Variable belongs to the original formulation."
struct OriginalVar <: AbstractOriginalVar end

"Affine function of variables of duty OriginalVar ."
struct OriginalExpression <: AbstractOriginalVar end

"Variable that belongs to master."
struct PureMastVar <: AbstractMasterVar end

"Variable that belongs to master and is a partial solution of other variables."
struct MasterCol <: AbstractMasterVar end

"Artificial variable used to garantee feasibility when not enough columns were yet generated."
struct MastArtVar <: AbstractMasterVar end

"Master representative of a pricing subproblem variable."
struct MastRepPricingSpVar <: AbstractMastRepDwSpVar end

"Master representative of a pricing setup variable."
struct MastRepPricingSetupSpVar <: AbstractMastRepDwSpVar end

"Master representative of a benders subproblem variable."
struct MastRepBendSpVar <: AbstractMastRepDwSpVar end

"Variable that belongs to a pricing subproblem."
struct PricingSpVar <: AbstractPricingSpVar end

"Variable that represents the setup (use or not) of a pricing subproblem solution."
struct PricingSpSetupVar <: AbstractPricingSpVar end

"Variable belongs to a subproblem and has no representatives in the master? FV can you check this?"
struct PricingSpPureVar <: AbstractDwSpVar end

"Variable that belongs to a pricing subproblem."
struct BendersSepSpVar <: AbstractBendSpVar end

"Variable belongs to a subproblem and has no representatives in the master? FV can you check this?"
struct BendersSepVar <: AbstractBendSpVar end

struct BendersSecondStageCostVar <: AbstractMasterVar end

struct BendersFirstStageVar <: AbstractMasterVar end

struct BendersSepRepSecondStageCostVar <: AbstractBendSpVar end

struct BendersSepRepFirstStageVar <: AbstractBendSpVar end

struct UndefinedVarDuty <: AbstractVarDuty end

#struct BendersSpVar <: AbstractVarDuty end
#struct BlockGenSpVar <: AbstractVarDuty end
#struct MastRepBlockSpVar <: AbstractVarDuty end

# First level of specification on ConstrDuty
abstract type AbstractOriginalConstr <: AbstractConstrDuty end
abstract type AbstractMasterConstr <: AbstractConstrDuty end
abstract type AbstractDwSpConstr <: AbstractConstrDuty end
abstract type AbstractBendSpConstr <: AbstractConstrDuty end
abstract type AbstractMasterRepOriginalConstr <: AbstractMasterConstr end
abstract type AbstractBendersTechnologicalConstr <: AbstractBendSpConstr end

# Concrete duties for Constraints
"Constraint belongs to the original formulation."
struct OriginalConstr <: AbstractOriginalConstr end

"Constraint belongs to the master formulation and involves only pure master variables."
struct MasterPureConstr <: AbstractMasterConstr end

"Constraint belongs to the master formulation."
struct MasterConstr <: AbstractMasterRepOriginalConstr end # is it correct?

"Convexity constraint of the master formulation."
struct MasterConvexityConstr <: AbstractMasterConstr end

"Branching constraint in the master formulation."
struct MasterBranchConstr <: AbstractMasterRepOriginalConstr end # is is correct?

"Constraint of the pricing subproblem."
struct PricingSpPureConstr <: AbstractDwSpConstr end

"Representation of a branching constraint from the master in the pricing subproblem."
struct PricingSpRepMastBranchConstr <: AbstractDwSpConstr end

struct BendersPureSepConstr <: AbstractBendSpConstr end

struct BendersFeasibilityTechnologicalConstr <: AbstractBendersTechnologicalConstr end

struct BendersPureMasterConstr <: AbstractBendMasterConstr end

struct BendersSecondStageCostConstr <: AbstractMasterConstr end

struct BendersSepSecondStageCostConstr <: AbstractBendersTechnologicalConstr end

struct BendersCutConstr <: AbstractMasterConstr end

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
    OriginalVar, OriginalExpression, PureMastVar, MastRepPricingSpVar,
    MastRepPricingSetupSpVar, PricingSpVar, PricingSpSetupVar, PricingSpPureVar,
    OriginalConstr, MasterPureConstr, MasterConstr, MasterConvexityConstr,
    PricingSpPureConstr
}

const DynamicDuty = Union{
    Type{MasterCol}, Type{MasterBranchConstr},
    Type{PricingSpRepMastBranchConstr}
}

const OriginalRepresentatives = Union{
    Type{PureMastVar}, Type{MastRepPricingSpVar}
}

const ArtificialDuty = Union{Type{MastArtVar}}

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

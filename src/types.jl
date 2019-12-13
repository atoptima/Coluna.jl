abstract type AbstractNode end

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
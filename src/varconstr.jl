abstract type AbstractVarConstr end
abstract type AbstractVarDuty end
abstract type AbstractConstrDuty end

struct VarId <: Integer
    id::Int
end
struct ConstrId <: Integer
    id::Int
end


abstract type AbstractCounter end

mutable struct ConstraintCounter <: AbstractCounter
    value::ConstrId
    ConstraintCounter() = new(0)
end

mutable struct VariableCounter <: AbstractCounter
    value::VarId
    VariableCounter() = new(0)
end

function increment_counter(counter::AbstractCounter)
    counter.value += 1
    return counter.value
end

struct MoiVarDef
    # TODO
end

struct MoiConstrDef
    # TODO
end





# fract_part(val::Float64) = (abs(val - round(val)))

# function is_value_integer(val::Float64, tolerance::Float64)
#     return (fract_part(val) <= tolerance)
# end



# @enum VCSTATUS Inactive Active Unsuitable


# function VarConstrBuilder(counter::VariableCounter,
#                           name::String,
#                           duty::AbstractVarDuty,
#                           cost::Float64,
#                           sense::Char,
#                           vc_type::Char,
#                           flag::Char,
#                           lb::Float64,
#                           ub::Float64,
#                           directive::Char,
#                           priority::Float64)
#     return Variable(increment_counter(counter),
#                     name,
#                     duty,
#                     Formulation(),
#                     cost,
#                     sense,
#                     vc_type,
#                     flag,
#                     lb,
#                     ub,
#                     directive,
#                     priority,
#                     Active,
#                     0.0, 
#                     Dict{VarConstr, Float}())
# end

# function VarConstrBuilder(counter::ConstraintCounter,
#                           name::String,
#                           duty::AbstractConstrDuty,
#                           rhs::Float64,
#                           sense::Char,
#                           vc_type::Char,
#                           flag::Char)
#     return Constraint(increment_counter(counter),
#                       name,
#                       duty,
#                       Formulation(),
#                       rhs,
#                       sense,
#                       vc_type,
#                       flag,
#                       Active,
#                       rhs,
#             Dict{VarConstr, Float}())
# end



# Base.show(io::IO, varconstr::VarConstr) = Base.show(io::IO, varconstr.name)

# const MoiBounds = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float}}

# const MoiVcType = MOI.ConstraintIndex{MOI.SingleVariable,T} where T <: Union{
#     MOI.Integer,MOI.ZeroOne}

# mutable struct MoiVarDef
#     # ```
#     # Index in MOI optimizer
#     # ```
#     var_index::MOI.VariableIndex

#     # ```
#     # Stores the MOI.ConstraintIndex used as lower and upper bounds
#     # ```
#     bounds_index::MoiBounds

#     # ```
#     # Stores the MOI.ConstraintIndex that represents vc_type in coluna
#     # ```
#     type_index::MoiVcType
# end

# function MoiVarDef()
#     return MoiVarDef(MOI.VariableIndex(-1), MoiBounds(-1), MoiVcType{MOI.ZeroOne}(-1))
# end


# struct AbstractVarData # pure Abstract
# end

# struct explicitVarData <: AbstractVarData
#     ev::MoiVarDef # explicit var
# end

# mutable struct MoiConstrDef
#     # ```
#     # Index in MOI optimizer
#     # ```
#     constr_index::MOI.MOI.ConstraintIndex{F,S} where {F,S}

#     # ```
#     # Type of constraint in MOI optimizer
#     # ``
#     set_type::Type{<:MOI.AbstractSet}
# end

# function MoiConstrDef(constr::Constraint)

#     if constr.sense == 'G'
#         set_type = MOI.GreaterThan{Float}
#     elseif constr.sense == 'L'
#         set_type = MOI.LessThan{Float}
#     elseif constr.sense == 'E'
#         set_type = MOI.EqualTo{Float}
#     else
#         error("Sense $sense is not supported")
#     end

#     return MoiConstrDef(MOI.ConstraintIndex{MOI.ScalarAffineFunction,set_type}(-1),
#                         set_type)
# end




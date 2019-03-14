@enum VCSTATUS Inactive Active Unsuitable


Base.show(io::IO, varconstr::VarConstr) = Base.show(io::IO, varconstr.name)

function VarConstrBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
                          sense::Char, vc_type::Char, flag::Char, directive::Char,
                          priority::Float)
    return (increment_counter(counter), name, -1, directive,
            priority, costrhs, sense, vc_type, flag, Active, 0.0, costrhs,
            Dict{VarConstr, Float}(), 0.0)
end

const MoiBounds = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float}}
const MoiVcType = MOI.ConstraintIndex{MOI.SingleVariable,T} where T <: Union{
    MOI.Integer,MOI.ZeroOne}
mutable struct MoiDef
    # ```
    # Index in MOI optimizer
    # ```
    var_index::MOI.VariableIndex

    # ```
    # Stores the MOI.ConstraintIndex used as lower and upper bounds
    # ```
    bounds_index::MoiBounds

    # ```
    # Stores the MOI.ConstraintIndex that represents vc_type in coluna
    # ```
    type_index::MoiVcType
end

function MoiDef()
    return MoiDef(MOI.VariableIndex(-1), MoiBounds(-1), MoiVcType{MOI.ZeroOne}(-1))
end

@hl mutable struct Variable <: VarConstr
    
    # ```
    # Stores the representation of this variable in MOI.
    # ```
    moi_def::MoiDef

    # ```
    # Stores a secondary representation of this variable in MOI.
    # Used when solving the problem with another optimizer
    # i.e.: When doing primal heuristics
    # ```
    secondary_moi_def::MoiDef

    # ```
    # To represent local lower bound on variable primal / constraint dual
    # In the problem which it belongs to
    # ```
    lower_bound::Float

    # ```
    # To represent local upper bound on variable primal / constraint dual
    # In the problem which it belongs to
    # ```
    upper_bound::Float

    # ```
    # Current (local) bound values
    # Used in preprocessing
    # ```
    cur_lb::Float
    cur_ub::Float
end

function VariableBuilder(counter::VarConstrCounter, name::String,
        costrhs::Float, sense::Char, vc_type::Char, flag::Char, directive::Char,
        priority::Float, lb::Float, ub::Float)

    return tuplejoin(
        VarConstrBuilder(counter, name, costrhs, sense, vc_type, flag,
                         directive, priority),
        MoiDef(), MoiDef(), lb, ub, lb, ub)
end

function bounds_changed(var::Variable)
    return (var.cur_lb != var.lower_bound
        || var.cur_ub != var.upper_bound
        || var.cur_cost_rhs != var.cost_rhs)
end

function set_default_currents(var::Variable)
    var.cur_lb = var.lower_bound
    var.cur_ub = var.upper_bound
    var.cur_cost_rhs = var.cost_rhs
end

@hl mutable struct Constraint <: VarConstr
    # ```
    # Index in MOI optimizer
    # ```
    moi_index::MOI.ConstraintIndex{F,S} where {F,S}

    # ```
    # Used when solving the problem with another optimizer
    # i.e.: When doing primal heuristics
    # ``
    secondary_moi_index::MOI.ConstraintIndex{F,S} where {F,S}

    # ```
    # Type of constraint in MOI optimizer
    # ``
    set_type::Type{<:MOI.AbstractSet}
end

function ConstraintBuilder(counter::VarConstrCounter, name::String,
        cost_rhs::Float, sense::Char, vc_type::Char, flag::Char)
    if sense == 'G'
        set_type = MOI.GreaterThan{Float}
    elseif sense == 'L'
        set_type = MOI.LessThan{Float}
    elseif sense == 'E'
        set_type = MOI.EqualTo{Float}
    else
        error("Sense $sense is not supported")
    end

    return tuplejoin(
        VarConstrBuilder(counter, name, cost_rhs, sense, vc_type, flag, 'U', 1.0),
        MOI.ConstraintIndex{MOI.ScalarAffineFunction,set_type}(-1),
        MOI.ConstraintIndex{MOI.ScalarAffineFunction,set_type}(-1),
        set_type
    )
end

function find_first(var_constr_vec::Vector{<:VarConstr}, vc_ref::Int)
    for i in 1:length(var_constr_vec)
        if vc_ref == var_constr_vec[i].vc_ref
            return i
        end
    end
    return 0
end

function cost_rhs_changed(constr::Constraint)
    return constr.cur_cost_rhs != constr.cost_rhs
end

function set_default_currents(constr::Constraint)
    constr.cur_cost_rhs = constr.cost_rhs
end

function switch_primary_secondary_moi_indices(constr::Constraint)
    temp_idx = constr.moi_index
    constr.moi_index = constr.secondary_moi_index
    constr.secondary_moi_index = temp_idx
end

function switch_primary_secondary_moi_def(var::Variable)
    temp_moi_def = var.moi_def
    var.moi_def = var.secondary_moi_def
    var.secondary_moi_def = temp_moi_def
end

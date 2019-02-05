@enum VCSTATUS Inactive Active Unsuitable

mutable struct VarConstrCounter
    value::Int
end

function increment_counter(counter::VarConstrCounter)
    counter.value += 1
    return counter.value
end

@hl mutable struct VarConstr
    vc_ref::Int
    name::String

    # Ref of Problem which this VarConstr is part of
    prob_ref::Int

    # ```
    # 'U' or 'D'
    # ```
    directive::Char

    # ```
    # A higher priority means that var is selected first for branching or diving
    # ```
    priority::Float

    # ```
    # Cost for a variable, rhs for a constraint
    # ```
    cost_rhs::Float

    # ```
    # Variables:
    # sense : 'P' = positive
    # sense : 'N' = negative
    # sense : 'F' = free
    #
    # Constraints:
    # sense : 'G' = greater or equal to
    # sense : 'L' = less or equal to
    # sense : 'E' = equal to
    # ```

    sense::Char

    # ```
    # For Variables:
    # 'C' = continuous,
    # 'B' = binary, or
    # 'I' = integer
    #
    # For Constraints:
    # mutable struct = 'C' for core -required for the IP formulation-,
    # mutable struct = 'F' for facultative -only helpfull to tighten the LP approximation of the IP formulation-,
    # mutable struct = 'S' for constraints defining a subsystem in column generation for
    #            extended formulation approach
    # mutable struct = 'M' for constraints defining a pure master constraint
    # mutable struct = 'X' for constraints defining a subproblem convexity constraint
    #            in the master
    # ```
    vc_type::Char

    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # 'a' for artificial VarConstr.
    # ```
    flag::Char

    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    status::VCSTATUS

    # ```
    # Primal Value for a variable, dual value for a constraint
    # ```
    val::Float

    # ```
    # Temprarity recorded primal Value for a variable in rounding or fixing
    # heuristic -dual value a constraint- used for functions returning fract part
    # ```
    # challengerroundedval::Float

    cur_cost_rhs::Float

    # ```
    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    member_coef_map::Dict{VarConstr, Float}

    reduced_cost::Float
end

Base.show(io::IO, varconstr::VarConstr) = Base.show(io::IO, varconstr.name)

function VarConstrBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
                          sense::Char, vc_type::Char, flag::Char, directive::Char,
                          priority::Float)
    return (increment_counter(counter), name, -1, directive,
            priority, costrhs, sense, vc_type, flag, Active, 0.0, costrhs,
            Dict{VarConstr, Float}(), 0.0)
end

const MoiBounds = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float}}
@hl mutable struct Variable <: VarConstr
    # ```
    # Index in MOI optimizer
    # ```
    moi_index::MOI.VariableIndex

    # ```
    # Used when solving the problem with another optimizer
    # i.e.: When doing primal heuristics
    # ```
    secondary_moi_index::MOI.VariableIndex

    # ```
    # Stores the MOI.ConstraintIndex used as lower and upper bounds
    # ```
    moi_bounds_index::MoiBounds

    # ```
    # Stores the secondary MOI.ConstraintIndex used as lower and upper bounds
    # Used when solving the problem with another optimizer
    # i.e.: When doing primal heuristics
    # ```
    secondary_moi_bounds_index::MoiBounds

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
                         directive, priority), MOI.VariableIndex(-1),
        MOI.VariableIndex(-1), MoiBounds(-1), MoiBounds(-1), lb, ub, lb, ub)
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

function set_initial_cur_cost(constr::Constraint)
    constr.cur_cost_rhs = constr.cost_rhs
end

function find_first(var_constr_vec::Vector{<:VarConstr}, vc_ref::Int)
    for i in 1:length(var_constr_vec)
        if vc_ref == var_constr_vec[i].vc_ref
            return i
        end
    end
    return 0
end

function switch_primary_secondary_moi_indices(vc::VarConstr)
    temp_idx = vc.moi_index
    vc.moi_index = vc.secondary_moi_index
    vc.secondary_moi_index = temp_idx
end

function switch_primary_secondary_moi_indices(var::Variable)
    @callsuper switch_primary_secondary_moi_indices(var::VarConstr)
    # This also changes the bounds index
    temp_idx = var.moi_bounds_index
    var.moi_bounds_index = var.secondary_moi_bounds_index
    var.secondary_moi_bounds_index = temp_idx
end

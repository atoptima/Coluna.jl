@enum VCSTATUS Inactive Active Unsuitable

mutable struct VarConstrCounter
    value::Int
end

function increment_counter(counter::VarConstrCounter)
    counter.value += 1
    return counter.value
end

mutable struct VarConstrStabInfo
end

@hl mutable struct VarConstr
    vc_ref::Int
    name::String

    in_cur_prob::Bool
    in_cur_form::Bool

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
    # Rounding Primal Value for a variable, dual value a constraint
    # ```
    # floorval::Float
    # ceilval::Float

    # ```
    # Closest integer to val
    # ```
    # roundedval::Float

    # ```
    # 'U' or 'D'
    # ```
    # roundedsense::Char

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

    # Needed for VarConstrResetInfo.
    is_info_updated::Bool

    in_preprocessed_list::Bool # added by Ruslan, needed for preprocessing

    reduced_cost::Float

    # ```
    # To hold Info Need for stabilisation of constraint in Col Gen approach and
    # on First stage Variables in Benders approach
    # ```
    stab_info::VarConstrStabInfo

    # ```
    # Treat order of the node where the column has been generated -needed for
    # problem setup-
    # ```
    treat_order_id::Int
    # TODO better be called gen_sequence_number
end

Base.show(io::IO, varconstr::VarConstr) = Base.show(io::IO, varconstr.name)

# Think about this constructor (almost a copy)
function VarConstrBuilder(vc::VarConstr, counter::VarConstrCounter)
    # This is not a copy since some fields are reset to default
    return (increment_counter(counter), "", false, false, vc.directive,
            vc.priority, vc.cost_rhs, vc.sense, vc.vc_type, vc.flag,
            vc.status, vc.val, vc.cur_cost_rhs, copy(vc.member_coef_map), false,
            vc.in_preprocessed_list, vc.reduced_cost, VarConstrStabInfo(), 0)
end

function VarConstrBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
                          sense::Char, vc_type::Char, flag::Char, directive::Char,
                          priority::Float)
    return (increment_counter(counter), name, false, false, directive,
            priority, costrhs, sense, vc_type, flag, Active, 0.0, 0.0,
            Dict{VarConstr, Float}(), false, false, 0.0, VarConstrStabInfo(), 0)
end

@hl mutable struct Variable <: VarConstr
    # ```
    # Flag telling whether or not the variable is fractional.
    # ```
    moi_index::MOI.VariableIndex


    # ```
    # To represent global lower bound on variable primal / constraint dual
    # ```
    lower_bound::Float


    # ```
    # To represent global upper bound on variable primal / constraint dual
    # ```
    upper_bound::Float

    cur_lb::Float
    cur_ub::Float
end

function VariableBuilder(counter::VarConstrCounter, name::String, 
        costrhs::Float, sense::Char, vc_type::Char, flag::Char, directive::Char, 
        priority::Float, lowerBound::Float, upperBound::Float)

    return tuplejoin(VarConstrBuilder( counter, name, costrhs, sense, vc_type,
            flag, directive, priority), MOI.VariableIndex(-1), lowerBound, 
            upperBound, -Inf, Inf)
end

VariableBuilder(var::Variable, counter::VarConstrCounter) = tuplejoin(
        VarConstrBuilder(var, counter),
        (MOI.VariableIndex(-1), -Inf, Inf, -Inf, Inf))

@hl mutable struct Constraint <: VarConstr
    moi_index::MOI.ConstraintIndex{F,S} where {F,S}
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

    return tuplejoin(VarConstrBuilder(counter, name, cost_rhs, sense, vc_type,
            flag, 'U', 1.0),
            MOI.ConstraintIndex{MOI.ScalarAffineFunction,set_type}(-1), set_type)
end

function find_first(var_constr_vec::Vector{<:VarConstr}, vc_ref::Int)
    for i in 1:length(var_constr_vec)
        if vc_ref == var_constr_vec[i].vc_ref
            return i
        end
    end
    return 0
end

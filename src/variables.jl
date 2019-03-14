mutable struct VariableCounter
    value::Int
end

function increment_counter(counter::VariableCounter)
    counter.value += 1
    return counter.value
end

struct Variable{DutyType <: AbstactDuty, DataType <: AbstractVarData}
    uid::Int # unique id
    name::String
    duty::DutyType
    formulation::Formulation
    # ```
    # 'U' or 'D'
    # ```
    directive::Char

    # ```
    # A higher priority means that var is selected first for branching or diving
    # ```
    priority::Float64

    # ```
    # Cost for a variable, rhs for a constraint
    # ```
    cost::Float64

    # ```
    # Variables:
    # sense : 'P' = positive
    # sense : 'N' = negative
    # sense : 'F' = free

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
    v_type::Char

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

        # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    membership::Dict{Constraint, Float64}

    data::DataType
end


@hl mutable struct SubprobVar <: Variable
    # ```
    # To represent global lower bound on sp variable primal value
    # Aggregated bound in master
    # ```
    global_lb::Float

    # ```
    # To represent global upper bound on sp variable primal value
    # Aggregated bound in master
    # ```
    global_ub::Float

    # ```
    # Current global bound values (aggregated in master)
    # Used in preprocessing
    # ```
    cur_global_lb::Float
    cur_global_ub::Float

    # ```
    # Represents the master membership in the master constraints as a map where:
    # - The key is the index of the master constraint including this as member,
    # - The value is the corresponding coefficient.
    # ```
    master_constr_coef_map::Dict{Constraint, Float} # Constraint -> MasterConstr

    # ```
    # Represents the master membership in column solutions as map where:
    # - The key is the index of a column whose solutions includes this as member,
    # - The value is the variable value in the corresponding pricing solution.
    # ```
    master_col_coef_map::Dict{Variable, Float} # Variable -> MasterColumn
end

function SubprobVarBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
        sense::Char, vc_type::Char, flag::Char, directive::Char, priority::Float,
        lowerBound::Float, upperBound::Float, globallb::Float, globalub::Float,
        curgloballb::Float, curglobalub::Float)

    return tuplejoin(VariableBuilder(counter, name, costrhs, sense, vc_type, flag,
            directive, priority, lowerBound, upperBound), globallb, globalub,
            curgloballb, curglobalub, Dict{Constraint,Float}(),
            Dict{Variable,Float}())
end

function bounds_changed(var::SubprobVar)
    changed = @callsuper bounds_changed(var::Variable)
    return (changed || (var.cur_global_lb != var.global_lb)
            || (var.cur_global_ub != var.global_ub))
end

function set_default_currents(var::SubprobVar)
    @callsuper set_default_currents(var::Variable)
    var.cur_global_lb = var.global_lb
    var.cur_global_ub = var.global_ub
end

function set_global_bounds(var::SubprobVar, multiplicity_lb::Float,
                           multiplicity_ub::Float)
    var.global_lb = var.lower_bound * multiplicity_lb
    var.global_ub = var.upper_bound * multiplicity_ub
end

@hl mutable struct MasterVar <: Variable
    # ```
    # Holds the contribution of the master variable in the lagrangian dual bound
    # ```
    dualBoundContrib::Float
end

MasterVarBuilder(v::Variable, counter::VarConstrCounter) = tuplejoin(
        VariableBuilder(v, counter), (0.0,))

function MasterVarBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
        sense::Char, vc_type::Char, flag::Char, directive::Char, priority::Float,
        lowerBound::Float, upperBound::Float)

    return tuplejoin(VariableBuilder(counter, name, costrhs, sense, vc_type,
            flag, directive, priority, lowerBound, upperBound), 0.0)
end

fract_part(val::Float) = (abs(val - round(val)))

function is_value_integer(val::Float, tolerance::Float)
    return (fract_part(val) <= tolerance)
end


struct Constraint{T <: AbstractConstrDuty}
    uid::ConstrId  # unique id
    name::Symbol
    duty::T
    formulation::Formulation
    vc_ref::Int
    rhs::Float64
    # ```
    # sense : 'G' = greater or equal to
    # sense : 'L' = less or equal to
    # sense : 'E' = equal to
    # ```
    sense::Char
    # ```
    # vc_type = 'C' for core -required for the IP formulation-,
    # vc_type = 'F' for facultative -only helpfull to tighten the LP approximation of the IP formulation-,
    # vc_type = 'S' for constraints defining a subsystem in column generation for
    #            extended formulation approach
    # vc_type = 'M' for constraints defining a pure master constraint
    # vc_type = 'X' for constraints defining a subproblem convexity constraint in the master
    # ```
    vc_type::Char
    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # ```
    flag::Char
    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    status
    # ```
    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    var_memvership::VarMembership
end


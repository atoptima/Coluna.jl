struct Variable{T <: AbstractVarDuty}
    uid::Int # unique id
    name::Symbol
    duty::T
    formulation::Formulation
    cost::Float
    # ```
    # sense : 'P' = positive
    # sense : 'N' = negative
    # sense : 'F' = free
    # ```
    sense::Char
    # ```
    # 'C' = continuous,
    # 'B' = binary, or
    # 'I' = integer
    vc_type::Char
    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # 'a' for artificial VarConstr.
    # ```
    flag::Char
    lower_bound::Float
    upper_bound::Float
    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    # ```
    # 'U' or 'D'
    # ```
    directive::Char
    # ```
    # A higher priority means that var is selected first for branching or diving
    # ```
    priority::Float
    status

    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    member_coef_map::Dict{Int, Float64}
end


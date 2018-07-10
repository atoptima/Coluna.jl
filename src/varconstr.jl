@enum VCSTATUS Inactive Active

type VarConstrCounter
    value::Int
end

function incrementcounter(problem)
    problem.counter.value += 1
    return problem.counter.value
end

type VarConstrStabInfo
end

@hl type VarConstr{P}
    vc_ref::Int    
    name::String

    problem::P # needed?

    incurprob::Bool
    incurform::Bool

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
    costrhs::Float

    # ```
    # Variables:
    # sense : 'P' = positive
    # sense : 'N' = negative
    # sense : 'F' = free
    #
    # Constraints: 'G', 'L', or 'E'
    # ```
    sense::Char

    # ```
    # For Variables:
    # 'C' = continuous,
    # 'B' = binary,
    # or 'I' = integer
    # For Constraints:
    # type = 'C' for core -required for the IP formulation-,
    # type = 'F' for facultative -only helpfull for the LP formulation-,
    # type = 'S' for constraints defining a subsystem in column generation for extended formulation approach
    # type = 'M' for constraints defining a pure master constraint
    # type = 'X' for constraints defining a subproblem convexity constraint in the master
    # ```
    vc_type::Char


    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased when the problem is erased-
    # 'd' for generated dynamic VarConstr not belonging to the problem
    # 'a' for artificial VarConstr.
    # ```
    flag::Char


    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = Cannot enter the formulation in current node.
    # ```
    status::VCSTATUS

    # ```
    # Primal Value for a variable, dual value a constraint
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

    curcostrhs::Float

    # ```
    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    membercoefmap::Dict{Int64, Float}

    isinfoupdated::Bool # added by Ruslan, needed for VarConstrResetInfo
    inpreprocessedlist::Bool # added by Ruslan, needed for preprocessing

    reducedcost::Float

    # ```
    # To hold Info Need for stabilisation of constraint in Col Gen approach and
    # on First stage Variables in Benders approach
    # ```
    stabInfo::VarConstrStabInfo

    # ```
    # Treat order of the node where the column has been generated -needed for problem setup-
    # ```
    treatorderid::Int
end


# Think about this constructor (almost a copy)
function VarConstrBuilder(vc::VarConstr) # This is not a copy since some fields are reset to default
    return (incrementcounter(vc.problem), -1, "", vc.problem, false, false, vc.directive, vc.priority,
            vc.costrhs, vc.sense, vc.vc_type, vc.flag, vc.status, vc.val, vc.curcostrhs, copy(vc.membercoefmap),
            false, vc.inpreprocessedlist, vc.reducedcost, VarConstrStabInfo(), 0)
end

function VarConstrBuilder(problem::P, name::String, costrhs::Float, sense::Char, vc_type::Char, flag::Char, 
                          directive::Char, priority::Float) where P
    return (incrementcounter(problem), -1, name, problem, false, false, directive, priority, 
            costrhs, sense, vc_type, flag, Active, 0.0, 0.0, Dict{Int64, Float}(), false, false, 
            0.0, VarConstrStabInfo(), 0)
end

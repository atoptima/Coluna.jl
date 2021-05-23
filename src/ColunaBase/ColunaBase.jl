module ColunaBase

using DynamicSparseArrays, MathOptInterface

const MOI = MathOptInterface

import Base
import Printf

# interface.jl
export AbstractModel, AbstractProblem, AbstractSense, AbstractMinSense, AbstractMaxSense,
    AbstractSpace, AbstractPrimalSpace, AbstractDualSpace

# nestedenum.jl
export NestedEnum, @nestedenum, @exported_nestedenum

# solsandbounds.jl
export Bound, Solution, getvalue, isbetter, diff, gap, printbounds, getsol,
    getstatus, remove_until_last_point

# Statuses
export TerminationStatus, SolutionStatus, OPTIMIZE_NOT_CALLED, OPTIMAL, INFEASIBLE, TIME_LIMIT, 
    NODE_LIMIT, OTHER_LIMIT, UNKNOWN_TERMINATION_STATUS, UNCOVERED_TERMINATION_STATUS, 
    FEASIBLE_SOL, INFEASIBLE_SOL, UNKNOWN_FEASIBILITY, UNKNOWN_SOLUTION_STATUS, 
    UNCOVERED_SOLUTION_STATUS, convert_status

include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")

end

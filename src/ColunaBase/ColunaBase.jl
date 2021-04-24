module ColunaBase

using ..Coluna

using DynamicSparseArrays, MathOptInterface, TimerOutputs

const MOI = MathOptInterface
const TO = TimerOutputs

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
export TerminationStatus, SolutionStatus, OPTIMAL, INFEASIBLE, TIME_LIMIT, 
    NODE_LIMIT, OTHER_LIMIT, UNKNOWN_TERMINATION_STATUS, UNCOVERED_TERMINATION_STATUS, 
    FEASIBLE_SOL, INFEASIBLE_SOL, UNKNOWN_FEASIBILITY, UNKNOWN_SOLUTION_STATUS, 
    UNCOVERED_SOLUTION_STATUS, convert_status

# Storages (TODO : clean)
export RecordsVector, UnitType, Storage, AbstractStorageUnit, AbstractRecord,
    UnitsUsageDict, UnitAccessMode, READ_AND_WRITE, READ_ONLY, NOT_USED, StorageUnitWrapper,
    add_unit_pair_usage!, store_record!, restore_from_records!, getstorageunit, copy_records,
    restore_from_record!, remove_records!, check_records_participation, record_type

include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")
include("storage.jl")

end

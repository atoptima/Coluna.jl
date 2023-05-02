module ColunaBase

include("../MustImplement/MustImplement.jl")
using .MustImplement

using DynamicSparseArrays, MathOptInterface, TimerOutputs, RandomNumbers, Random, SparseArrays

const MOI = MathOptInterface
const TO = TimerOutputs

import BlockDecomposition
import Base
import Printf

# interface.jl
export AbstractModel, AbstractProblem, AbstractSense, AbstractMinSense, AbstractMaxSense,
    AbstractSpace, AbstractPrimalSpace, AbstractDualSpace, getuid, getstorage

# nestedenum.jl
export NestedEnum, @nestedenum, @exported_nestedenum

# solsandbounds.jl
export Bound, Solution, getvalue, getbound, isbetter, best, worst, diff, gap, printbounds,
    getstatus, remove_until_last_point, getmodel, isunbounded, isinfeasible

# Statuses
export TerminationStatus, SolutionStatus, OPTIMIZE_NOT_CALLED, OPTIMAL,
    INFEASIBLE, UNBOUNDED, TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, UNCOVERED_TERMINATION_STATUS, 
    FEASIBLE_SOL, INFEASIBLE_SOL, UNKNOWN_FEASIBILITY, UNKNOWN_SOLUTION_STATUS, 
    UNCOVERED_SOLUTION_STATUS, convert_status

# hashtable
export HashTable, gethash, savesolid!, getsolids

# Storages (TODO : clean)
export UnitType,
    UnitsUsage, UnitPermission, READ_AND_WRITE, READ_ONLY, NOT_USED,
    restore_from_records!,
    getstorageunit, getstoragewrapper

export Storage, RecordUnitManager, AbstractRecordUnit, AbstractRecord, storage_unit,
    record, record_type, storage_unit_type, restore_from_record!, create_record

include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")
include("hashtable.jl")

# TODO: extract storage
include("recordmanager.jl")
include("storage.jl")

end

module ColunaBase

using ..Coluna

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
    INFEASIBLE, DUAL_INFEASIBLE, INFEASIBLE_OR_UNBOUNDED, TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, UNCOVERED_TERMINATION_STATUS, 
    FEASIBLE_SOL, INFEASIBLE_SOL, UNKNOWN_FEASIBILITY, UNKNOWN_SOLUTION_STATUS, 
    UNCOVERED_SOLUTION_STATUS, convert_status

# hashtable
export HashTable, gethash, savesolid!, getsolids

# Storages (TODO : clean)
export UnitType,
    UnitsUsage, UnitPermission, READ_AND_WRITE, READ_ONLY, NOT_USED,
    restore_from_records!,
    getstorageunit, getstoragewrapper

export NewStorage, NewStorageUnitManager, AbstractNewStorageUnit, AbstractNewRecord, new_storage_unit,
    new_record, record_type, storage_unit_type, restore_from_record!, create_record

# mustimplement.jl
export @mustimplement

include("mustimplement.jl")
include("interface.jl")
include("nestedenum.jl")
include("solsandbounds.jl")
include("hashtable.jl")
include("recordmanager.jl")
include("storage.jl")

end

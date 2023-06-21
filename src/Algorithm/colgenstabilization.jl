# mutable struct ColGenStabilizationUnit <: AbstractRecordUnit
#     basealpha::Float64 # "global" alpha parameter
#     curalpha::Float64 # alpha parameter during the current misprice sequence
#     nb_misprices::Int64 # number of misprices during the current misprice sequence
#     pseudo_dual_bound::ColunaBase.Bound # pseudo dual bound, may be non-valid, f.e. when the pricing problem solved heuristically
#     valid_dual_bound::ColunaBase.Bound # valid dual bound
#     stabcenter::Union{Nothing,DualSolution} # current stability center, correspond to cur_dual_bound
#     newstabcenter::Union{Nothing,DualSolution} # to keep temporarily stab. center after update
#     basestabcenter::Union{Nothing,DualSolution} # stability center, corresponding to valid_dual_bound
# end

# function ClB.storage_unit(::Type{ColGenStabilizationUnit}, master::Formulation{DwMaster})
#     return ColGenStabilizationUnit(
#         0.5, 0.0, 0, DualBound(master), DualBound(master), nothing, nothing, nothing
#     )
# end

# mutable struct ColGenStabRecord <: AbstractRecord
#     alpha::Float64
#     dualbound::ColunaBase.Bound
#     stabcenter::Union{Nothing,DualSolution}
# end

# struct ColGenStabKey <: AbstractStorageUnitKey end

# key_from_storage_unit_type(::Type{ColGenStabilizationUnit}) = ColGenStabKey()
# record_type_from_key(::ColGenStabKey) = ColGenStabRecord

# function ClB.record(::Type{ColGenStabRecord}, id::Int, form::Formulation, unit::ColGenStabilizationUnit)
#     alpha = unit.basealpha < 0.5 ? 0.5 : unit.basealpha
#     return ColGenStabRecord(alpha, unit.valid_dual_bound, unit.basestabcenter)
# end

# ClB.record_type(::Type{ColGenStabilizationUnit}) = ColGenStabRecord
# ClB.storage_unit_type(::Type{ColGenStabRecord}) = ColGenStabilizationUnit

# function ClB.restore_from_record!(
#     ::Formulation, unit::ColGenStabilizationUnit, state::ColGenStabRecord
# )
#     unit.basealpha = state.alpha
#     unit.valid_dual_bound = state.dualbound
#     unit.basestabcenter = state.stabcenter
#     return
# end

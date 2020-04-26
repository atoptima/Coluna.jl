struct VarState
    cost::Float64
    lb::Float64
    ub::Float64
end

struct ConstrState
    rhs::Float64
end

"""
    BranchConstrStorage

    Storage to store the current set of branching constraint of a formulation
"""

struct BranchConstrStorState <: AbstractStorageState
    active_constrs::Dict{ConstrId, ConstrState}
end

struct BranchConstrStor{BranchConstrStorState} <: AbstractStorage{BranchConstrStorState}
    form::Formulation
    statesdict::StorageStateDict{BranchConstrStorState}
end

const BranchConstrStorage = BranchConstrStor{BranchConstrStorState}

"""
    BasisStorage

    Storage to store the current LP basis of a formulation
"""

struct BasisStorState <: AbstractStorageState
end

struct BasisStor{BasisStorState} <: AbstractStorage{BasisStorState}
    form::Formulation
    statesdict::StorageStateDict{BasisStorState}
end

const BasisStorage = BasisStor{BasisStorState}
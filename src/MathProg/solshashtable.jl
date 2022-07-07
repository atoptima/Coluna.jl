const mt_seed = 1234567
const mt_mask = 0x0ffff  # hash keys from 1 to 65536

mutable struct SolutionsHashTable
    rng::MersenneTwisters.MT19937
    varid_to_hash::Dict{VarId, Int}
    hash_to_colids::Vector{Vector{VarId}}
end

function SolutionsHashTable()
    return SolutionsHashTable(
        MersenneTwisters.MT19937(mt_seed),
        Dict{VarId, UInt32}(),
        [Vector{VarId}[] for _ in 0:mt_mask]
    )
end

function gethash(sht::SolutionsHashTable, sol::T) where T
    bad_hash = Int(mt_mask) + 2
    acum_hash = UInt32(0)
    for (varid, _) in sol
        hash = UInt32(get(sht.varid_to_hash, varid, bad_hash) - 1)
        if hash > mt_mask
            hash = MersenneTwisters.mt_get(sht.rng) & mt_mask
            sht.varid_to_hash[varid] = Int(hash) + 1
        end
        acum_hash ⊻= hash
    end
    return Int(acum_hash) + 1
end

getcolids(sht::SolutionsHashTable, sol::T) where T = sht.hash_to_colids[gethash(sht, sol)]

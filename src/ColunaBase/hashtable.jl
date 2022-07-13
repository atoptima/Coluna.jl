const MT_SEED = 1234567
const MT_MASK = 0x0ffff  # hash keys from 1 to 65536

"""
This datastructure allows us to quickly find solution that shares the same members:
variables for primal solutions and constraints for dual solutions.
"""
struct HashTable{VarConstrId}
    rng::MersenneTwisters.MT19937
    memberid_to_hash::Dict{VarConstrId, UInt32} # members of the primal/dual solution -> hash
    hash_to_solids::Vector{Vector{VarConstrId}} # hash of the primal/dual solution -> solution id

    HashTable{VarConstrId}() where {VarConstrId} = new(
        MersenneTwisters.MT19937(MT_SEED),
        Dict{VarConstrId, UInt32}(),
        [VarConstrId[] for _ in 0:MT_MASK]
    )
end

function gethash(hashtable::HashTable, sol)
    bad_hash = Int(MT_MASK) + 2
    acum_hash = UInt32(0)
    for (varconstrid, _) in sol
        hash = UInt32(get(hashtable.memberid_to_hash, varconstrid, bad_hash) - 1)
        if hash > MT_MASK
            hash = MersenneTwisters.mt_get(hashtable.rng) & MT_MASK
            hashtable.memberid_to_hash[varconstrid] = Int(hash) + 1
        end
        acum_hash ⊻= hash
    end
    return Int(acum_hash) + 1
end

savesolid!(hashtable::HashTable, solid, sol) = push!(getsolids(hashtable, sol), solid)

getsolids(hashtable::HashTable, sol) = hashtable.hash_to_solids[gethash(hashtable, sol)]

function Base.show(io::IO, ht::HashTable)
    println(io, typeof(ht), ":")
    println(io, " memberid_to_hash : ", ht.memberid_to_hash)
    println(io, " hash_to_solids :")
    for (a,b) in Iterators.filter(a -> !isempty(a[2]), enumerate(ht.hash_to_solids))
        println(io, "\t", a, "=>", b)
    end
    return
end
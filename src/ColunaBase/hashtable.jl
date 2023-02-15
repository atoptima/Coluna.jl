const MT_SEED = 1234567
const MT_MASK = 0x0ffff # hash keys from 1 to 65536

"""
This datastructure allows us to quickly find solution that shares the same members:
variables for primal solutions and constraints for dual solutions.
"""
struct HashTable{MemberId,SolId}
    rng::MersenneTwisters.MT19937
    memberid_to_hash::Dict{MemberId, UInt32} # members of the primal/dual solution -> hash
    hash_to_solids::Vector{Vector{SolId}} # hash of the primal/dual solution -> solution id

    HashTable{MemberId,SolId}() where {MemberId,SolId} = new(
        MersenneTwisters.MT19937(MT_SEED),
        Dict{MemberId, UInt32}(),
        [SolId[] for _ in 0:MT_MASK]
    )
end

function _gethash!(
    hashtable::HashTable{MemberId,SolId}, id::MemberId, bad_hash = Int(MT_MASK) + 2
) where {MemberId,SolId}
    hash = UInt32(get(hashtable.memberid_to_hash, id, bad_hash) - 1)
    if hash > MT_MASK
        hash = MersenneTwisters.mt_get(hashtable.rng) & MT_MASK
        hashtable.memberid_to_hash[id] = Int(hash) + 1
    end
    return hash
end

_gethash!(hashtable, entry::Tuple, bad_hash = Int(MT_MASK) + 2) = 
    _gethash!(hashtable, first(entry), bad_hash)

# By default, we consider that the iterator of the `sol` argument returns a tuple that 
# contains the id as first element.
function gethash(hashtable::HashTable, sol)
    acum_hash = UInt32(0)
    for entry in sol
        acum_hash ⊻= _gethash!(hashtable, entry)
    end
    return Int(acum_hash) + 1
end

# If the solution is in a sparse vector, we just want to check indices associated to non-zero
# values.
function gethash(hashtable::HashTable, sol::SparseVector)
    acum_hash = UInt32(0)
    for nzid in SparseArrays.nonzeroinds(sol)
        acum_hash ⊻= _gethash!(hashtable, nzid)
    end
    return Int(acum_hash) + 1
end

savesolid!(hashtable::HashTable, solid, sol) =
    push!(getsolids(hashtable, sol), solid)

getsolids(hashtable::HashTable, sol) =
    hashtable.hash_to_solids[gethash(hashtable, sol)]

function Base.show(io::IO, ht::HashTable)
    println(io, typeof(ht), ":")
    println(io, " memberid_to_hash : ", ht.memberid_to_hash)
    println(io, " hash_to_solids :")
    for (a,b) in Iterators.filter(a -> !isempty(a[2]), enumerate(ht.hash_to_solids))
        println(io, "\t", a, "=>", b)
    end
    return
end
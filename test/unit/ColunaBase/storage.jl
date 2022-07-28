# Storage units keeps records of a given data structure.
const NB_VARS_CS1 = 15

struct ModelCs1
    char_values::Vector{Char}
    tracked_char_pos::Vector{Int}
end

struct CharUnitStorageCs1 <: ClB.AbstractNewUnitStorage end

ClB.new_unit_storage(::Type{CharUnitStorageCs1}) = CharUnitStorageCs1()

struct CharRecordCs1 <: ClB.AbstractNewRecord
    id::Int
    char_values::Dict{Int, Char}
end

ClB.get_id(r::CharRecordCs1) = r.id
ClB.record_type(::Type{CharUnitStorageCs1}) = CharRecordCs1
ClB.unit_storage_type(::Type{CharRecordCs1}) = CharUnitStorageCs1
function ClB.new_record(::Type{CharRecordCs1}, id::Int, model::ModelCs1, ::CharUnitStorageCs1)
    entries_it = Iterators.filter(
        t -> t[1] ∈ model.tracked_char_pos,
        Iterators.map(t -> (t[1] => t[2]), Iterators.enumerate(model.char_values))
    )
    return CharRecordCs1(id, Dict{Int,Char}(collect(entries_it)))
end

function ClB.restore_from_record!(
    model::ModelCs1, unit::CharUnitStorageCs1, record::CharRecordCs1
)
    for (pos, char) in record.char_values
        @show (pos, char)
        model.char_values[pos] = char
    end
    return
end

@testset "ColunaBase - storage" begin
    model = ModelCs1(fill('A', NB_VARS_CS1), [3,4,5])
    storage = ClB.NewStorage(model)
    r1 = ClB.create_record(storage, CharUnitStorageCs1)
    @show r1
    a = ClB.restore_from_record!(storage, r1)
    @show a

    model.char_values[3] = 'B'
    r2 = ClB.create_record(storage, CharUnitStorageCs1)
    @show r2

    println(0)
    @show model
    println(1)
    @show r1
    ClB.restore_from_record!(storage, r1)
    @show model
    println(2)
    @show r2
    ClB.restore_from_record!(storage, r2)
    @show model
    exit()
end
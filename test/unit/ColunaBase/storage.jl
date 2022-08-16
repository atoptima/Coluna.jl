# Storage units keeps records of a given data structure.
const NB_VARS_CS1 = 6

struct ModelCs1 <: ClB.AbstractModel
    char_values::Vector{Char}
    tracked_char_pos::Vector{Int}
end

function Base.show(io::IO, model::ModelCs1) # TODO remove
    print(io, model.char_values)
end

struct CharStorageUnitCs1 <: ClB.AbstractNewStorageUnit end

ClB.new_storage_unit(::Type{CharStorageUnitCs1}, _) = CharStorageUnitCs1()

struct CharRecordCs1 <: ClB.AbstractNewRecord
    id::Int
    char_values::Dict{Int, Char}
end

ClB.get_id(r::CharRecordCs1) = r.id
ClB.record_type(::Type{CharStorageUnitCs1}) = CharRecordCs1
ClB.storage_unit_type(::Type{CharRecordCs1}) = CharStorageUnitCs1
function ClB.new_record(::Type{CharRecordCs1}, id::Int, model::ModelCs1, ::CharStorageUnitCs1)
    entries_it = Iterators.filter(
        t -> t[1] ∈ model.tracked_char_pos,
        Iterators.map(t -> (t[1] => t[2]), Iterators.enumerate(model.char_values))
    )
    return CharRecordCs1(id, Dict{Int,Char}(collect(entries_it)))
end

function ClB.restore_from_record!(
    model::ModelCs1, ::CharStorageUnitCs1, record::CharRecordCs1
)
    for (pos, char) in record.char_values
        model.char_values[pos] = char
    end
    return
end

@testset "ColunaBase - storage" begin
    model = ModelCs1(fill('A', NB_VARS_CS1), [3,4,5])
    storage = ClB.NewStorage(model)
    r1 = ClB.create_record(storage, CharStorageUnitCs1) # create_record -> save_current_state

    a = ClB.restore_from_record!(storage, r1)

    model.char_values[3] = 'B'
    r2 = ClB.create_record(storage, CharStorageUnitCs1)

    ClB.restore_from_record!(storage, r1)
    @test model.char_values[3] == 'A'

    ClB.restore_from_record!(storage, r2)
    @test model.char_values[3] == 'B'
end
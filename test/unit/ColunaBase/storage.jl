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

    #######
    # READ_WRITE

    # model
    # save_current_state(model, Unit) # uniquement stocker l'id (etat actuel augmente par 1)
    # restore_from_record(model, )
    # restuarer pour lire ->
    # exit()
end


############
######
######
######  THIS IS A TEST FOR THE OLD INTERFACE
######
######
######

# struct CharStorageUnitCs2 <: ClB.AbstractStorageUnit end

# CharStorageUnitCs2(model) = CharStorageUnitCs2()

# struct CharRecordCs2 <: ClB.AbstractRecord
#     char_values::Dict{Int, Char}
# end

# function CharRecordCs2(model::ModelCs1, ::CharStorageUnitCs2)
#     entries_it = Iterators.filter(
#         t -> t[1] ∈ model.tracked_char_pos,
#         Iterators.map(t -> (t[1] => t[2]), Iterators.enumerate(model.char_values))
#     )
#     return CharRecordCs2(Dict{Int,Char}(collect(entries_it)))
# end

# function ClB.restore_from_record!(
#     model::ModelCs1, ::CharStorageUnitCs2, record::CharRecordCs2
# )
#     for (pos, char) in record.char_values
#         model.char_values[pos] = char
#     end
#     return
# end

# @testset "ColunaBase - old storage" begin

#     model = ModelCs1(fill('A', NB_VARS_CS1), [3,4,5])
#     storage = ClB.Storage()
#     storage.units[CharStorageUnitCs2] = ClB.StorageUnitWrapper{ModelCs1,CharStorageUnitCs2,CharRecordCs2}(model)
#     storage_unit = storage.units[CharStorageUnitCs2]


#     units_to_restore = ClB.UnitsUsage()
#     ClB.set_permission!(
#         units_to_restore,
#         storage.units[CharStorageUnitCs2],
#         ClB.READ_AND_WRITE
#     )

#     println("\e[45m A \e[00m")
#     @show storage_unit

#     records = ClB.RecordsVector()

#     ClB.restore_from_records!(units_to_restore, records)
    
#     r1 = ClB.store_record!(storage_unit)
#     push!(records, (storage_unit => r1))

#     println("\e[45m B \e[00m")
#     @show storage_unit
#     @show r1


#     model.char_values[3] = 'B'
#     @show model

#     println("\e[45m C \e[00m")
#     r2 = ClB.store_record!(storage_unit)
#     @show storage_unit
#     @show r2

#     ClB.restore_from_records!(units_to_restore, ClB.copy_records(records))
#     @show storage_unit

#     model.char_values[3] = 'C'

#     println("\e[45m D \e[00m")
#     r3 = ClB.store_record!(storage_unit)
#     @show storage_unit
#     @show r3


#     exit()

#     # exit()
# end
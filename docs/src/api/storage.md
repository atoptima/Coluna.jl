```@meta
EditURL = "<unknown>/src/api/storage.jl"
```

# Storage API

```@meta
      CurrentModule = Coluna
```

## API

To summarize from a developer's point of view, there is a one-to-one correspondence between
storage unit types and record types.
This correspondence is implemented by methods
`record_type(StorageUnitType)` and `storage_unit_type(RecordType)`.

The developer must also implement methods `storage_unit(StorageUnitType)` and
`record(RecordType, id, model, storage_unit)` that must call constructors of the custom
storage unit and one of its associated records.
Arguments of `record` allow the developer to record the state of entities from
both the storage unit and the model.

At last, he must implement `restore_from_record!(storage_unit, model, record)` to restore the
state of the entities represented by the storage unit.
Entities can be in the storage unit, the model, or both of them.

```@docs
    ColunaBase.record_type
    ColunaBase.storage_unit_type
    ColunaBase.storage_unit
    ColunaBase.record
    ColunaBase.restore_from_record!
```

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*


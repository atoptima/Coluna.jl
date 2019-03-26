
mutable struct VarCounter <: AbstractCounter
    value::VarId
    VarCounter() = new(0)
end
mutable struct ConstrCounter <: AbstractCounter
    value::ConstrId
    ConstrCounter() = new(0)
end
mutable struct FormCounter <: AbstractCounter
    value::FormId
    FormCounter() = new(-1) # 0 is for the original formulation
end

function getnewuid(counter::AbstractCounter)
    counter.value = (counter.value + 1)
    return counter.value
end

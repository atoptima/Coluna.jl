struct Manager{T <: AbstractVarConstr}
    container::Dict{Int, T}
end

function Manager{T}() where {T <: AbstractVarConstr}
    return Manager(Dict{Int, T}())
end
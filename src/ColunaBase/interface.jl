abstract type AbstractModel end

function getuid(m::AbstractModel)
    @warn "getuid(::$(typeof(m))) no implemented."
    return nothing
end

"Return the storage of a model."
function getstorage(m::AbstractModel)
    @warn("Model of type $(typeof(m)) does not have getstorage implemented.")
    return nothing
end

abstract type AbstractProblem end

abstract type AbstractSense end
abstract type AbstractMinSense <: AbstractSense end
abstract type AbstractMaxSense <: AbstractSense end

abstract type AbstractSpace end
abstract type AbstractPrimalSpace <: AbstractSpace end
abstract type AbstractDualSpace <: AbstractSpace end


function remove_until_last_point(str::String)
    lastpointindex = findlast(isequal('.'), str) 
    shortstr = SubString(
        str, lastpointindex === nothing ? 1 : lastpointindex + 1, length(str)
    )
    return shortstr
end

function Base.show(io::IO, model::AbstractModel)
    shorttypestring = remove_until_last_point(string(typeof(model)))
    print(io, "model ", shorttypestring)
end
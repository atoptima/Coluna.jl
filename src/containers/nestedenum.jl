abstract type NestedEnum end

function ←(a::T, b::T) where {T <: NestedEnum}
    return a.id % b.id == 0
end
export ←

function _store!(expr::Symbol, i, names, parent_pos, leaves, primes)
    names[i] = expr
    parent_pos[i] = 0 # No parent
    leaves[i] = true
    primes[i] = Primes.prime(i)
    return
end

function _store!(expr::Expr, i, names, parent_pos, leaves, primes)
    expr.head == :call || error("Syntax.")
    expr.args[1] == :← || error("Syntax 2.")
    i > 1 || error("Parent not registered.")

    name = expr.args[2]
    parent_name = expr.args[3]

    r = findall(n -> n == parent_name, names[1:i-1])
    length(r) == 0 && error("Cannot find parent name.")
    length(r) > 1 && error("Element $parent_name registered more than once.")
    parent_pos[i] = r[1]
    names[i] = name
    leaves[i] = true
    primes[i] = Primes.prime(i)
    return
end

function _compute_values!(values, parent_pos, primes)
    for i in 1:length(parent_pos)
        factor = 1.0
        j = parent_pos[i]
        if j != 0
            factor = values[j]
        end
        values[i] = primes[i] * factor
    end
    return
end

macro nestedenum(expr)
    len = length(expr.args)
    names = Array{Symbol}(undef, len)
    parent_pos = zeros(Int, len)
    leaves = falses(len)
    primes = zeros(Int, len)
    values = zeros(UInt32, len)

    @assert expr.head == :tuple
    name_values = Dict{Symbol, Int}() 
    for (i, arg) in enumerate(expr.args)
        _store!(arg, i, names, parent_pos, leaves, primes)
    end

    _compute_values!(values, parent_pos, primes)

    root_name = names[1]
    enum_expr = Expr(:block, :(struct $root_name <: Coluna.NestedEnum id::UInt end))

    for i in 2:len
        push!(enum_expr.args, :($(names[i]) = $(root_name)(UInt($(values[i])))))
    end

    # @show root_name
    # @show names
    # @show parent_pos
    # @show primes
    # @show values

    @show enum_expr
    return esc(enum_expr)
end
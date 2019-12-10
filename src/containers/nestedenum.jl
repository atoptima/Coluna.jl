abstract type NestedEnum end

import Base.<=

function <=(a::T, b::T) where {T <: NestedEnum}
    return a.id % b.id == 0
end

# Store the item defined in expr at position i
function _store!(expr::Symbol, i, names, parent_pos, primes)
    names[i] = expr
    parent_pos[i] = 0 # No parent
    primes[i] = Primes.prime(i)
    return
end

# Store the item defined in expr at position i
function _store!(expr::Expr, i, names, parent_pos, primes)
    expr.head == :call || error("Syntax error :  Child <= Parent ")
    expr.args[1] == :(<=) || error("Syntax error : Child <= Parent ")
    i > 1 || error("First element cannot have a parent.")

    name = expr.args[2]
    parent_name = expr.args[3]

    r = findall(n -> n == parent_name, names[1:i-1])
    length(r) == 0 && error("Unknow parent $(parent_name).")
    length(r) > 1 && error("$(parent_name) registered more than once.")
    parent_pos[i] = r[1]
    names[i] = name
    primes[i] = Primes.prime(i)
    return
end

# Compute the value of each item. The value is equal to the multiplication of 
# the prime numbers assigned to the item and its ancestors.
function _compute_values!(values, parent_pos, primes)
    for i in 1:length(parent_pos)
        factor = 1
        j = parent_pos[i]
        if j != 0
            factor = values[j]
        end
        values[i] = primes[i] * factor
    end
    return
end

"""
    @nestedenum begin 
        Root
        ChildA <= Root
            GrandChildA1 <= ChildA
            GrandChildA2 <= ChildA
        ChildB <= Root
        ChildC <= Root
    end

Create a nested enumeration with name `Root` and items `ChildA`, 
`GrandChildA1`, `GrandChildA2`, `ChildB`, and `ChildC`.
The operator `<=` indicates the parent of the item.
In this example, `Root` is parent of `ChildA`, `ChildB`, and `ChildC`;
`Root` is grand-parent of `GrandChildA1` and `GrandChildA2`;
`ChildA` is parent of `GrandChildA1` and `GrandChildA2`.
"""
macro nestedenum(expr)
    Base.remove_linenums!(expr)

    expr.head == :block || error("Block expression expected.")

    len = length(expr.args)
    names = Array{Symbol}(undef, len)
    parent_pos = zeros(Int, len) # Position of the parent.
    primes = zeros(Int, len) # We assign a prime to each item.
    values = zeros(UInt32, len) # The value is the multiplication of primes of the item and its ancestors.

    name_values = Dict{Symbol, Int}() 
    for (i, arg) in enumerate(expr.args)
        _store!(arg, i, names, parent_pos, primes)
    end

    _compute_values!(values, parent_pos, primes)

    root_name = names[1]
    enum_expr = Expr(:block, :(struct $root_name <: Coluna.NestedEnum id::UInt end))

    for i in 2:len
        push!(enum_expr.args, :($(names[i]) = $(root_name)(UInt($(values[i])))))
    end
    return esc(enum_expr)
end
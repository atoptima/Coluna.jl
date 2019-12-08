function _store!(expr::Symbol, i, names, parent_pos, leaves, primes)
    names[i] = expr
    parent_pos[i] = 0 # No parent
    leaves[i] = true
    primes[i] = Primes.prime(i)
    return
end

function _store!(expr::Expr, i, names, parent_pos, leaves, primes)
    expr.head == :(<:) || error("Syntax.")
    i > 1 || error("Parent not registered.")

    name = expr.args[1]
    parent_name = expr.args[2]

    r = findall(n -> n == parent_name, names[1:i-1])
    length(r) == 0 && error("Cannot find parent name.")
    length(r) > 1 && error("Element $parent_name registered more than once.")
    parent_pos[i] = r[1]
    names[i] = name
    leaves[i] = true
    primes[i] = Primes.prime(i)
    return
end

macro nestedenum(typename, expr)
    len = length(expr.args)
    names = Array{Symbol}(undef, len)
    parent_pos = zeros(Int, len)
    leaves = falses(len)
    primes = zeros(Int, len)
    values = zeros(Int, len)

    println("\e[31m NESTED ENUMERATION \e[00m")
    @assert expr.head == :tuple
    name_values = Dict{Symbol, Int}() 
    for (i, arg) in enumerate(expr.args)
        _store!(arg, i, names, parent_pos, leaves, primes)
    end

    # TODO compute values
    # TODO generate code

    @show typename
    @show names
    @show parent_pos
    @show primes
    @show values
    return
end
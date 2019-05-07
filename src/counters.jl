mutable struct Counter
    value::Int
end
Counter() = Counter(0)
getnewuid(counter::Counter) = counter.value += 1

function interface(::Type{StartNode}, ::Type{ColumnGeneration}, f, n)
    setup(ColumnGeneration, f, n)
end

function interface(::Type{ColumnGeneration}, ::Type{MasterIpHeuristic}, f, n)
    println("\e[33m interface between column generation and masteripheuristic \e[00m")
end
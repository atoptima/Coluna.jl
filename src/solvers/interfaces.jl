# Beginning of a node -> ColumnGeneration
# Nothing to do
function interface!(::Type{StartNode}, ::Type{ColumnGeneration}, formulation, 
                    node)
    return
end

# ColumnGeneration -> MasterIpHeuristic
function interface!(::Type{ColumnGeneration}, ::Type{MasterIpHeuristic}, 
                    formulation, node)
    println("\e[33m interface between column generation and masteripheuristic \e[00m")
    return
end
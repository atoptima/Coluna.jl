# Beginning of a node -> ColumnGeneration
# Nothing to do
function interface!(::Type{StartNode}, ::Type{ColumnGeneration}, formulation, 
                    node)
    return
end

# ColumnGeneration -> MasterIpHeuristic
# Nothing to do
function interface!(::Type{ColumnGeneration}, ::Type{MasterIpHeuristic}, 
                    formulation, node)
    return
end

# MasterIpHeuristic -> Generate Children Nodes
# Nothing to do
function interface!(::Type{MasterIpHeuristic}, ::Type{GenerateChildrenNode}, 
                    formulation, node)
    return
end

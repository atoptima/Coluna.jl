# Beginning of a node -> ColumnGeneration
# Nothing to do
function interface!(::Type{StartNode}, D::Type{ColumnGeneration}, form, 
                    node, params)
    return
end

# ColumnGeneration -> MasterIpHeuristic
# Nothing to do
function interface!(S::Type{ColumnGeneration}, D::Type{MasterIpHeuristic}, 
                    form, node, params)
    setdown!(S, form, node, params)
    return
end

# ColumnGeneration -> Generate Children Nodes
# Nothing to do
function interface!(S::Type{ColumnGeneration}, D::Type{GenerateChildrenNode},
                    form, node, params)
    setdown!(S, form, node, params)
    return
end

# MasterIpHeuristic -> Generate Children Nodes
# Nothing to do
function interface!(S::Type{MasterIpHeuristic}, D::Type{GenerateChildrenNode}, 
                    form, node, params)
    setdown!(S, form, node, params)
    return
end

#GenerateChildrenNode -> End
# Nothing to do
function interface!(S::Type{GenerateChildrenNode}, ::Type{EndNode},
                    form, node, params)
    setdown!(S, form, node, params)
    return
end
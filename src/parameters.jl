@with_kw type Params
    max_num_nodes::Int = 100000
    open_nodes_limit::Int = 100000
    mip_tolerance_integrality::Float = 1e-5
    cut_up::Float = 1e+75
    cut_lo::Float = -Inf
    limit_on_tree_size_to_update_best_dual_bound::Int = 20
end

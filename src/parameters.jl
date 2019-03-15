@enum(SEARCHSTRATEGY, DepthFirst, BestDualBound)
@enum(NODEEVALMODE, SimplexCg, Lp)
@enum(ARTVARSMOE, Global, Local)

@with_kw mutable struct Params
    use_restricted_master_heur::Bool = false
    restricted_master_heur_solver_type::DataType = GLPK.Optimizer
    max_num_nodes::Int = 100000
    open_nodes_limit::Int = 100000
    mip_tolerance_integrality::Float = 1e-5
    cut_up::Float = Inf
    cut_lo::Float = -Inf
    limit_on_tree_size_to_update_best_dual_bound::Int = 1000000
    apply_preprocessing::Bool = false
    search_strategy::SEARCHSTRATEGY = DepthFirst
    force_copy_names::Bool = false
    node_eval_mode::NODEEVALMODE = SimplexCg
    art_vars_mode::ARTVARSMOE = Global
end

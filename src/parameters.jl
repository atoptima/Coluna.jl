@enum(SEARCHSTRATEGY, DepthFirst, BestDualBound)
@enum(NODEEVALMODE, SimplexCg, Lp)
@enum(ARTVARSMOE, Global, Local)

Base.@kwdef mutable struct Params
    max_num_nodes::Int = 1
    open_nodes_limit::Int = 100000
    mip_tolerance_integrality::Float64 = 1e-5
    cut_up::Float64 = Inf
    cut_lo::Float64 = -Inf
    search_strategy::SEARCHSTRATEGY = DepthFirst
    force_copy_names::Bool = false
    art_vars_mode::ARTVARSMOE = Global
end

update_field!(f_v::Tuple{Symbol,Any}) = setfield!(_params_, f_v[1], f_v[2])
_set_global_params(p::Params) = map(update_field!, [(f, getfield(p, f)) for f in fieldnames(Params)])


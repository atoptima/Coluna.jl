mutable struct Model <: AbstractModel
    name::String
    mid2cid_map::MOIU.IndexMap
    original_formulation::Union{Nothing, Formulation}
    re_formulation::Union{Nothing, Reformulation}
    var_counter::VarCounter
    constr_counter::ConstrCounter
    form_counter::FormCounter
    var_annotations:: Dict{VarId, BD.Annotation}
    constr_annotations:: Dict{ConstrId, BD.Annotation}
    timer_output::TimerOutputs.TimerOutput
    params::Params
    master_factory::Union{Nothing, JuMP.OptimizerFactory}
    pricing_factory::Union{Nothing, JuMP.OptimizerFactory}
    #problemidx_optimizer_map::Dict{Int, MOI.AbstractOptimizer}
end

Model(params::Params, master_factory, pricing_factory) = Model("model", MOIU.IndexMap(), nothing, nothing, 
    VarCounter(), ConstrCounter(), FormCounter(), Dict{VarId, BD.Annotation}(), 
    Dict{ConstrId, BD.Annotation}(), TimerOutputs.TimerOutput(), params, master_factory, pricing_factory)

function set_original_formulation!(m::Model, of::Formulation)
    m.original_formulation = of
    return
end

function set_re_formulation!(m::Model, r::Reformulation)
    m.re_formulation = r
    return
end

get_original_formulation(m::Model) = m.original_formulation
get_re_formulation(m::Model) = m.re_formulation
moi2cid(m::Model, mid) = m.mid2cid_map[mid] 

# @hl mutable struct Callback end

# mutable struct Model # user model
#     extended_problem::Union{Nothing, Reformulation}
#     callback::Callback
#     params::Params
#     prob_counter::ProblemCounter
#     problemidx_optimizer_map::Dict{Int,MOI.AbstractOptimizer}
# end

# function ModelConstructor(params = Params();
#                           with_extended_prob = true)

#     callback = Callback()
#     prob_counter = ProblemCounter(-1) # like cplex convention of prob_ref
#     vc_counter = VarConstrCounter(0)
#     if with_extended_prob
#         extended_problem = Reformulation(prob_counter, vc_counter, params,
#                                            params.cut_up, params.cut_lo)
#     else
#         extended_problem = nothing
#     end
#     return Model(extended_problem, callback, params, prob_counter,
#                  Dict{Int,MOI.AbstractOptimizer}())
# end

function create_root_node(extended_problem::Reformulation, params::Params)
    return Node(extended_problem, -Inf, ProblemSetupInfo(), params)
end

function set_model_optimizers(model::Model)
    initialize_problem_optimizer(model.re_formulation,
                                 model.problemidx_optimizer_map)
end

#function select_eval_alg(extended_problem::Reformulation, node_eval_mode::NODEEVALMODE)
#    if node_eval_mode == SimplexCg
#        return AlgToEvalNodeBySimplexColGen(extended_problem)
#    elseif node_eval_mode == Lp
#        return AlgToEvalNodeByLp(extended_problem)
#    else
 #       error("Invalid eval mode: ", node_eval_mode)
#    end
#end

# # Add Manager to take care of parallelism.
# # Maybe inside optimize!(extended_problem::Reformulation) (?)

# function initialize_convexity_constraints(extended_problem::Reformulation)
#     for pricing_prob in extended_problem.pricing_vect
#         add_convexity_constraints(extended_problem, pricing_prob)
#     end
# end

function initialize_artificial_variables(extended_problem::Reformulation)
    master = extended_problem.master_problem
    init_manager(extended_problem.art_var_manager, master)
    for constr in master.constr_manager.active_static_list
        attach_art_var(extended_problem.art_var_manager, master, constr)
    end
end

function coluna_initialization(model::Model)
    #params = model.params
    #extended_problem = model.extended_problem

    _set_global_params(model.params)
    reformulate!(model, DantzigWolfeDecomposition)

    #set_prob_ref_to_problem_dict(extended_problem)
    #set_model_optimizers(model)
    #initialize_convexity_constraints(extended_problem)
    #initialize_artificial_variables(extended_problem)
    #load_problem_in_optimizer(extended_problem)
end

# # Behaves like optimize!(problem::Problem), but sets parameters before
# # function optimize!(problem::Reformulation)

function optimize!(m::Model)
    coluna_initialization(m)
    global __initial_solve_time = time()
    @show m.params
    @timeit m.timer_output "Solve model" begin
        status = optimize!(m.re_formulation, m.params)
    end
    println(m.timer_output)
end

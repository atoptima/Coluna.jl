mutable struct Problem <: AbstractProblem
    name::String
    # mid2uid_map::MOIU.IndexMap
    # mid2cid_map::Dict{MOI.Index, Tuple{Id, AbstractVarConstr}}
    original_formulation::Union{Nothing, Formulation}
    re_formulation::Union{Nothing, Reformulation}
    var_counter::VarCounter
    constr_counter::ConstrCounter
    form_counter::FormCounter

    var_annotations:: PerIdDict{VarState,BD.Annotation}
    constr_annotations:: PerIdDict{ConstrState,BD.Annotation}

    # var_annotations:: Dict{Tuple{Id{VarState}, Variable}, BD.Annotation}
    # constr_annotations:: Dict{Tuple{Id{ConstrState}, Constraint}, BD.Annotation}

    timer_output::TimerOutputs.TimerOutput
    params::Params
    master_factory::Union{Nothing, JuMP.OptimizerFactory}
    pricing_factory::Union{Nothing, JuMP.OptimizerFactory}
    #problemidx_optimizer_map::Dict{Int, MOI.AbstractOptimizer}
end

function Problem(params::Params, master_factory, pricing_factory)
    return Problem(
        "prob", nothing, nothing, VarCounter(), ConstrCounter(), FormCounter(),
        PerIdDict{VarState,BD.Annotation}(),
        PerIdDict{ConstrState,BD.Annotation}(), TimerOutputs.TimerOutput(),
        params, master_factory, pricing_factory
    )
end

function set_original_formulation!(m::Problem, of::Formulation)
    m.original_formulation = of
    return
end

function set_re_formulation!(m::Problem, r::Reformulation)
    m.re_formulation = r
    return
end

get_original_formulation(m::Problem) = m.original_formulation
get_re_formulation(m::Problem) = m.re_formulation
moi2cid(m::Problem, mid) = m.mid2cid_map[mid] 

# @hl mutable struct Callback end

# mutable struct Problem # user model
#     extended_problem::Union{Nothing, Reformulation}
#     callback::Callback
#     params::Params
#     prob_counter::ProblemCounter
#     problemidx_optimizer_map::Dict{Int,MOI.AbstractOptimizer}
# end

# function ProblemConstructor(params = Params();
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
#     return Problem(extended_problem, callback, params, prob_counter,
#                  Dict{Int,MOI.AbstractOptimizer}())
# end

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


_red(s::String) = string("\e[1;31m ", s, " \e[00m")
_green(s::String) = string("\e[1;32m ", s, " \e[00m")
_pink(s::String) = string("\e[1;35m ", s, " \e[00m")
function call_attention()
    for i in 1:10
        print(_red("!"))
        print(_green("!"))
        print(_pink("!"))
    end
    println()
end

function load_problem_in_optimizer(prob::Problem)
    load_problem_in_optimizer(prob.re_formulation)
end

function initialize_moi_optimizer(prob::Problem)
    initialize_moi_optimizer(
        prob.re_formulation, prob.master_factory, prob.pricing_factory
    )
    println(_pink("---------------> Problems loaded to MOI <---------------------------"))
end

function coluna_initialization(prob::Problem)
 
    _set_global_params(prob.params)
    reformulate!(prob, DantzigWolfeDecomposition)
    initialize_moi_optimizer(prob)
    load_problem_in_optimizer(prob)

    call_attention()
end

# # Behaves like optimize!(problem::Problem), but sets parameters before
# # function optimize!(problem::Reformulation)

function optimize!(prob::Problem)
    coluna_initialization(prob)
    global __initial_solve_time = time()
    @show _params_
    @timeit prob.timer_output "Solve prob" begin
        status = optimize!(prob.re_formulation)
    end
    println(prob.timer_output)
end

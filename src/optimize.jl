function _welcome_message()
    welcome = """
    Coluna
    Version $(version()) | https://github.com/atoptima/Coluna.jl
    """
    print(welcome)
end

function _adjust_params(params, init_pb)
    if params.global_art_var_cost === nothing
        if init_pb != Inf && init_pb != -Inf
            exp = ceil(log(10, init_pb))
            params.global_art_var_cost = 10^(exp + 1)
        else
            params.global_art_var_cost = 100000.0
        end
    end
    if params.local_art_var_cost === nothing
        if init_pb != Inf && init_pb != -Inf
            exp = ceil(log(10, init_pb))
            params.local_art_var_cost = 10^exp
        else
            params.local_art_var_cost = 10000.0
        end
    end
    return
end

"""
Starting point of the solver.
"""
function optimize!(env::Env, prob::MathProg.Problem, annotations::Annotations)
    _welcome_message()

    buffer_reset = prob.original_formulation.buffer
    ann_pf_reset = annotations.ann_per_form

    # Adjust parameters
    ## Retrieve initial bounds on the objective given by the user
    init_pb = get_initial_primal_bound(prob)
    init_db = get_initial_dual_bound(prob)
    init_cols = prob.initial_columns_callback
    _adjust_params(env.params, init_pb)

    # Apply decomposition
    reformulate!(prob, annotations, env)

    # Coluna ready to start
    set_optim_start_time!(env)
    @logmsg LogLevel(-1) "Coluna ready to start."
    @logmsg LogLevel(-1) env.params

    TO.@timeit _to "Coluna" begin
        outstate, algstate = optimize!(get_optimization_target(prob), env, init_pb, init_db, init_cols)
    end

    env.kpis.elapsed_optimization_time = elapsed_optim_time(env)
    prob.original_formulation.buffer = buffer_reset
    annotations.ann_per_form = ann_pf_reset

    println(_to)
    TO.reset_timer!(_to)

    @logmsg LogLevel(0) "Terminated"
    @logmsg LogLevel(0) string("Primal bound: ", get_ip_primal_bound(outstate))
    @logmsg LogLevel(0) string("Dual bound: ", get_ip_dual_bound(outstate))
    return outstate, algstate
end

function optimize!(
    reform::MathProg.Reformulation, env::Env, initial_primal_bound, initial_dual_bound,
    initial_columns
)
    master = getmaster(reform)
    initstate = OptimizationState(
        master,
        ip_primal_bound = initial_primal_bound,
        ip_dual_bound = initial_dual_bound,
        lp_dual_bound = initial_dual_bound
    )

    algorithm = env.params.solver

    # retrieve initial columns
    MathProg.initialize_solution_pools!(reform, initial_columns)

    # initialize all the units used by the algorithm and its child algorithms
    Algorithm.initialize_storage_units!(reform, algorithm)    

    print(IOContext(stdout, :user_only => true), reform)

    algstate = Algorithm.run!(algorithm, env, reform, initstate)

    # we copy optimisation state as we want to project the solution to the compact space
    outstate = OptimizationState(
        master,
        termination_status = getterminationstatus(algstate),
        ip_primal_bound = get_ip_primal_bound(algstate),
        ip_dual_bound = get_ip_dual_bound(algstate),
        lp_primal_bound = get_lp_primal_bound(algstate),
        lp_dual_bound = get_lp_dual_bound(algstate)
    )

    ip_primal_sols = get_ip_primal_sols(algstate)
    if !isnothing(ip_primal_sols)
        for sol in ip_primal_sols
            add_ip_primal_sol!(outstate, proj_cols_on_rep(sol))
        end
    end

    # lp_primal_sol may also be of interest, for example when solving the relaxation
    lp_primal_sol = get_best_lp_primal_sol(algstate)
    if !isnothing(lp_primal_sol)
        add_lp_primal_sol!(outstate, proj_cols_on_rep(lp_primal_sol))
    end

    # lp_dual_sol to retrieve, for instance, the dual value of generated cuts
    lp_dual_sol = get_best_lp_dual_sol(algstate)
    if !isnothing(lp_dual_sol)
        add_lp_dual_sol!(outstate, lp_dual_sol)
    end

    # It returns two optimisation states.
    # The first one contains the solutions projected on the original formulation.
    # The second one contains the solutions to the master formulation so the user can
    # retrieve the disagreggated solution.

    return outstate, algstate
end

function optimize!(
    form::MathProg.Formulation, env::Env, initial_primal_bound, initial_dual_bound, _
)
    initstate = OptimizationState(
        form,
        ip_primal_bound = initial_primal_bound,
        ip_dual_bound = initial_dual_bound,
        lp_dual_bound = initial_dual_bound
    )
    algorithm = env.params.solver
    output = Algorithm.run!(algorithm, env, form, initstate)
    return output, nothing
end

"""
Fallback if no solver provided by the user.
"""
function optimize!(::MathProg.Reformulation, ::Nothing, ::Real, ::Real, _)
    error("""
        No solver to optimize the reformulation. You should provide a solver through Coluna parameters. 
        Please, check the starting guide of Coluna.
    """)
end

function optimize!(::MathProg.Formulation, ::Nothing, ::Real, ::Real, _)
    error("""
        No solver to optimize the formulation. You should provide a solver through Coluna parameters. 
        Please, check the starting guide of Coluna.
    """)
end
####################################################################
#                      ParameterizedHeuristic
####################################################################

struct ParameterizedHeuristic{A <: AlgoAPI.AbstractAlgorithm}
    algorithm::A
    root_priority::Float64
    nonroot_priority::Float64
    frequency::Integer
    max_depth::Integer
    name::String
end

ParamRestrictedMasterHeuristic() = 
    ParameterizedHeuristic(
        RestrictedMasterHeuristic(), 
        1.0, 1.0, 1, 1000, "Restricted Master IP"
    )

####################################################################
#                      NodeFinalizer
####################################################################

struct NodeFinalizer <: AbstractConquerAlgorithm
    algorithm::AbstractOptimizationAlgorithm
    min_depth::Integer
    name::String
end

####################################################################
#                      BeforeCutGenAlgo
####################################################################

"Algorithm called before cut generation."
struct BeforeCutGenAlgo <: AbstractConquerAlgorithm
    algorithm::AbstractOptimizationAlgorithm
    name::String
end

get_child_algorithms(algo::BeforeCutGenAlgo, reform::Reformulation) = Dict("algorithm" => (algo.algorithm, reform))

####################################################################
#                      BendersConquer
####################################################################

@with_kw struct BendersConquer <: AbstractConquerAlgorithm 
    benders::BendersCutGeneration = BendersCutGeneration()
end

# BendersConquer does not use any unit for the moment, it just calls 
# BendersCutSeparation algorithm, therefore get_units_usage() is not defined for it

get_child_algorithms(algo::BendersConquer, reform::Reformulation) = Dict("benders" => (algo.benders, reform))

function run!(algo::BendersConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    # !run_conquer(input) && return
    # node = getnode(input)    
    # node_state = <optimization state of node>
    # output = run!(algo.benders, env, reform, node_state)
    # update!(node_state, output)
    return
end

####################################################################
#                      ColCutGenConquer
####################################################################

"""
    Coluna.Algorithm.ColCutGenConquer(
        colgen = ColumnGeneration(),
        primal_heuristics = ParameterizedHeuristic[ParamRestrictedMasterHeuristic()],
        cutgen = CutCallbacks(),
        max_nb_cut_rounds = 3
    )

Column-and-cut-generation based algorithm to find primal and dual bounds for a 
problem decomposed using Dantzig-Wolfe paradigm.

This algorithm applies a set of column generation algorithms whose definitions are
stored in `stages`. These algorithms are called in the reverse order of vector `stages`.
So usually, the first stage is the one with exact pricing, and other stages use heuristic pricing (the higher is the position of the stage, 
the faster is the heuristic).

This algorithm also applies `cutgen` for the cut generation phase.
It can apply several primal heuristics stored in `primal_heuristics` to more efficiently find feasible solutions.

Parameters :
- `stages`: column generation algorithms from the exact one to the most heuristic one
- `primal_heuristics`: heuristics to find a feasible solution
- `cutgen`: cut generation algorithm
- `max_nb_cut_rounds` : number of cut generation done by the algorithm
"""
struct ColCutGenConquer <: AbstractConquerAlgorithm 
    colgen::ColumnGeneration
    primal_heuristics::Vector{ParameterizedHeuristic}
    before_cutgen_user_algorithm::Union{Nothing, BeforeCutGenAlgo}
    node_finalizer::Union{Nothing, NodeFinalizer}
    preprocess
    cutgen
    max_nb_cut_rounds::Int # TODO : tailing-off ?
    opt_atol::Float64# TODO : force this value in an init() method
    opt_rtol::Float64 # TODO : force this value in an init() method
end

ColCutGenConquer(;
        colgen = ColumnGeneration(),
        primal_heuristics = [ParamRestrictedMasterHeuristic()],
        before_cutgen_user_algorithm = nothing,
        node_finalizer = nothing,
        preprocess = nothing,
        cutgen = CutCallbacks(),
        max_nb_cut_rounds = 3,
        opt_atol = AlgoAPI.default_opt_atol(),
        opt_rtol = AlgoAPI.default_opt_rtol()
) = ColCutGenConquer(
    colgen, 
    primal_heuristics, 
    before_cutgen_user_algorithm, 
    node_finalizer, 
    preprocess, 
    cutgen, 
    max_nb_cut_rounds, 
    opt_atol, 
    opt_rtol
)

# ColCutGenConquer does not use any storage unit for the moment, therefore 
# get_units_usage() is not defined for i
function get_child_algorithms(algo::ColCutGenConquer, reform::Reformulation) 
    child_algos = Dict(
        "colgen" => (algo.colgen, reform),
        "cutgen" => (algo.cutgen, getmaster(reform))
    )

    if !isnothing(algo.preprocess)
        child_algos["preprocess"] = (algo.preprocess, reform)
    end

    if !isnothing(algo.node_finalizer)
        child_algos["node_finalizer"] = (algo.node_finalizer, reform)
    end

    if !isnothing(algo.before_cutgen_user_algorithm)
        child_algos["before_cutgen_user"] = (algo.before_cutgen_user_algorithm, reform)
    end

    for heuristic in algo.primal_heuristics
        child_algos["heuristic_$(heuristic.name)"] = (heuristic.algorithm, reform)
    end
    return child_algos
end

struct ColCutGenContext
    params::ColCutGenConquer
end

function type_of_context(::ColCutGenConquer)
    return ColCutGenContext
end

function new_context(::Type{ColCutGenContext}, algo::ColCutGenConquer, reform, input)
    return ColCutGenContext(algo)
end

"""
Runs a round of cut generation.
Returns `true` if at least one cut is separated; `false` otherwise.
"""
function run_cutgen!(::ColCutGenContext, env, reform, sol)
    cutcb_output = run!(CutCallbacks(), env, getmaster(reform), CutCallbacksInput(sol))
    cuts_were_added = cutcb_output.nb_cuts_added + cutcb_output.nb_essential_cuts_added > 0
    return cuts_were_added
end

"""
Runs a column generation algorithm and updates the optimization state of the node with 
the result of the column generation.
Returns `false` if the node is infeasible, subsolver time limit is reached, or node gap is closed;
`true` if the conquer algorithm continues.
"""
function run_colgen!(ctx::ColCutGenContext, env, reform, conquer_output)
    colgen_output = run!(ctx.params.colgen, env, reform, conquer_output)
    update!(conquer_output, colgen_output)
    if getterminationstatus(conquer_output) == INFEASIBLE ||
       getterminationstatus(conquer_output) == TIME_LIMIT ||
       ip_gap_closed(conquer_output, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol)
        return false
    end
    return true
end

function run_before_cutgen_user_algo!(
    ::ColCutGenContext, before_cutgen_user_algo, env, reform, conquer_output
)
    if ismanager(before_cutgen_user_algo.algorithm)
        records = create_records(reform)
    end

    changed = run!(before_cutgen_user_algo.algorithm, env, reform, conquer_output)

    if ismanager(before_cutgen_user_algo.algorithm) 
        restore_from_records!(input.units_to_restore, records)
    end
    return changed
end

"""
Runs several rounds of column and cut generation.
Returns `false` if the column generation returns `false` or time limit is reached.
Returns `true` if the conquer algorithm continues.
"""
function run_colcutgen!(ctx::ColCutGenContext, env, reform, conquer_output)
    nb_cut_rounds = 0
    run_conquer = true
    master_changed = true # stores value returned by the algorithm called before cut gen.
    cuts_were_added = true # stores value returned by cut gen.
    while run_conquer && (cuts_were_added || master_changed)  
        run_conquer = run_colgen!(ctx, env, reform, conquer_output)
        if !run_conquer
            return false
        end

        master_changed = false
        before_cutgen_user_algorithm = ctx.params.before_cutgen_user_algorithm
        if !isnothing(before_cutgen_user_algorithm)
            master_changed = run_before_cutgen_user_algo!(
                ctx, before_cutgen_user_algorithm, env, reform, conquer_output
            )
        end

        sol = get_best_lp_primal_sol(conquer_output)
        cuts_were_added = false
        if !isnothing(sol) 
            if run_conquer && nb_cut_rounds < ctx.params.max_nb_cut_rounds
                cuts_were_added = run_cutgen!(ctx, env, reform, sol)
                nb_cut_rounds += 1
            end
        else
            @warn "Column generation did not produce an LP primal solution. Skip cut generation."
        end

        time_limit_reached!(conquer_output, env) && return false
    end
    return true
end

# get_heuristics_to_run!
function get_heuristics_to_run(ctx::ColCutGenContext, node_depth)
    return sort!(
        filter(
            h -> node_depth <= h.max_depth #= & frequency () TODO define a function here =#,
            ctx.params.primal_heuristics
        ),
        by = h -> node_depth == 0 ? h.root_priority : h.nonroot_priority,
        rev = true
    )
end

# run_heuristics!
function run_heuristics!(ctx::ColCutGenContext, heuristics, env, reform, conquer_output)
    for heuristic in heuristics
        # TODO: check time limit of Coluna

        if ip_gap_closed(conquer_output, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol)
            return false
        end

        if ismanager(heuristic.algorithm)
            records = create_records(reform)
        end

        output = AlgoAPI.run!(heuristic.algorithm, env, getmaster(reform), get_best_ip_primal_sol(conquer_output))
        for sol in Heuristic.get_primal_sols(output)
            update_ip_primal_sol!(conquer_output, sol)
        end

        if ismanager(heuristic.algorithm) 
            restore_from_records!(input.units_to_restore, records)
        end
    end
    return true
end

"""
Runs the preprocessing algorithm. 
Returns `true` if conquer algorithm should continue; 
`false` otherwise (in the case where preprocessing finds the formulation infeasible).
"""
function run_preprocessing!(::ColCutGenContext, preprocess_algo, env, reform, conquer_output)
    preprocess_output = run!(preprocess_algo, env, reform, nothing)
    if isinfeasible(preprocess_output)
        setterminationstatus!(conquer_output, INFEASIBLE)
        return false
    end
    return true
end

function run_node_finalizer!(::ColCutGenContext, node_finalizer, env, reform, node_depth, conquer_output)
    if node_depth >= node_finalizer.min_depth #= TODO: put in a function =#
        if ismanager(node_finalizer.algorithm)
            records = create_records(reform)
        end

        nf_output = run!(node_finalizer.algorithm, env, reform, conquer_output)
        status = getterminationstatus(nf_output)
        ip_primal_sols = get_ip_primal_sols(nf_output)

        # if the node has been conquered by the node finalizer
        if status in (OPTIMAL, INFEASIBLE)
            # set the ip solutions found without checking the cuts and finish
            if !isnothing(ip_primal_sols) && length(ip_primal_sols) > 0
                for sol in sort(ip_primal_sols)
                    update_ip_primal_sol!(conquer_output, sol)
                end
            end

            # make sure that the gap is closed for the current node
            dual_bound = DualBound(reform, getvalue(get_ip_primal_bound(conquer_output)))
            update_ip_dual_bound!(conquer_output, dual_bound)
        else
            if !isnothing(ip_primal_sols) && length(ip_primal_sols) > 0
                # we start with worst solution to add all improving solutions
                for sol in sort(ip_primal_sols)
                    cutgen = CutCallbacks(call_robust_facultative = false)
                    # TODO by Artur : Node finalizer should ensure itselves that the returned solution is feasible
                    # NOTE by Guillaume: How can we do that ? I'm not sure it's a good idea to couple NF and cut gen.
                    cutcb_output = run!(cutgen, env, getmaster(reform), CutCallbacksInput(sol))
                    if cutcb_output.nb_cuts_added == 0
                        update_ip_primal_sol!(conquer_output, sol)
                    end
                end
            end
        end
    
        if ismanager(node_finalizer.algorithm) 
            restore_from_records!(input.units_to_restore, records)
        end
    end
    return true
end

function run_colcutgen_conquer!(ctx::ColCutGenContext, env, reform, input)
    # We initialize the output of the conquer algorithm using the input given by the algorithm
    # that calls the conquer strategy. This output will be updated by the conquer algorithm.
    conquer_output = OptimizationState(
        getmaster(reform);
        ip_primal_bound = get_conquer_input_ip_primal_bound(input),
        ip_dual_bound = get_conquer_input_ip_dual_bound(input)
    )

    if !get_run_conquer(input)
        return conquer_output
    end

    time_limit_reached!(conquer_output, env) && return conquer_output

    if !isnothing(ctx.params.preprocess)
        run_conquer = run_preprocessing!(ctx, ctx.params.preprocess, env, reform, conquer_output)
        !run_conquer && return conquer_output
    end

    time_limit_reached!(conquer_output, env) && return conquer_output

    run_conquer = run_colcutgen!(ctx, env, reform, conquer_output)
    !run_conquer && return conquer_output

    time_limit_reached!(conquer_output, env) && return conquer_output

    heuristics_to_run = get_heuristics_to_run(ctx, get_node_depth(input))
    run_conquer = run_heuristics!(ctx, heuristics_to_run, env, reform, conquer_output)
    !run_conquer && return conquer_output

    time_limit_reached!(conquer_output, env) && return conquer_output

    # if the gap is still unclosed, try to run the node finalizer
    node_finalizer = ctx.params.node_finalizer
    if !ip_gap_closed(conquer_output, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol) && !isnothing(node_finalizer)
        run_node_finalizer!(ctx, node_finalizer, env, reform, get_node_depth(input), conquer_output)
    end

    time_limit_reached!(conquer_output, env) && return conquer_output

    if ip_gap_closed(conquer_output, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol)
        setterminationstatus!(conquer_output, OPTIMAL)
    elseif getterminationstatus(conquer_output) != TIME_LIMIT && getterminationstatus(conquer_output) != INFEASIBLE
        setterminationstatus!(conquer_output, OTHER_LIMIT)
    end
    return conquer_output
end

function run!(algo::ColCutGenConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    ctx = new_context(type_of_context(algo), algo, reform, input)
    return run_colcutgen_conquer!(ctx, env, reform, input)
end

####################################################################
#                      RestrMasterLPConquer
####################################################################

@with_kw struct RestrMasterLPConquer <: AbstractConquerAlgorithm
    masterlpalgo::SolveLpForm = SolveLpForm(
        update_ip_primal_solution = true
    )
end

# RestrMasterLPConquer does not use any unit, therefore get_units_usage() is not defined for it

function get_child_algorithms(algo::RestrMasterLPConquer, reform::Reformulation)
    return Dict("restr_master_lp" => (algo.masterlpalgo, getmaster(reform)))
end

function run!(algo::RestrMasterLPConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    conquer_output = OptimizationState(
        getmaster(reform);
        ip_primal_bound = get_conquer_input_ip_primal_bound(input),
        ip_dual_bound = get_conquer_input_ip_dual_bound(input)
    )

    if !get_run_conquer(input)
        return conquer_output
    end

    masterlp_state = run!(algo.masterlpalgo, env, getmaster(reform), conquer_output)

    update!(conquer_output, masterlp_state)
    if ip_gap_closed(masterlp_state)
        setterminationstatus!(conquer_output, OPTIMAL)
    else
        setterminationstatus!(conquer_output, OTHER_LIMIT)
    end
    return conquer_output
end

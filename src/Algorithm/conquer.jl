####################################################################
#                      ParameterizedHeuristic
####################################################################

"""
    Coluna.Algorithm.RestrictedMasterHeuristic()

This algorithm enforces integrality of column variables in the master formulation and then
solves the master formulation with its optimizer.
"""
RestrictedMasterIPHeuristic() = SolveIpForm(moi_params = MoiOptimize(get_dual_bound = false))

struct ParameterizedHeuristic{OptimAlgorithm<:AbstractOptimizationAlgorithm}
    algorithm::OptimAlgorithm
    root_priority::Float64
    nonroot_priority::Float64
    frequency::Integer
    max_depth::Integer
    name::String
end

ParamRestrictedMasterHeuristic() = 
    ParameterizedHeuristic(
        RestrictedMasterIPHeuristic(), 
        1.0, 1.0, 1, 1000, "Restricted Master IP"
    )

####################################################################
#                      NodeFinalizer
####################################################################

struct NodeFinalizer
    algorithm::AbstractOptimizationAlgorithm
    frequency::Integer
    min_depth::Integer
    name::String
end

####################################################################
#                      BendersConquer
####################################################################

@with_kw struct BendersConquer <: AbstractConquerAlgorithm 
    benders::BendersCutGeneration = BendersCutGeneration()
end

isverbose(strategy::BendersConquer) = true

# BendersConquer does not use any unit for the moment, it just calls 
# BendersCutSeparation algorithm, therefore get_units_usage() is not defined for it

function get_child_algorithms(algo::BendersConquer, reform::Reformulation) 
    return [(algo.benders, reform)]
end

function run!(algo::BendersConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    !run_conquer(input) && return
    restore_from_records!(get_units_to_restore(input), get_records(node))
    node = getnode(input)    
    node_state = get_opt_state(node)
    output = run!(algo.benders, env, reform, node_state)
    update!(node_state, output)
    return 
end

####################################################################
#                      ColCutGenConquer
####################################################################

"""
    Coluna.Algorithm.ColCutGenConquer(
        stages = ColumnGeneration[ColumnGeneration()],
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
@with_kw struct ColCutGenConquer <: AbstractConquerAlgorithm 
    stages::Vector{ColumnGeneration} = [ColumnGeneration()]
    primal_heuristics::Vector{ParameterizedHeuristic} = [ParamRestrictedMasterHeuristic()]
    node_finalizer::Union{Nothing, NodeFinalizer} = nothing
    preprocess = nothing
    cutgen = CutCallbacks()
    max_nb_cut_rounds::Int = 3 # TODO : tailing-off ?
    opt_atol::Float64 = stages[1].opt_atol # TODO : force this value in an init() method
    opt_rtol::Float64 = stages[1].opt_rtol # TODO : force this value in an init() method
end

function isverbose(algo::ColCutGenConquer) 
    for colgen in algo.stages
        colgen.log_print_frequency > 0 && return true
    end
    return false
end

# ColCutGenConquer does not use any storage unit for the moment, therefore 
# get_units_usage() is not defined for it

function get_child_algorithms(algo::ColCutGenConquer, reform::Reformulation) 
    child_algos = Tuple{AbstractAlgorithm, AbstractModel}[]
    for colgen in algo.stages
        push!(child_algos, (colgen, reform))
    end
    push!(child_algos, (algo.cutgen, getmaster(reform)))
    if !isnothing(algo.preprocess)
        push!(child_algos, (algo.preprocess, reform))
    end
    for heuristic in algo.primal_heuristics
        push!(child_algos, (heuristic.algorithm, reform))
    end
    return child_algos
end

struct ColCutGenContext
    params::ColCutGenConquer
end

function type_of_context(algo::ColCutGenConquer)
    return ColCutGenContext
end

function new_context(::Type{ColCutGenContext}, algo::ColCutGenConquer, reform, input)
    return ColCutGenContext(algo)
end

# run_cutgen!
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
function run_colgen!(ctx::ColCutGenContext, colgen, env, reform, node_state)
    colgen_output = run!(colgen, env, reform, node_state)
    update!(node_state, colgen_output)

    if getterminationstatus(node_state) == INFEASIBLE ||
       getterminationstatus(node_state) == TIME_LIMIT ||
       ip_gap_closed(node_state, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol)
        return false
    end
    return true
end

"""

"""
function run_colcutgen!(ctx::ColCutGenContext, env, reform, node_state)
    nb_cut_rounds = 0
    run_conquer = true
    cuts_were_added = true
    while run_conquer && cuts_were_added
        for (stage_index, colgen) in Iterators.reverse(Iterators.enumerate(ctx.params.stages))
            # print stage_index
            run_conquer = run_colgen!(ctx, colgen, env, reform, node_state)
            if !run_conquer
                return false
            end
        end
    
        sol = get_best_lp_primal_sol(node_state)
        cuts_were_added = false
        if !isnothing(sol) 
            if run_conquer && nb_cut_rounds < ctx.params.max_nb_cut_rounds
                cuts_were_added = run_cutgen!(ctx, env, reform, sol)
                nb_cut_rounds += 1
            end
        else
            @warn "Column generation did not produce an LP primal solution. Skip cut generation."
        end
    end
    return true
end

# get_heuristics_to_run!
function get_heuristics_to_run(ctx::ColCutGenContext, node)
    return sort!(
        filter(
            h -> getdepth(node) <= h.max_depth #= & frequency () TODO define a function here =#,
            ctx.params.primal_heuristics
        ),
        by = h -> isroot(node) ? h.root_priority : h.nonroot_priority,
        rev = true
    )
end

# run_heuristics!
function run_heuristics!(ctx::ColCutGenContext, heuristics, env, reform, node_state,)
    for heuristic in heuristics
        # TODO: check time limit of Coluna

        if ip_gap_closed(node_state, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol)
            return false
        end

        if ismanager(heuristic.algorithm)
            records = create_records(reform)
        end

        heur_output = run!(heuristic.algorithm, env, reform, node_state)
        if getterminationstatus(heur_output) == TIME_LIMIT
            setterminationstatus!(node_state, TIME_LIMIT)
        end

        ip_primal_sols = get_ip_primal_sols(heur_output)
        if !isnothing(ip_primal_sols) && length(ip_primal_sols) > 0
            # we start with worst solution to add all improving solutions
            for sol in sort(ip_primal_sols)
                cutgen = CutCallbacks(call_robust_facultative = false)
                # TODO (Ruslan): Heuristics should ensure themselves that the returned solution is feasible (Ruslan)
                # NOTE (Guillaume): I don't know how we can do that because the heuristic should not have
                # access to the cut callback algorithm.
                cutcb_output = run!(cutgen, env, getmaster(reform), CutCallbacksInput(sol))
                if cutcb_output.nb_cuts_added == 0
                    update_ip_primal_sol!(node_state, sol)
                end
            end
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
function run_preprocessing!(::ColCutGenContext, preprocess_algo, env, reform, node_state)
    preprocess_output = run!(preprocess_algo, env, reform, nothing)
    if isinfeasible(preprocess_output)
        setterminationstatus!(node_state, INFEASIBLE)
        return false
    end
    return true
end

function run_node_finalizer!(::ColCutGenContext, node_finalizer, env, reform, node, node_state)
    if getdepth(node) >= node_finalizer.min_depth #= TODO: put in a function =#
        if ismanager(node_finalizer.algorithm)
            records = create_records(reform)
        end

        nf_output = run!(node_finalizer.algorithm, env, reform, node_state)
        status = getterminationstatus(nf_output)
        ip_primal_sols = get_ip_primal_sols(nf_output)

        # if the node has been conquered by the node finalizer
        if status in (OPTIMAL, INFEASIBLE)
            # set the ip solutions found without checking the cuts and finish
            if !isnothing(ip_primal_sols) && length(ip_primal_sols) > 0
                for sol in sort(ip_primal_sols)
                    update_ip_primal_sol!(node_state, sol)
                end
            end

            # make sure that the gap is closed for the current node
            dual_bound = DualBound(reform, getvalue(get_ip_primal_bound(node_state)))
            update_ip_dual_bound!(node_state, dual_bound)
        else
            if !isnothing(ip_primal_sols) && length(ip_primal_sols) > 0
                # we start with worst solution to add all improving solutions
                for sol in sort(ip_primal_sols)
                    cutgen = CutCallbacks(call_robust_facultative = false)
                    # TODO by Artur : Node finalizer should ensure itselves that the returned solution is feasible
                    # NOTE by Guillaume: How can we do that ? I'm not sure it's a good idea to couple NF and cut gen.
                    cutcb_output = run!(cutgen, env, getmaster(reform), CutCallbacksInput(sol))
                    if cutcb_output.nb_cuts_added == 0
                        update_ip_primal_sol!(node_state, sol)
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
    node = get_node(input)
    restore_from_records!(get_units_to_restore(input), get_records(node))
    node_state = get_opt_state(node)

    # TODO: check time limit of Coluna
    if !isnothing(ctx.params.preprocess)
        run_conquer = run_preprocessing!(ctx, ctx.params.preprocess, env, reform, node_state)
        !run_conquer && return
    end

    # TODO: check time limit of Coluna
    run_conquer = run_colcutgen!(ctx, env, reform, node_state)
    !run_conquer && return

    # TODO: check time limit of Coluna
    heuristics_to_run = get_heuristics_to_run(ctx, node)
    run_conquer = run_heuristics!(ctx, heuristics_to_run, env, reform, node_state)
    !run_conquer && return

    # TODO: check time limit of Coluna

    # if the gap is still unclosed, try to run the node finalizer
    node_finalizer = ctx.params.node_finalizer
    if !ip_gap_closed(node_state, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol) && !isnothing(node_finalizer)
        run_node_finalizer!(ctx, node_finalizer, env, reform, node, node_state)
    end

    # TODO: check time limit of Coluna
    if ip_gap_closed(node_state, atol = ctx.params.opt_atol, rtol = ctx.params.opt_rtol)
        setterminationstatus!(node_state, OPTIMAL)
    elseif getterminationstatus(node_state) != TIME_LIMIT && getterminationstatus(node_state) != INFEASIBLE
        setterminationstatus!(node_state, OTHER_LIMIT)
    end
    return
end

function run!(algo::ColCutGenConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    !run_conquer(input) && return
    ctx = new_context(type_of_context(algo), algo, reform, input)
    run_colcutgen_conquer!(ctx, env, reform, input)
    return
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
    return [(algo.masterlpalgo, getmaster(reform))]
end

function run!(algo::RestrMasterLPConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    !run_conquer(input) && return

    node = get_node(input)
    restore_from_records!(get_units_to_restore(input), get_records(node))

    node_state = get_opt_state(node)
    masterlp_state = run!(algo.masterlpalgo, env, getmaster(reform), node_state)
    update!(node_state, masterlp_state)
    if ip_gap_closed(masterlp_state)
        setterminationstatus!(node_state, OPTIMAL)
    else
        setterminationstatus!(node_state, OTHER_LIMIT)
    end
    return
end

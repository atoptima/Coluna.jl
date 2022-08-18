"""
AbstractConquerInput

Input of a conquer algorithm used by the tree search algorithm.
Contains the node in the search tree and the collection of units to restore 
before running the conquer algorithm. This collection of units is passed
in the input so that it is not obtained each time the conquer algorithm runs. 
"""

abstract type AbstractConquerInput end

function get_node(i::AbstractConquerInput)
    @warn "get_node(::$(typeof(i))) not implemented."
    return nothing
end

function get_units_to_restore(i::AbstractConquerInput)
    @warn "get_units_to_restore(::$(typeof(i))) not implemented."
    return nothing
end

function run_conquer(i::AbstractConquerInput)
    @warn "run_conquer(::$(typeof(i))) not implemented."
    return nothing
end

"""
    AbstractConquerAlgorithm

This algorithm type is used by the tree search algorithm to update the incumbents and the formulation.
For the moment, a conquer algorithm can be run only on reformulation.     
A conquer algorithm should restore records of storage units using `restore_from_records!(conquer_input)`
- each time it runs in the beginning
- each time after calling a child manager algorithm
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end

# conquer algorithms are always manager algorithms (they manage storing and restoring units)
ismanager(algo::AbstractConquerAlgorithm) = true

function run!(algo::AbstractConquerAlgorithm, env::Env, reform::Reformulation, input::AbstractConquerInput)
    algotype = typeof(algo)
    error(string("Method run! which takes as parameters Reformulation and ConquerInput ", 
                 "is not implemented for algorithm $algotype.")
    )
end

# this function is needed in strong branching (to have a better screen logging)
isverbose(algo::AbstractConquerAlgorithm) = false

# this function is needed to check whether the best primal solution should be copied to the node optimization state
exploits_primal_solutions(algo::AbstractConquerAlgorithm) = false

####################################################################
#                      ParameterisedHeuristic
####################################################################

"""
    Coluna.Algorithm.RestrictedMasterHeuristic()

This algorithm enforces integrality of column variables in the master formulation and then solves the master formulation with its optimizer.
"""
RestrictedMasterIPHeuristic() = SolveIpForm(moi_params = MoiOptimize(get_dual_bound = false))

struct ParameterisedHeuristic
    algorithm::AbstractOptimizationAlgorithm
    root_priority::Float64
    nonroot_priority::Float64
    frequency::Integer
    max_depth::Integer
    name::String
end

ParamRestrictedMasterHeuristic() = 
    ParameterisedHeuristic(
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
    output = run!(algo.benders, env, reform, OptimizationInput(node_state))
    update!(node_state, get_opt_state(output))
    return 
end

####################################################################
#                      ColCutGenConquer
####################################################################

"""
    Coluna.Algorithm.ColCutGenConquer(
        stages = ColumnGeneration[ColumnGeneration()],
        primal_heuristics = ParameterisedHeuristic[ParamRestrictedMasterHeuristic()],
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
    primal_heuristics::Vector{ParameterisedHeuristic} = [ParamRestrictedMasterHeuristic()]
    node_finalizer::Union{Nothing, NodeFinalizer} = nothing
    preprocess = PreprocessAlgorithm()
    cutgen = CutCallbacks()
    max_nb_cut_rounds::Int = 3 # TODO : tailing-off ?
    run_preprocessing::Bool = false
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
    algo.run_preprocessing && push!(child_algos, (algo.preprocess, reform))
    for heuristic in algo.primal_heuristics
        push!(child_algos, (heuristic.algorithm, reform))
    end
    return child_algos
end

function run!(algo::ColCutGenConquer, env::Env, reform::Reformulation, input::AbstractConquerInput)
    !run_conquer(input) && return

    node = get_node(input)
    restore_from_records!(get_units_to_restore(input), get_records(node))

    node_state = get_opt_state(node)
    if algo.run_preprocessing && isinfeasible(run!(algo.preprocess, env, reform, EmptyInput()))
        setterminationstatus!(node_state, INFEASIBLE)
        return
    end

    nb_cut_rounds = 0
    stop_conquer = false
    run_colgen = true
    while !stop_conquer && run_colgen

        for (stage, colgen) in Iterators.reverse(enumerate(algo.stages))
            if length(algo.stages) > 1 
                @logmsg LogLevel(0) "Column generation stage $stage is started"
            end

            colgen_output = run!(colgen, env, reform, OptimizationInput(node_state))
            update!(node_state, get_opt_state(colgen_output))

            if getterminationstatus(node_state) == INFEASIBLE ||
               getterminationstatus(node_state) == TIME_LIMIT ||
               ip_gap_closed(node_state, atol = algo.opt_atol, rtol = algo.opt_rtol)
                stop_conquer = true
                break
            end
        end
    
        cuts_were_added = false
        sol = get_best_lp_primal_sol(node_state)
        if sol !== nothing 
            if !stop_conquer && nb_cut_rounds < algo.max_nb_cut_rounds
                cutcb_input = CutCallbacksInput(sol)
                cutcb_output = run!(CutCallbacks(), env, getmaster(reform), cutcb_input)
                nb_cut_rounds += 1
                # TO DO : there is no need to distinguish added essential cuts
                #         just the number of generated cuts would be enough
                if cutcb_output.nb_cuts_added + cutcb_output.nb_essential_cuts_added > 0
                    cuts_were_added = true
                end
            end
        else
            @warn "Column generation did not produce an LP primal solution."
        end
        if !cuts_were_added 
            run_colgen = false
        end
    end

    if !stop_conquer
        heuristics_to_run = Tuple{AbstractOptimizationAlgorithm, String, Float64}[]
        for heuristic in algo.primal_heuristics
            #TO DO : get_tree_order of nodes in strong branching is always -1
            # TO DO: replace this condition by a function.
            if getdepth(node) <= heuristic.max_depth #&& 
                #mod(get_tree_order(node) - 1, heuristic.frequency) == 0 (tree_order removed)
                push!(heuristics_to_run, (
                    heuristic.algorithm, heuristic.name,
                    isroot(node) ? heuristic.root_priority : heuristic.nonroot_priority
                ))
            end
        end
        sort!(heuristics_to_run, by = x -> last(x), rev=true)
    
        for (heur_algorithm, name, _) in heuristics_to_run
            if ip_gap_closed(node_state, atol = algo.opt_atol, rtol = algo.opt_rtol) 
                break
            end

            @info "Running $name heuristic"
            if ismanager(heur_algorithm) 
                records = create_records(reform)
            end   

            heur_output = run!(heur_algorithm, env, reform, OptimizationInput(node_state))
            status = getterminationstatus(get_opt_state(heur_output))
            status == TIME_LIMIT && setterminationstatus!(node_state, status)
            ip_primal_sols = get_ip_primal_sols(get_opt_state(heur_output))
            if ip_primal_sols !== nothing && length(ip_primal_sols) > 0
                # we start with worst solution to add all improving solutions
                for sol in sort(ip_primal_sols)
                    cutgen = CutCallbacks(call_robust_facultative = false)
                    # TO DO : Heuristics should ensure themselves that the returned solution is feasible
                    cutcb_output = run!(cutgen, env, getmaster(reform), CutCallbacksInput(sol))
                    if cutcb_output.nb_cuts_added == 0
                        update_ip_primal_sol!(node_state, sol)
                    end
                end
            end
            if ismanager(heur_algorithm) 
                restore_from_records!(input.units_to_restore, records)
            end

            if getterminationstatus(node_state) == TIME_LIMIT ||
               ip_gap_closed(node_state, atol = algo.opt_atol, rtol = algo.opt_rtol)
               break
            end   
        end

        # if the gap is still unclosed, try to run the node finalizer if any
        run_node_finalizer = (algo.node_finalizer !== nothing)
        run_node_finalizer = run_node_finalizer && getterminationstatus(node_state) != TIME_LIMIT
        run_node_finalizer =
            run_node_finalizer && !ip_gap_closed(node_state, atol = algo.opt_atol, rtol = algo.opt_rtol)
        run_node_finalizer = run_node_finalizer && getdepth(node) >= algo.node_finalizer.min_depth
        run_node_finalizer =
            run_node_finalizer #&& mod(get_tree_order(node) - 1, algo.node_finalizer.frequency) == 0 (tree_order removed)

        if run_node_finalizer
            # get the algorithm info
            nodefinalizer = algo.node_finalizer.algorithm
            name = algo.node_finalizer.name

            @info "Running $name node finalizer"
            if ismanager(nodefinalizer) 
                records = create_records(reform)
            end   

            nf_output = run!(nodefinalizer, env, reform, OptimizationInput(node_state))
            status = getterminationstatus(get_opt_state(nf_output))
            status == TIME_LIMIT && setterminationstatus!(node_state, status)
            ip_primal_sols = get_ip_primal_sols(get_opt_state(nf_output))

            # if the node has been conquered by the node finalizer
            if status in (OPTIMAL, INFEASIBLE)
                # set the ip solutions found without checking the cuts and finish
                if ip_primal_sols !== nothing && length(ip_primal_sols) > 0
                    for sol in sort(ip_primal_sols)
                        update_ip_primal_sol!(node_state, sol)
                    end
                end

                # make sure that the gap is closed for the current node
                dual_bound = DualBound(reform, getvalue(get_ip_primal_bound(node_state)))
                update_ip_dual_bound!(node_state, dual_bound)
            else
                if ip_primal_sols !== nothing && length(ip_primal_sols) > 0
                    # we start with worst solution to add all improving solutions
                    for sol in sort(ip_primal_sols)
                        cutgen = CutCallbacks(call_robust_facultative = false)
                        # TO DO : Node finalizer should ensure itselves that the returned solution is feasible
                        cutcb_output = run!(cutgen, env, getmaster(reform), CutCallbacksInput(sol))
                        if cutcb_output.nb_cuts_added == 0
                            update_ip_primal_sol!(node_state, sol)
                        end
                    end
                end
                if ismanager(nodefinalizer) 
                    restore_from_records!(input.units_to_restore, records)
                end
            end
        end
    end

    if ip_gap_closed(node_state, atol = algo.opt_atol, rtol = algo.opt_rtol)
        setterminationstatus!(node_state, OPTIMAL)
    elseif getterminationstatus(node_state) != TIME_LIMIT && getterminationstatus(node_state) != INFEASIBLE
        setterminationstatus!(node_state, OTHER_LIMIT)
    end
    return
end

####################################################################
#                      RestrMasterLPConquer
####################################################################

@with_kw struct RestrMasterLPConquer <: AbstractConquerAlgorithm 
    masterlpalgo::SolveLpForm = SolveLpForm(
        update_ip_primal_solution = true, consider_partial_solution = true
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
    output = run!(algo.masterlpalgo, env, getmaster(reform), OptimizationInput(node_state))
    masterlp_state =  get_opt_state(output)
    update!(node_state, masterlp_state)
    if ip_gap_closed(masterlp_state)
        setterminationstatus!(node_state, OPTIMAL)
    else
        setterminationstatus!(node_state, OTHER_LIMIT)
    end
    return
end

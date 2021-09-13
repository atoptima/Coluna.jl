"""

    Coluna.Algorithm.BranchCutAndPriceAlgorithm(;
        maxnumnodes::Int = 100000,
        opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL,
        restmastipheur_timelimit::Int = 600,
        restmastipheur_frequency::Int = 1,
        restmastipheur_maxdepth::Int = 1000,
        max_nb_cut_rounds::Int = 3,
        colgen_stabilization::Float64 = 0.0, 
        colgen_cleanup_threshold::Int = 10000,
        colgen_stages_pricing_solvers::Vector{Int} = [1],
        branching_priorities::Vector{Float64} = [1.0],
        stbranch_phases_num_candidates::Int = [],
        stbranch_intrmphase_colgen_stages::Vector{Int} = [1],
        stbranch_intrmphase_pricing_solvers::Vector{Int} = [1],
        stbranch_intrmphase_colgen_maxiters::Vector{Int} = [100])

Coluna.Algorithm.BranchCutAndPriceAlgorithm is an alias for a simplified parameterisation 
of the branch-cut-and-price algorithm.

Parameters : 
- `maxnumnodes` : maximum number of nodes explored by the algorithm
- `opt_atol` : optimality absolute tolerance 
- `opt_rtol` : optimality relative tolerance
- `restmastipheur_timelimit` : time limit in seconds for the restricted master heuristic 
                               (if <= 0 then the heuristic is disabled)
- `restmastipheur_frequency` : frequency of calls to the restricted master heuristic                               
- `restmastipheur_maxdepth` : maximum depth of the search tree when the restricted master heuristic is called
- `max_nb_cut_rounds` : maximum number of cut generation rounds in every node of the search tree
- `colgen_stabilization` : parameterisation of the dual price smoothing stabilization of column generation
                           0.0 - disabled, 1.0 - automatic, ∈(0.0,1.0) - fixed smoothing parameter
- `colgen_cleanup_threshold` : threshold (number of active columns) to trigger the restricted master LP clean up
- `colgen_stages_pricing_solvers` : vector of pricing solver ids for every column generation stage,
                                    pricing solvers should be specified using argument `solver` of `BlockDecomposition.specify!()`,
                                    the number of column generation stages is equal to the length of this vector,
                                    column generation stages are executed in the reverse order,
                                    the first stage should be exact to ensure the optimality of the BCP algorithm
- `branching_priorities` : vector of different branching priorities (in decreasing order) set for the variables of the model,
                           branching priorities for variables can be set using `BlockDecomposition.branchingpriority!()`,
                           branching candidates are generated in the decreasing order of branching priority
                           if no branching candidates are found for a larger branching priority, the next lower branching priority is considered,
                           in strong branching, branching candidates of the next lower priority are considered if
                           - no branching candidates of a larger priority are generated
                           - the maximum number of candidates for the first phase of strong branching is not yet reached
                             and the next lower priority is not less than the rounded down value of an already generated branching candidate
- `stbranch_phases_num_candidates` : maximum number of candidates for each strong branching phase, 
                                     strong branching is activated if this vector is not empty,
                                     the number of phases in strong branching is equal to min{3, length(stbranch_phases_num_candidates)},
                                     in the last phase, the standard column-and-cut generation procedure is run,
                                     in the first phase (if their number is >= 2), only the restricted master LP is resolved, 
                                     in the second (intermediate) phase (if their number is >= 3), usually a heuristic pricing is used
                                     or the number of column generation iterations is limited, this is parameterised with the three
                                     next parameters, cut separation is not called in the intermediate strong branching phase, 
                                     if the lenth of this vector > 3, then all values except first, second, and last ones are ignored
- `stbranch_intrmphase_colgen_stages` : the number of column generation stages in the intemediate phase of strong branching 
                                        is equal to the length of this vector, the values of this vector determine the `stage`
                                        parameter passed to the pricing callback on every stage,
                                        as before column generation stages are executed in the reverse order
- `stbranch_intrmphase_pricing_solvers` : sets the solver id for every column generation stage in the intermediate phase of strong branching,
                                          the length of this vector should be equal to length(stbranch_intrmphase_colgen_stages)
- `stbranch_intrmphase_colgen_maxiters` : sets the maximum number of column generation iterations for every stage 
                                          in the intemediate phase of strong branching,
                                          the length of this vector should be equal to length(stbranch_intrmphase_colgen_stages)
"""



function BranchCutAndPriceAlgorithm(;
        maxnumnodes::Int = 100000,
        branchingtreefile::Union{Nothing, String} = nothing,
        opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL,
        restmastipheur_timelimit::Int = 600,
        restmastipheur_frequency::Int = 1,
        restmastipheur_maxdepth::Int = 1000,
        max_nb_cut_rounds::Int = 3,
        colgen_stabilization::Float64 = 0.0, 
        colgen_cleanup_threshold::Int = 10000,
        colgen_stages_pricing_solvers::Vector{Int64} = [1],
        branching_priorities::Vector{Float64} = [1.0],
        stbranch_phases_num_candidates = Vector{Int64}(),
        stbranch_intrmphase_colgen_stages::Vector{Int64} = [1],
        stbranch_intrmphase_pricing_solvers::Vector{Int64} = [1],
        stbranch_intrmphase_colgen_maxiters::Vector{Int64} = [100]
)
    heuristics::Vector{ParameterisedHeuristic} = []
    if restmastipheur_timelimit > 0
        heuristic = ParameterisedHeuristic(
            SolveIpForm(moi_params = MoiOptimize(
                get_dual_bound = false,
                time_limit = restmastipheur_timelimit
            )),
            1.0, 1.0, restmastipheur_frequency, 
            restmastipheur_maxdepth, "Restricted Master IP"
        )
        push!(heuristics, heuristic)
    end

    colgen_stages::Vector{ColumnGeneration} = []

    for (stage, solver_id) in enumerate(colgen_stages_pricing_solvers)
        colgen = ColumnGeneration(
            pricing_prob_solve_alg = SolveIpForm(
                optimizer_id = solver_id,
                user_params = UserOptimize(stage = stage), 
                moi_params = MoiOptimize(
                    deactivate_artificial_vars = false,
                    enforce_integrality = false
                )
            ),
            smoothing_stabilization = colgen_stabilization,
            cleanup_threshold = colgen_cleanup_threshold,
            opt_atol = opt_atol,
            opt_rtol = opt_rtol
        )
        push!(colgen_stages,  colgen)  
    end

    conquer = ColCutGenConquer(
        stages = colgen_stages,
        max_nb_cut_rounds = max_nb_cut_rounds,
        primal_heuristics = heuristics,
        opt_atol = opt_atol,
        opt_rtol = opt_rtol
    )

    branching = NoBranching()
    branching_rules::Vector{PrioritisedBranchingRule} = []
    if !isempty(branching_priorities)
        sorted_branching_priorities = sort(branching_priorities; rev=true)
        for priority in sorted_branching_priorities
            push!(branching_rules, PrioritisedBranchingRule(VarBranchingRule(), priority, priority))
        end
    else
        push!(branching_rules, PrioritisedBranchingRule(VarBranchingRule(), 1.0, 1.0))
    end

    if !isempty(stbranch_phases_num_candidates)
        branching_phases::Vector{BranchingPhase} = []
        if length(stbranch_phases_num_candidates) >= 2
            push!(branching_phases, 
                BranchingPhase(first(stbranch_phases_num_candidates), RestrMasterLPConquer())
            )    
            if length(stbranch_phases_num_candidates) >= 3
                intrmphase_stages::Vector{ColumnGeneration} = []
                for (stage_index, stage_number) in enumerate(stbranch_intrmphase_colgen_stages)
                    colgen = ColumnGeneration(
                        pricing_prob_solve_alg = SolveIpForm(
                            optimizer_id = stbranch_intrmphase_pricing_solvers[stage_index],
                            user_params = UserOptimize(stage = stage_number), 
                            moi_params = MoiOptimize(
                                deactivate_artificial_vars = false,
                                enforce_integrality = false
                            )
                        ),
                        smoothing_stabilization = colgen_stabilization,
                        cleanup_threshold = colgen_cleanup_threshold,
                        max_nb_iterations = stbranch_intrmphase_colgen_maxiters[stage_index],
                        opt_atol = opt_atol,
                        opt_rtol = opt_rtol
                    )
                    push!(intrmphase_stages,  colgen)  
                end                
                intrmphase_conquer = ColCutGenConquer(
                    stages = intrmphase_stages,
                    max_nb_cut_rounds = 0,
                    primal_heuristics = [],
                    opt_atol = opt_atol,
                    opt_rtol = opt_rtol
                )
                push!(branching_phases, 
                    BranchingPhase(stbranch_phases_num_candidates[2], intrmphase_conquer)
                )    
            end
        end            
        push!(branching_phases, BranchingPhase(last(stbranch_phases_num_candidates), conquer))    
        branching = StrongBranching(rules = branching_rules, phases = branching_phases)
    else
        branching = StrongBranching(rules = branching_rules)
    end

    return TreeSearchAlgorithm(
        conqueralg = conquer,
        dividealg = branching,
        maxnumnodes = maxnumnodes,
        branchingtreefile = branchingtreefile,
        opt_atol = opt_atol;
        opt_rtol = opt_rtol
    )
end    
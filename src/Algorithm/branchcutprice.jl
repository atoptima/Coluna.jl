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
        colgen_strict_integrality_check::Bool, 
        stbranch_phases_num_candidates::Vector{Int} = Int[],
        stbranch_intrmphase_stages::Vector{NamedTuple{(:userstage, :solverid, :maxiters), Tuple{Int64, Int64, Int64}}}
    )

Alias for a simplified parameterisation 
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
- `colgen_strict_integrality_check` : see description in `Coluna.Algorithm.ColumnGeneration`
- `stbranch_phases_num_candidates` : maximum number of candidates for each strong branching phase, 
                                     strong branching is activated if this vector is not empty,
                                     the number of phases in strong branching is equal to min{3, length(stbranch_phases_num_candidates)},
                                     in the last phase, the standard column-and-cut generation procedure is run,
                                     in the first phase (if their number is >= 2), only the restricted master LP is resolved, 
                                     in the second (intermediate) phase (if their number is >= 3), usually a heuristic pricing is used
                                     or the number of column generation iterations is limited, this is parameterised with the three
                                     next parameters, cut separation is not called in the intermediate strong branching phase, 
                                     if the lenth of this vector > 3, then all values except first, second, and last ones are ignored
- `stbranch_intrmphase_stages` : the size of this vector is the number of column generation stages in the intemediate phase of strong branching 
                                 each element of the vector is the named triple (userstage, solver, maxiters). "userstage" is the 
                                 value of "stage" parameter passed to the pricing callback on this stage, "solverid" is the solver id on this stage, 
                                 and "maxiters" is the maximum number of column generation iterations on this stage
"""



function BranchCutAndPriceAlgorithm(;
        maxnumnodes::Int = 100000,
        branchingtreefile::String = "",
        jsonfile::String = "",
        opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL,
        restmastipheur_timelimit::Int = 600,
        restmastipheur_frequency::Int = 1,
        restmastipheur_maxdepth::Int = 1000,
        max_nb_cut_rounds::Int = 3,
        colgen_stabilization::Float64 = 0.0, 
        colgen_cleanup_threshold::Int = 10000,
        colgen_stages_pricing_solvers::Vector{Int64} = [1],
        colgen_strict_integrality_check::Bool = false, 
        stbranch_phases_num_candidates::Vector{Int64} = Int[],
        stbranch_intrmphase_stages::Vector{NamedTuple{(:userstage, :solverid, :maxiters), Tuple{Int64, Int64, Int64}}} = [(userstage=1, solverid=1, maxiters=100)]
)
    heuristics = ParameterizedHeuristic[]
    if restmastipheur_timelimit > 0
        heuristic = ParameterizedHeuristic(
            RestrictedMasterHeuristic(),
            1.0, 1.0, restmastipheur_frequency, 
            restmastipheur_maxdepth, "Restricted Master IP"
        )
        push!(heuristics, heuristic)
    end

    colgen = ColumnGeneration(
        pricing_prob_solve_alg = SolveIpForm(
            user_params = UserOptimize(), 
            moi_params = MoiOptimize(
                deactivate_artificial_vars = false,
                enforce_integrality = false
            )
        ),
        strict_integrality_check = colgen_strict_integrality_check,
        stages_pricing_solver_ids = colgen_stages_pricing_solvers,
        smoothing_stabilization = colgen_stabilization,
        cleanup_threshold = colgen_cleanup_threshold,
        opt_atol = opt_atol,
        opt_rtol = opt_rtol
    )

    conquer = ColCutGenConquer(
        colgen = colgen,
        max_nb_cut_rounds = max_nb_cut_rounds,
        primal_heuristics = heuristics,
        opt_atol = opt_atol,
        opt_rtol = opt_rtol
    )

    branching = NoBranching()
    branching_rules = Branching.PrioritisedBranchingRule[Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)]

    if !isempty(stbranch_phases_num_candidates)
        branching_phases = BranchingPhase[]
        if length(stbranch_phases_num_candidates) >= 2
            push!(branching_phases, 
                BranchingPhase(first(stbranch_phases_num_candidates), RestrMasterLPConquer(), ProductScore())
            )    
            if length(stbranch_phases_num_candidates) >= 3
                colgen = ColumnGeneration(
                    pricing_prob_solve_alg = SolveIpForm(
                        user_params = UserOptimize(), 
                        moi_params = MoiOptimize(
                            deactivate_artificial_vars = false,
                            enforce_integrality = false
                        )
                    ),
                    strict_integrality_check = colgen_strict_integrality_check,
                    stages_pricing_solver_ids = map(t -> t.solverid, stbranch_intrmphase_stages),
                    smoothing_stabilization = colgen_stabilization,
                    cleanup_threshold = colgen_cleanup_threshold,
                    max_nb_iterations = mapreduce(t -> t.maxiters, +, stbranch_intrmphase_stages),
                    opt_atol = opt_atol,
                    opt_rtol = opt_rtol
                )
                  
                           
                intrmphase_conquer = ColCutGenConquer(
                    #stages = intrmphase_stages,
                    colgen = colgen,
                    max_nb_cut_rounds = 0,
                    primal_heuristics = [],
                    opt_atol = opt_atol,
                    opt_rtol = opt_rtol
                )
                push!(branching_phases, 
                    BranchingPhase(stbranch_phases_num_candidates[2], intrmphase_conquer, ProductScore())
                )    
            end
        end            
        push!(branching_phases, BranchingPhase(last(stbranch_phases_num_candidates), conquer, TreeDepthScore()))    
        branching = StrongBranching(rules = branching_rules, phases = branching_phases)
    else
        branching = ClassicBranching(rules = branching_rules)
    end

    return TreeSearchAlgorithm(
        conqueralg = conquer,
        dividealg = branching,
        maxnumnodes = maxnumnodes,
        branchingtreefile = branchingtreefile,
        jsonfile = jsonfile,
        opt_atol = opt_atol;
        opt_rtol = opt_rtol
    )
end    
############################################################################################
# AbstractConquerInput implementation for the strong branching.
############################################################################################
"Conquer input object created by the strong branching algorithm."
struct ConquerInputFromSb <: AbstractConquerInput
    children_candidate::SbNode
    children_units_to_restore::UnitsUsage
end

get_opt_state(i::ConquerInputFromSb) = i.children_candidate.optstate
get_node_depth(i::ConquerInputFromSb) = i.children_candidate.depth
get_units_to_restore(i::ConquerInputFromSb) = i.children_units_to_restore
run_conquer(::ConquerInputFromSb) = true

############################################################################################
# NoBranching
############################################################################################

"""
    NoBranching

Divide algorithm that does nothing. It does not generate any child.
"""
struct NoBranching <: AlgoAPI.AbstractDivideAlgorithm end

function run!(::NoBranching, ::Env, reform::Reformulation, ::Branching.AbstractDivideInput)
    return DivideOutput([], OptimizationState(getmaster(reform)))
end

############################################################################################
# Branching API implementation for the (classic) branching
############################################################################################

"""
    ClassicBranching(
        selection_criterion = MostFractionalCriterion()
        rules = [Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)]
    )

Chooses the best candidate according to a selection criterion and generates the two children.
"""
struct ClassicBranching <: AlgoAPI.AbstractDivideAlgorithm
    selection_criterion::Branching.AbstractSelectionCriterion
    rules::Vector{Branching.PrioritisedBranchingRule}
    int_tol::Float64
    ClassicBranching(;
        selection_criterion = MostFractionalCriterion(),
        rules = [Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)],
        int_tol = 1e-6
    ) = new(selection_criterion, rules, int_tol)
end


struct BranchingContext{SelectionCriterion<:Branching.AbstractSelectionCriterion} <: Branching.AbstractBranchingContext
    selection_criterion::SelectionCriterion
    rules::Vector{Branching.PrioritisedBranchingRule}
    max_nb_candidates::Int
    int_tol::Float64
end

branching_context_type(::ClassicBranching) = BranchingContext
Branching.get_selection_nb_candidates(ctx::BranchingContext) = ctx.max_nb_candidates

function new_context(::Type{<:BranchingContext}, algo::ClassicBranching, _)
    return BranchingContext(algo.selection_criterion, algo.rules, 1, algo.int_tol)
end

Branching.get_int_tol(ctx::BranchingContext) = ctx.int_tol
Branching.get_selection_criterion(ctx::BranchingContext) = ctx.selection_criterion
Branching.get_rules(ctx::BranchingContext) = ctx.rules

function Branching.new_ip_primal_sols_pool(ctx::BranchingContext, reform::Reformulation, input)
    # Optimization state with no information.
    return OptimizationState(getmaster(reform))
end

function _is_integer(sol::PrimalSolution)
    for (varid, val) in sol
        integer_val = abs(val - round(val)) < 1e-5
        if !integer_val
            return false
        end
    end
    return true
end

function _has_identical_sps(master::Formulation{DwMaster}, reform::Reformulation)
    for (sp_id, sp) in get_dw_pricing_sps(reform)
        lm_constr_id = sp.duty_data.lower_multiplicity_constr_id 
        um_constr_id = sp.duty_data.upper_multiplicity_constr_id
        lb = getcurrhs(master, lm_constr_id)
        ub = getcurrhs(master, um_constr_id)
        if ub > 1
            return true
        end
    end
    return false
end

function _why_no_candidate(master::Formulation{DwMaster}, reform, input, extended_sol, original_sol)
    integer_orig_sol = _is_integer(original_sol)
    integer_ext_sol = _is_integer(extended_sol)
    identical_sp = _has_identical_sps(master, reform)
    if integer_orig_sol && !integer_ext_sol && identical_sp
        message =  """
        The solution to the master is not integral and the projection on the original variables is integral.
        Your reformulation involves subproblems with upper multiplicity greater than 1.
        Column generation algorithm could not create an integral solution to the master using the column generated.
        In order to generate columns that can lead to an integral solution, you may have to use a branching scheme that changes the structure of the subproblems.
        This is not provided by the default implementation of the branching algorithm in the current version of Coluna.
        """
        @warn message
    end
    return nothing
end

function _why_no_candidate(::Formulation{BendersMaster}, reform, input, extended_sol, original_sol)
    return nothing
end

function Branching.why_no_candidate(reform::Reformulation, input, extended_sol, original_sol)
    master = getmaster(reform)
    return _why_no_candidate(master, reform, input, extended_sol, original_sol)
end

Branching.new_divide_output(children::Vector{SbNode}, optimization_state) = DivideOutput(children, optimization_state)
Branching.new_divide_output(::Nothing, optimization_state) = DivideOutput(SbNode[], optimization_state)

############################################################################################
# Branching API implementation for the strong branching
############################################################################################
"""
    BranchingPhase(max_nb_candidates, conquer_algo)

Define a phase in strong branching. It contains the maximum number of candidates
to evaluate and the conquer algorithm which does evaluation.
"""
struct BranchingPhase
    max_nb_candidates::Int64
    conquer_algo::AbstractConquerAlgorithm
    score::Branching.AbstractBranchingScore
end

"""
    StrongBranching

The algorithm that performs a (multi-phase) (strong) branching in a tree search algorithm.

Strong branching is a procedure that heuristically selects a branching constraint that
potentially gives the best progress of the dual bound. The procedure selects a collection 
of branching candidates based on their branching rule and their score.
Then, the procedure evaluates the progress of the dual bound in both branches of each branching
candidate by solving both potential children using a conquer algorithm.
The candidate that has the largest product of dual bound improvements in the branches 
is chosen to be the branching constraint.

When the dual bound improvement produced by the branching constraint is difficult to compute
(e.g. time-consuming in the context of column generation), one can let the branching algorithm
quickly estimate the dual bound improvement of each candidate and retain the most promising
branching candidates. This is called a **phase**. The goal is to first evaluate a large number
of candidates with a very fast conquer algorithm and retain a certain number of promising ones. 
Then, over the phases, it evaluates the improvement with a more precise conquer algorithm and
restrict the number of retained candidates until only one is left.
"""
struct StrongBranching <: AlgoAPI.AbstractDivideAlgorithm
    phases::Vector{BranchingPhase}
    rules::Vector{Branching.PrioritisedBranchingRule}
    selection_criterion::Branching.AbstractSelectionCriterion
    verbose::Bool
    int_tol::Float64
    StrongBranching(;
        phases = [],
        rules = [],
        selection_criterion = MostFractionalCriterion(),
        verbose = true,
        int_tol = 1e-6
    ) = new(phases, rules, selection_criterion, verbose, int_tol)
end

## Implementation of Algorithm API.

# StrongBranching does not use any storage unit itself, 
# therefore get_units_usage() is not defined for it

function get_child_algorithms(algo::StrongBranching, reform::Reformulation) 
    child_algos = Tuple{AlgoAPI.AbstractAlgorithm, AbstractModel}[]
    for phase in algo.phases
        push!(child_algos, (phase.conquer_algo, reform))
    end
    for prioritised_rule in algo.rules
        push!(child_algos, (prioritised_rule.rule, reform))
    end
    return child_algos
end

# Implementation of the strong branching API.
struct StrongBranchingPhaseContext <: Branching.AbstractStrongBrPhaseContext
    phase_params::BranchingPhase
    units_to_restore_for_conquer::UnitsUsage
end

Branching.get_score(ph::StrongBranchingPhaseContext) = ph.phase_params.score
Branching.get_conquer(ph::StrongBranchingPhaseContext) = ph.phase_params.conquer_algo
Branching.get_units_to_restore_for_conquer(ph::StrongBranchingPhaseContext) = ph.units_to_restore_for_conquer
Branching.get_max_nb_candidates(ph::StrongBranchingPhaseContext) = ph.phase_params.max_nb_candidates

function new_phase_context(::Type{StrongBranchingPhaseContext}, phase::BranchingPhase, reform, _)
    units_to_restore_for_conquer = collect_units_to_restore!(phase.conquer_algo, reform)
    return StrongBranchingPhaseContext(phase, units_to_restore_for_conquer)
end

struct StrongBranchingContext{
    PhaseContext<:Branching.AbstractStrongBrPhaseContext,
    SelectionCriterion<:Branching.AbstractSelectionCriterion
} <: Branching.AbstractStrongBrContext
    phases::Vector{PhaseContext}
    rules::Vector{Branching.PrioritisedBranchingRule}
    selection_criterion::SelectionCriterion
    int_tol::Float64
end

Branching.get_selection_nb_candidates(ctx::StrongBranchingContext) = Branching.get_max_nb_candidates(first(ctx.phases))
Branching.get_rules(ctx::StrongBranchingContext) = ctx.rules
Branching.get_selection_criterion(ctx::StrongBranchingContext) = ctx.selection_criterion
Branching.get_int_tol(ctx::StrongBranchingContext) = ctx.int_tol
Branching.get_phases(ctx::StrongBranchingContext) = ctx.phases

function branching_context_type(algo::StrongBranching)
    select_crit_type = typeof(algo.selection_criterion)
    if algo.verbose
        return BranchingPrinter{StrongBranchingContext{PhasePrinter{StrongBranchingPhaseContext},select_crit_type}}
    end
    return StrongBranchingContext{StrongBranchingPhaseContext,select_crit_type}
end

function new_context(
    ::Type{StrongBranchingContext{PhaseContext, SelectionCriterion}}, algo::StrongBranching, reform
) where {PhaseContext<:Branching.AbstractStrongBrPhaseContext,SelectionCriterion<:Branching.AbstractSelectionCriterion}
    if isempty(algo.rules)
        error("Strong branching: no branching rule is defined.")
    end

    if isempty(algo.phases)
        error("Strong branching: no branching phase is defined.")
    end

    phases = map(((i, phase),) -> new_phase_context(PhaseContext, phase, reform, i), enumerate(algo.phases))
    return StrongBranchingContext(
        phases, algo.rules, algo.selection_criterion, algo.int_tol
    )
end

function Branching.eval_child_of_candidate!(child, phase::Branching.AbstractStrongBrPhaseContext, ip_primal_sols_found, env, reform, input)    
    child_state = OptimizationState(
        getmaster(reform);
        ip_primal_bound = get_ip_primal_bound(Branching.get_conquer_opt_state(input)),    
    )
    child.optstate = child_state

    # In the `ip_primal_sols_found`, we maintain all the primal solutions found during the 
    # strong branching procedure but also the best primal bound found so far (in the whole optimization).
    update_ip_primal_bound!(child_state, get_ip_primal_bound(ip_primal_sols_found))

    # TODO: We consider that all branching algorithms don't exploit the primal solution 
    # at the moment.
    # best_ip_primal_sol = get_best_ip_primal_sol(sbstate)
    # if !isnothing(best_ip_primal_sol)
    #     set_ip_primal_sol!(nodestate, best_ip_primal_sol)
    # end
    
    if !ip_gap_closed(child_state)
        units_to_restore = Branching.get_units_to_restore_for_conquer(phase)
        restore_from_records!(units_to_restore, child.records)
        input = ConquerInputFromSb(child, units_to_restore)
        run!(Branching.get_conquer(phase), env, reform, input)
        TreeSearch.set_records!(child, create_records(reform))
    end
    child.conquerwasrun = true

    # Store new primal solutions found during the evaluation of the child.
    add_ip_primal_sols!(ip_primal_sols_found, get_ip_primal_sols(child_state)...)
    return
end

function Branching.new_ip_primal_sols_pool(ctx::StrongBranchingContext, reform, input)
    # Optimization state with copy of bounds only (except lp_primal_bound).
    # Only the ip primal bound is used to avoid inserting integer solutions that are not
    # better than the incumbent.
    # We also use the primal bound to init candidate nodes in the strong branching procedure.
    input_opt_state = Branching.get_conquer_opt_state(input)
    return OptimizationState(
        getmaster(reform);
        ip_primal_bound = get_ip_primal_bound(input_opt_state),
    )
end
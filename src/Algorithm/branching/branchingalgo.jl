############################################################################################
# AbstractConquerInput implementation for the strong branching.
############################################################################################
"Conquer input object created by the strong branching algorithm."
struct ConquerInputFromSb <: AbstractConquerInput
    global_primal_handler::GlobalPrimalBoundHandler
    children_candidate::SbNode
    children_units_to_restore::UnitsUsage
end

get_conquer_input_ip_dual_bound(i::ConquerInputFromSb) = get_ip_dual_bound(i.children_candidate.optstate)
get_global_primal_handler(i::ConquerInputFromSb) = i.global_primal_handler
get_node_depth(i::ConquerInputFromSb) = i.children_candidate.depth
get_units_to_restore(i::ConquerInputFromSb) = i.children_units_to_restore

############################################################################################
# NoBranching
############################################################################################

"""
Divide algorithm that does nothing. It does not generate any child.
"""
struct NoBranching <: AlgoAPI.AbstractDivideAlgorithm end

function run!(::NoBranching, ::Env, reform::Reformulation, ::Branching.AbstractDivideInput)
    return DivideOutput([])
end

############################################################################################
# Branching API implementation for the (classic) branching
############################################################################################

"""
    ClassicBranching(
        selection_criterion = MostFractionalCriterion()
        rules = [Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)]
        int_tol = 1e-6
    )

Chooses the best candidate according to a selection criterion and generates the two children.

**Parameters**
- `selection_criterion`: selection criterion to choose the best candidate
- `rules`: branching rules to generate the candidates
- `int_tol`: tolerance to determine if a variable is integer

It is implemented as a specific case of the strong branching algorithm.
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

Branching.new_divide_output(children::Vector{SbNode}) = DivideOutput(children)
Branching.new_divide_output(::Nothing) = DivideOutput(SbNode[])

############################################################################################
# Branching API implementation for the strong branching
############################################################################################
"""
    BranchingPhase(max_nb_candidates, conquer_algo, score)

Define a phase in strong branching. It contains the maximum number of candidates
to evaluate, the conquer algorithm which does evaluation, and the score used to sort the 
candidates.
"""
struct BranchingPhase
    max_nb_candidates::Int64
    conquer_algo::AbstractConquerAlgorithm
    score::Branching.AbstractBranchingScore
end

"""
    StrongBranching(
        phases = [],
        rules = [Branching.PrioritisedBranchingRule(SingleVarBranchingRule(), 1.0, 1.0)],
        selection_criterion = MostFractionalCriterion(),
        verbose = true,
        int_tol = 1e-6
    )

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

**Parameters**:

- `phases`: a vector of [`Coluna.Algorithm.BranchingPhase`](@ref)
- `rules`: a vector of [`Coluna.Algorithm.Branching.PrioritisedBranchingRule`](@ref)
- `selection_criterion`: a selection criterion to choose the initial candidates
- `verbose`: if true, print the progress of the strong branching procedure
- `int_tol`: tolerance to determine if a variable is integer
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
    child_algos = Dict()
    for (i, phase) in enumerate(algo.phases)
        child_algos["phase$i"] = (phase.conquer_algo, reform)
    end
    for (i, prioritised_rule) in enumerate(algo.rules)
        child_algos["rule$i"] = (prioritised_rule.rule, reform)
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

function Branching.eval_child_of_candidate!(child, phase::Branching.AbstractStrongBrPhaseContext, env, reform, input)    
    child_state = OptimizationState(getmaster(reform))
    child.conquer_output = child_state

    global_primal_handler = Branching.get_global_primal_handler(input)
    update_ip_primal_bound!(child_state, get_global_primal_bound(global_primal_handler))
        
    if !ip_gap_closed(child_state)
        units_to_restore = Branching.get_units_to_restore_for_conquer(phase)
        restore_from_records!(units_to_restore, child.records)
        conquer_input = ConquerInputFromSb(global_primal_handler, child, units_to_restore)
        child.conquer_output = run!(Branching.get_conquer(phase), env, reform, conquer_input)
        child.ip_dual_bound = get_lp_dual_bound(child.conquer_output)
        for sol in get_ip_primal_sols(child.conquer_output)
            store_ip_primal_sol!(global_primal_handler, sol)
        end
        TreeSearch.set_records!(child, create_records(reform))
    end

    # Store new primal solutions found during the evaluation of the child.
    for sol in get_ip_primal_sols(child_state)
        store_ip_primal_sol!(global_primal_handler, sol)
    end
    return
end

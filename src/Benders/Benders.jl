module Benders

include("../MustImplement/MustImplement.jl")
using .MustImplement

abstract type AbstractBendersContext end

struct UnboundedError <: Exception end

"Returns `true` if the objective sense is minimization, `false` otherwise."
@mustimplement "Benders" is_minimization(context::AbstractBendersContext) = nothing

"Returns Benders reformulation."
@mustimplement "Benders" get_reform(context::AbstractBendersContext) = nothing

"Returns the master problem."
@mustimplement "Benders" get_master(context::AbstractBendersContext) = nothing

"Returns the separation subproblems."
@mustimplement "Benders" get_benders_subprobs(context) = nothing

"""
    optimize_master_problem!(master, context, env) -> MasterResult

Returns an instance of a custom object `MasterResult` that implements the following methods:
- `is_unbounded(res::MasterResult) -> Bool`
- `is_infeasible(res::MasterResult) -> Bool`
- `is_certificate(res::MasterResult) -> Bool`
- `get_primal_sol(res::MasterResult) -> Union{Nothing, PrimalSolution}`
"""
@mustimplement "Benders" optimize_master_problem!(master, context, env) = nothing

"""
    treat_unbounded_master_problem_case!(master, context, env) -> MasterResult

When after a call to `optimize_master_problem!`, the master is unbounded, this method is called.
Returns an instance of a custom object `MasterResult`.
"""
@mustimplement "Benders" treat_unbounded_master_problem_case!(master, context, env) = nothing

# Master solution
"Returns `true` if the master is unbounded, `false` otherwise."
@mustimplement "Benders" is_unbounded(res) = nothing

"Returns `true` if the master is infeasible, `false` otherwise."
@mustimplement "Benders" is_infeasible(res) = nothing

"Returns the certificate of dual infeasibility if the master is unbounded, `nothing` otherwise."
@mustimplement "Benders" is_certificate(res) = nothing

"Returns the primal solution of the master problem if it exists, `nothing` otherwise."
@mustimplement "Benders" get_primal_sol(res) = nothing

# second stage variable costs
@mustimplement "Benders" set_second_stage_var_costs_to_zero!(context) = nothing

@mustimplement "Benders" reset_second_stage_var_costs!(context) = nothing

@mustimplement "Benders" update_sp_rhs!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" setup_separation_for_unbounded_master_case!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" set_of_cuts(context) = nothing

@mustimplement "Benders" set_of_sep_sols(context) = nothing

"""
    optimize_separation_problem!(context, sp_to_solve, env, unbounded_master) -> SeparationResult

Returns an instance of a custom object `SeparationResult` that implements the following methods:
- `is_unbounded(res::SeparationResult) -> Bool`
- `is_infeasible(res::SeparationResult) -> Bool`
- `get_obj_val(res::SeparationResult) -> Float64`
- `get_primal_sol(res::SeparationResult) -> Union{Nothing, PrimalSolution}`
- `get_dual_sp_sol(res::SeparationResult) -> Union{Nothing, DualSolution}`
"""
@mustimplement "Benders" optimize_separation_problem!(context, sp_to_solve, env, unbounded_master) = nothing

"""
    treat_infeasible_separation_problem_case!(context, sp_to_solve, env, unbounded_master) -> SeparationResult

When after a call to `optimize_separation_problem!`, the separation problem is infeasible, this method is called.
Returns an instance of a custom object `SeparationResult`.
"""
@mustimplement "Benders" treat_infeasible_separation_problem_case!(context, sp_to_solve, env, unbounded_master_case) = nothing

"Returns the dual solution of the separation problem if it exists; `nothing` otherwise."
@mustimplement "Benders" get_dual_sol(res) = nothing

@mustimplement "Benders" update_sp_dual_vars!(context, sp_to_solve, dual_sol) = nothing

@mustimplement "Benders" push_in_set!(context, generated_cuts, dual_sol) = nothing

@mustimplement "Benders" insert_cuts!(reform, context, generated_cuts) = nothing

@mustimplement "Benders" benders_iteration_output_type(::AbstractBendersContext) = nothing

abstract type AbstractBendersIterationOutput end

@mustimplement "Benders" new_iteration_output(::Type{<:AbstractBendersIterationOutput}, is_min_sense, nb_cuts_inserted, ip_primal_sol, infeasible, time_limit_reached, master_obj_val) = nothing

@mustimplement "Benders" after_benders_iteration(::AbstractBendersContext, phase, env, iteration, benders_iter_output) = nothing

@mustimplement "Benders" stop_benders(::AbstractBendersContext, benders_iter_output, iteration) = nothing

@mustimplement "Benders" benders_output_type(::AbstractBendersContext) = nothing

abstract type AbstractBendersOutput end

@mustimplement "Benders" new_output(::Type{<:AbstractBendersOutput}, benders_iter_output) = nothing

@mustimplement "BendersMasterResult" get_obj_val(master_res) = nothing

@mustimplement "Benders" setup_reformulation!(reform, env) = nothing

@mustimplement "Benders" build_primal_solution(context, mast_primal_sol, sep_sp_sols) = nothing

@mustimplement "Benders" master_is_unbounded(context, second_stage_cost, unbounded_master_case) = nothing

function run_benders_loop!(context, env; iter = 1)
    iteration = iter
    phase = nothing
    ip_primal_sol = nothing
    benders_iter_output = nothing
    setup_reformulation!(get_reform(context), env)
    while !stop_benders(context, benders_iter_output, iteration)
        benders_iter_output = run_benders_iteration!(context, phase, env, ip_primal_sol)
        after_benders_iteration(context, phase, env, iteration, benders_iter_output)
        iteration += 1
    end
    O = benders_output_type(context)
    return new_output(O, benders_iter_output)
end

# Benders cut generation implementation must handle the following cases:
# - optimize the "classic" separation problem (Separation)
# - optimize the feasibility "classic" separation problem (Phase 1 - Separation)
# - optimize the separation problem "for the unbounded master" (Separation for unbounded master)
# - optimize the feasibility separation problem "for the unbounded master" (Phase 1 - Separation for unbounded master)

# The following diagram is an overview of the transitions between the procedures.
# If the procedure ends up with "infeasible" or "unbounded", the transition consists in
# adding the cut to the master and going back to the master optimization (next iteration).

# stateDiagram-v2
#     state "Separation for unbounded master" as unbounded_master
#     state "Phase 1 - Separation for unbounded master" as infeasible_unbounded
#     state "Phase 1 - Separation" as infeasible
#     [*] --> Master
#     Master --> unbounded_master : unbounded
#     unbounded_master --> infeasible_unbounded : infeasible
#     Master --> Separation : optimal
#     Separation --> infeasible : infeasible
#     Master --> [*] : infeasible
#     infeasible_unbounded --> [*] : infeasible/unbounded
#     infeasible --> [*] : infeasible/unbounded
#     Separation --> [*] : unbounded

function run_benders_iteration!(context, phase, env, ip_primal_sol)
    master = get_master(context)
    mast_result = optimize_master_problem!(master, context, env)
    O = benders_iteration_output_type(context)
    is_min_sense = is_minimization(context)

    # At least at the first iteration, if the master does not contain any Benders cut, the master will be
    # unbounded. The implementation must provide a routine to handle this case.
    # If the master is a MIP, we have to relax integrality constraints to retrieve a dual infeasibility
    # certificate.
    if is_unbounded(mast_result)
        mast_result = treat_unbounded_master_problem_case!(master, context, env)
    end

    # If the master is unbounded (even after treating unbounded master problem case), we
    # stop the algorithm because we don't handle unboundedness.
    if is_unbounded(mast_result)
        throw(UnboundedError())
    end

    # If the master is infeasible, it means the first level is infeasible and so the whole problem.
    # We stop Benders.
    if is_infeasible(mast_result)
        return new_iteration_output(O, is_min_sense, 0, nothing, true, false, nothing)
    end

    mast_primal_sol = get_primal_sol(mast_result)

    # Depending on whether the master was unbounded, we will solve a different separation problem.
    # See Lemma 2 of "Implementing Automatic Benders Decomposition in a Modern MIP Solver" (Bonami et al., 2020)
    # for more information.
    unbounded_master_case = is_certificate(mast_result)

    # Separation problems setup.
    for (_, sp) in get_benders_subprobs(context)
        if unbounded_master_case
            setup_separation_for_unbounded_master_case!(context, sp, mast_primal_sol)
        else
            update_sp_rhs!(context, sp, mast_primal_sol)
        end
    end

    # Solve the separation problems.
    generated_cuts = set_of_cuts(context)
    sep_sp_sols = set_of_sep_sols(context)
    second_stage_cost = 0.0
    for (_, sp_to_solve) in get_benders_subprobs(context)
        sep_result = optimize_separation_problem!(context, sp_to_solve, env, unbounded_master_case)

        if is_infeasible(sep_result)
            sep_result = treat_infeasible_separation_problem_case!(context, sp_to_solve, env, unbounded_master_case)
        end

        if is_unbounded(sep_result)
            throw(UnboundedError())
        end

        if is_infeasible(sep_result)
            return new_iteration_output(O, is_min_sense, 0, nothing, true, false, nothing)
        end

        second_stage_cost += get_obj_val(sep_result)

        nb_cuts_pushed = 0
        if push_in_set!(context, generated_cuts, sep_result)
            nb_cuts_pushed += 1
        else
            push_in_set!(context, sep_sp_sols, sep_result)
        end
    end

    if master_is_unbounded(context, second_stage_cost, unbounded_master_case)
        throw(UnboundedError())
    end

    cut_ids = insert_cuts!(get_reform(context), context, generated_cuts)
    nb_cuts_inserted = length(cut_ids)

    # Build primal solution
    ip_primal_sol = nothing
    if nb_cuts_inserted == 0
        ip_primal_sol = build_primal_solution(context, mast_primal_sol, sep_sp_sols)
    end
    
    master_obj_val = get_obj_val(mast_result)
    return new_iteration_output(O, is_min_sense, nb_cuts_inserted, ip_primal_sol, false, false, master_obj_val)
end

end
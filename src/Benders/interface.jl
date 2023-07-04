############################################################################################
# Reformulation getters
############################################################################################
"Returns `true` if the objective sense is minimization, `false` otherwise."
@mustimplement "BendersProbInfo" is_minimization(context::AbstractBendersContext) = nothing

"Returns Benders reformulation."
@mustimplement "BendersProbInfo" get_reform(context::AbstractBendersContext) = nothing

"Returns the master problem."
@mustimplement "BendersProbInfo" get_master(context::AbstractBendersContext) = nothing

"Returns the separation subproblems."
@mustimplement "BendersProbInfo" get_benders_subprobs(context) = nothing

############################################################################################
# Main loop
############################################################################################
"Prepares the reformulation before starting the Benders cut generation algorithm."
@mustimplement "Benders" setup_reformulation!(reform, env) = nothing

"Returns `true` if the Benders cut generation algorithm must stop, `false` otherwise."
@mustimplement "Benders" stop_benders(::AbstractBendersContext, benders_iter_output, iteration) = nothing

"Placeholder method called after each iteration of the Benders cut generation algorithm."
@mustimplement "Benders" after_benders_iteration(::AbstractBendersContext, phase, env, iteration, benders_iter_output) = nothing

############################################################################################
# Benders output
############################################################################################
"Supertype for the custom objects that will store the output of the Benders cut generation algorithm."
abstract type AbstractBendersOutput end

"""
    benders_output_type(context) -> Type{<:AbstractBendersOutput}

Returns the type of the custom object that will store the output of the Benders cut generation
algorithm.
"""
@mustimplement "Benders" benders_output_type(::AbstractBendersContext) = nothing

"Returns a new instance of the custom object that stores the output of the Benders cut generation algorithm."
@mustimplement "Benders" new_output(::Type{<:AbstractBendersOutput}, benders_iter_output) = nothing

############################################################################################
# Master optimization
############################################################################################
"""
    optimize_master_problem!(master, context, env) -> MasterResult

Returns an instance of a custom object `MasterResult` that implements the following methods:
- `is_unbounded(res::MasterResult) -> Bool`
- `is_infeasible(res::MasterResult) -> Bool`
- `is_certificate(res::MasterResult) -> Bool`
- `get_primal_sol(res::MasterResult) -> Union{Nothing, PrimalSolution}`
"""
@mustimplement "Benders" optimize_master_problem!(master, context, env) = nothing

############################################################################################
# Unbounded master case
############################################################################################
"""
    treat_unbounded_master_problem_case!(master, context, env) -> MasterResult

When after a call to `optimize_master_problem!`, the master is unbounded, this method is called.
Returns an instance of a custom object `MasterResult`.
"""
@mustimplement "Benders" treat_unbounded_master_problem_case!(master, context, env) = nothing

############################################################################################
# Update separation subproblems
############################################################################################
"""
    update_sp_rhs!(context, sp, mast_primal_sol)

Updates the right-hand side of the separation problem `sp` by fixing the first-level solution
obtained by solving the master problem `mast_primal_sol`.
"""
@mustimplement "Benders" update_sp_rhs!(context, sp, mast_primal_sol) = nothing

"""
    setup_separation_for_unbounded_master_case!(context, sp, mast_primal_sol)

Updates the separation problem to derive a cut when the master problem is unbounded.
"""
@mustimplement "Benders" setup_separation_for_unbounded_master_case!(context, sp, mast_primal_sol) = nothing

############################################################################################
# Separation problem optimization
############################################################################################
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

############################################################################################
# Cuts and primal solutions
############################################################################################
"""
Returns an empty container that will store all the cuts generated by the separation problems
during an iteration of the Benders cut generation algorithm.
One must be able to iterate on this container to insert the cuts in the master problem.
"""
@mustimplement "Benders" set_of_cuts(context) = nothing

"""
Returns an empty container that will store the primal solutions to the separation problems
at a given iteration of the Benders cut generation algorithm.
"""
@mustimplement "Benders" set_of_sep_sols(context) = nothing


"""
    push_in_set!(context, cut_pool, sep_result) -> Bool

Inserts a cut in the set of cuts generated at a given iteration of the Benders cut generation algorithm.
The `cut_pool` structure is generated by `set_of_cuts(context)`.

    push_in_set!(context, sep_sp_sols, sep_result) -> Bool

Inserts a primal solution to a separation problem in the set of primal solutions generated at a given iteration of the Benders cut generation algorithm.
The `sep_sp_sols` structure is generated by `set_of_sep_sols(context)`.

Returns `true` if the cut or the primal solution was inserted in the set, `false` otherwise.
"""
@mustimplement "Benders" push_in_set!(context, pool, elem) = nothing

############################################################################################
# Cuts insertion
############################################################################################
"Inserts the cuts into the master."
@mustimplement "Benders" insert_cuts!(reform, context, generated_cuts) = nothing

############################################################################################
# Benders iteration output
############################################################################################

"Supertype for the custom objects that will store the output of a Benders iteration."
abstract type AbstractBendersIterationOutput end

"""
    benders_iteration_output_type(context) -> Type{<:AbstractBendersIterationOutput}

Returns the type of the custom object that will store the output of a Benders iteration.
"""
@mustimplement "Benders" benders_iteration_output_type(::AbstractBendersContext) = nothing

"Returns a new instance of the custom object that stores the output of a Benders iteration."
@mustimplement "Benders" new_iteration_output(::Type{<:AbstractBendersIterationOutput}, is_min_sense, nb_cuts_inserted, ip_primal_sol, infeasible, time_limit_reached, master_obj_val) = nothing

############################################################################################
# Optimization result getters
############################################################################################
"Returns `true` if the problem is unbounded, `false` otherwise."
@mustimplement "Benders" is_unbounded(res) = nothing

"Returns `true` if the master is infeasible, `false` otherwise."
@mustimplement "Benders" is_infeasible(res) = nothing

"Returns the certificate of dual infeasibility if the master is unbounded, `nothing` otherwise."
@mustimplement "Benders" is_certificate(res) = nothing

"Returns the primal solution of the master problem if it exists, `nothing` otherwise."
@mustimplement "Benders" get_primal_sol(res) = nothing

"Returns the dual solution of the separation problem if it exists; `nothing` otherwise."
@mustimplement "Benders" get_dual_sol(res) = nothing

"Returns the objective value of the master or separation problem."
@mustimplement "BendersMasterResult" get_obj_val(master_res) = nothing

############################################################################################
# Build primal solution
############################################################################################
"""
Builds a primal solution to the original problem from the primal solution to the master 
problem and the primal solutions to the separation problems.
"""
@mustimplement "Benders" build_primal_solution(context, mast_primal_sol, sep_sp_sols) = nothing

############################################################################################
# Master unboundedness
############################################################################################

"Returns `true` if the master has been proven unbounded, `false` otherwise."
@mustimplement "Benders" master_is_unbounded(context, second_stage_cost, unbounded_master_case) = nothing

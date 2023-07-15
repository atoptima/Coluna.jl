struct UnboundedProblemError <: Exception
    message::String
end

############################################################################################
# Reformulation getters
############################################################################################
"Returns Dantzig-Wolfe reformulation."
@mustimplement "ColGen" get_reform(ctx) = nothing

"Returns master formulation."
@mustimplement "ColGen" get_master(ctx) = nothing

"Returns `true` if the objective sense is minimization; `false` otherwise."
@mustimplement "ColGen" is_minimization(ctx) = nothing

"""
    get_pricing_subprobs(ctx) -> Vector{Tuple{SuproblemId, SpFormulation}}

Returns subproblem formulations.
"""
@mustimplement "ColGen" get_pricing_subprobs(ctx) = nothing

############################################################################################
# Result getters
############################################################################################
"Returns true if a master or pricing problem result is infeasible; false otherwise."
@mustimplement "ColGenResultGetter" is_infeasible(res) = nothing

"Returns true if a master or pricing problem result is unbounded; false otherwise."
@mustimplement "ColGenResultGetter" is_unbounded(res) = nothing

"""
Returns the optimal objective value of the master LP problem."
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenResultGetter" get_obj_val(master_res) = nothing

"Returns primal solution to the master LP problem."
@mustimplement "ColGenResultGetter" get_primal_sol(master_res) = nothing

"Returns dual solution to the master optimization problem."
@mustimplement "ColGenResultGetter" get_dual_sol(master_res) = nothing

"Array of primal solutions to the pricing subproblem"
@mustimplement "ColGenResultGetter" get_primal_sols(pricing_res) = nothing

"""
Returns dual bound of the pricing subproblem; `nothing` if no dual bound is available and
the initial dual bound returned by `compute_sp_init_db` will be used to compute the master
dual bound.
"""
@mustimplement "ColGenResultGetter" get_dual_bound(pricing_res) = nothing

"""
Returns primal bound of the pricing subproblem; `nothing` if no primal bound is available
and the initial dual bound returned by `compute_sp_init_pb` will be used to compute the
pseudo dual bound.
"""
@mustimplement "ColGenResultGetter" get_primal_bound(pricing_res) = nothing

############################################################################################
# Master resolution.
############################################################################################

"""
    optimize_master_lp_problem!(master, context, env) -> MasterResult

Returns an instance of a custom object `MasterResult` that implements the following methods:
- `get_obj_val`: objective value of the master (mandatory)
- `get_primal_sol`: primal solution to the master (optional)
- `get_dual_sol`: dual solution to the master (mandatory otherwise column generation stops)

It should at least return a dual solution (obtained with LP optimization or subgradient) 
otherwise column generation cannot continue.
"""
@mustimplement "ColGenMaster" optimize_master_lp_problem!(master, context, env) = nothing

############################################################################################
# Master solution integrality.
############################################################################################

"""
Returns a primal solution expressed in the original problem variables if the current master
LP solution is integer feasible; `nothing` otherwise.
"""
@mustimplement "ColGenMasterIntegrality" check_primal_ip_feasibility!(mast_lp_primal_sol, ::AbstractColGenContext, phase, env) = nothing

"""
Returns `true` if the new master IP primal solution is better than the current; `false` otherwise.
"""
@mustimplement "ColGenMasterIntegrality" is_better_primal_sol(new_ip_primal_sol, ip_primal_sol) = nothing

############################################################################################
# Master IP incumbent.
############################################################################################
"""
Updates the current master IP primal solution.
"""
@mustimplement "ColGenMasterUpdateIncumbent" update_inc_primal_sol!(ctx::AbstractColGenContext, ip_primal_sol) = nothing

############################################################################################
# Reduced costs calculation.
############################################################################################
"""
Updates dual value of the master constraints.
Dual values of the constraints can be used when the pricing solver supports non-robust cuts.
"""
@mustimplement "ColGenReducedCosts" update_master_constrs_dual_vals!(ctx, mast_lp_dual_sol) = nothing

"""
Method that you can implement if you want to store the reduced cost of subproblem variables
in the context.
"""
@mustimplement "ColGenReducedCosts" update_reduced_costs!(context, phase, red_costs) = nothing

"""
Returns the original cost `c` of subproblems variables.
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts" get_subprob_var_orig_costs(ctx::AbstractColGenContext) = nothing

"""
Returns the coefficient matrix `A` of subproblem variables in the master
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts" get_subprob_var_coef_matrix(ctx::AbstractColGenContext) = nothing

"Updates reduced costs of variables of a given subproblem."
@mustimplement "ColGenReducedCosts" update_sp_vars_red_costs!(ctx::AbstractColGenContext, sp, red_costs) = nothing

############################################################################################
# Dual bound calculation.
############################################################################################
"""
Returns an initial dual bound for a pricing subproblem.
Default value should be +/- infinite depending on the optimization sense.
"""
@mustimplement "ColGenDualBound" compute_sp_init_db(ctx, sp) = nothing

"""
Returns an initial primal bound for a pricing subproblem.
Default value should be +/- infinite depending on the optimization sense.
"""
@mustimplement "ColGenDualBound" compute_sp_init_pb(ctx, sp) = nothing

"""
    compute_dual_bound(ctx, phase, master_lp_obj_val, master_dbs, generated_columns, mast_dual_sol) -> Float64

Caculates the dual bound at a given iteration of column generation.
The dual bound is composed of:
- `master_lp_obj_val`: objective value of the master LP problem
- `master_dbs`: dual values of the pricing subproblems
- the contribution of the master convexity constraints that you should compute from `mast_dual_sol`.
"""
@mustimplement "ColGenDualBound" compute_dual_bound(ctx, phase, master_dbs, generated_columns, mast_dual_sol) = nothing

############################################################################################
# Columns insertion.
############################################################################################

"""
Inserts columns into the master. Returns the number of columns inserted.
Implementation is responsible for checking if the column must be inserted and warn the user
if something unexpected happens.
"""
@mustimplement "ColGenColInsertion" insert_columns!(ctx, phase, columns) = nothing

############################################################################################
# Iteration Output
############################################################################################
"Supertype for the objects that contains the output of a column generation iteration."
abstract type AbstractColGenIterationOutput end

"""
    colgen_iteration_output_type(ctx) -> Type{<:AbstractColGenIterationOutput}

Returns the type of the column generation iteration output associated to the context.
"""
@mustimplement "ColGenIterationOutput" colgen_iteration_output_type(::AbstractColGenContext) = nothing

"""
    new_iteration_output(::Type{<:AbstractColGenIterationOutput}, args...) -> AbstractColGenIterationOutput

Arguments (i.e. `arg...`) of this function are the following:
- `min_sense`: `true` if the objective is a minimization function; `false` otherwise
- `mlp`: the optimal solution value of the master LP
- `db`: the Lagrangian dual bound
- `nb_new_cols`: the number of columns inserted into the master
- `new_cut_in_master`: `true` if valid inequalities or new constraints added into the master; `false` otherwise
- `infeasible_master`: `true` if the master is proven infeasible; `false` otherwise
- `unbounded_master`: `true` if the master is unbounded; `false` otherwise
- `infeasible_subproblem`: `true` if a pricing subproblem is proven infeasible; `false` otherwise
- `unbounded_subproblem`: `true` if a pricing subproblem is unbounded; `false` otherwise
- `time_limit_reached`: `true` if time limit is reached; `false` otherwise
- `master_primal_sol`: the primal master LP solution
- `ip_primal_sol`: the incumbent primal master solution
- `dual_sol`: the dual master LP solution
"""
@mustimplement "ColGenIterationOutput" new_iteration_output(
    ::Type{<:AbstractColGenIterationOutput},
    min_sense,
    mlp,
    db,
    nb_new_cols,
    new_cut_in_master,
    infeasible_master,
    unbounded_master,
    infeasible_subproblem,
    unbounded_subproblem,
    time_limit_reached,
    master_primal_sol,
    ip_primal_sol,
    dual_sol
) = nothing

############################################################################################
# Phase Output
############################################################################################
"Supertype for the objects that contains the output of a column generation phase."
abstract type AbstractColGenPhaseOutput end

"""
    colgen_phase_outputype(ctx) -> Type{<:AbstractColGenPhaseOutput}

Returns the type of the column generation phase output associated to the context.
"""
@mustimplement "ColGenPhaseOutput" colgen_phase_output_type(::AbstractColGenContext) = nothing

"""
    new_phase_output(OutputType, min_sense, phase, stage, colgen_iter_output, iter, inc_dual_bound) -> OutputType

Returns the column generation phase output.

Arguments of this function are:
- `OutputType`: the type of the column generation phase output
- `min_sense`: `true` if it is a minimization problem; `false` otherwise
- `phase`: the current column generation phase
- `stage`: the current column generation stage
- `col_gen_iter_output`: the last column generation iteration output
- `iter`: the last iteration number
- `inc_dual_bound`: the current incumbent dual bound
"""
@mustimplement "ColGenPhaseOutput" new_phase_output(::Type{<:AbstractColGenPhaseOutput}, min_sense, phase, stage, ::AbstractColGenIterationOutput, iteration, incumbent_dual_bound) = nothing

"Returns `true` when the column generation algorithm must stop; `false` otherwise."
@mustimplement "ColGenPhaseOutput" stop_colgen(context, phase_output) = nothing

############################################################################################
# Colgen Output
############################################################################################
"Supertype for the objects that contains the output of the column generation algorithm."
abstract type AbstractColGenOutput end

"""
    colgen_output_type(ctx) -> Type{<:AbstractColGenOutput}

Returns the type of the column generation output associated to the context.
"""
@mustimplement "ColGenOutput" colgen_output_type(::AbstractColGenContext) = nothing

"""
    new_output(OutputType, colgen_phase_output) -> OutputType

Returns the column generation output where `colgen_phase_output` is the output of the last
column generation phase executed.
"""
@mustimplement "ColGenOutput" new_output(::Type{<:AbstractColGenOutput}, colgen_phase_output::AbstractColGenPhaseOutput) = nothing

############################################################################################
# Common to outputs
############################################################################################

"Returns the number of new columns inserted into the master at the end of an iteration."
@mustimplement "ColGenOutputs" get_nb_new_cols(output) = nothing

"Returns the incumbent primal master IP solution at the end of an iteration or a phase."
@mustimplement "ColGenOutputs" get_master_ip_primal_sol(output) = nothing

"Returns the primal master LP solution found at the last iteration of the column generation algorithm."
@mustimplement "ColGenOutputs" get_master_lp_primal_sol(output) = nothing

"Returns the dual master LP solution found at the last iteration of the column generation algorithm."
@mustimplement "ColGenOutputs" get_master_dual_sol(output) = nothing

"Returns the master LP solution value at the last iteration of the column generation algorithm."
@mustimplement "ColGenOutputs" get_master_lp_primal_bound(output) = nothing


############################################################################################
# ColGen Main Loop
############################################################################################

"""
Placeholder method called before the column generation iteration.
Does nothing by default but can be redefined to print some informations for instance.
We strongly advise users against the use of this method to modify the context or the reformulation.
"""
@mustimplement "ColGen" before_colgen_iteration(ctx::AbstractColGenContext, phase) = nothing

"""
Placeholder method called after the column generation iteration.
Does nothing by default but can be redefined to print some informations for instance.
We strongly advise users against the use of this method to modify the context or the reformulation.
"""
@mustimplement "ColGen" after_colgen_iteration(::AbstractColGenContext, phase, stage, env, colgen_iteration, stab, colgen_iter_output) = nothing

"Returns `true` if `new_dual_bound` is better than `dual_bound`; `false` otherwise."
@mustimplement "ColGen" is_better_dual_bound(context, new_dual_bound, dual_bound) = nothing

###
_inf(is_min_sense) = is_min_sense ? Inf : -Inf


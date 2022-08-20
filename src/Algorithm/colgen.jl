"""
    Coluna.Algorithm.ColumnGeneration(
        restr_master_solve_alg = SolveLpForm(get_dual_solution = true),
        pricing_prob_solve_alg = SolveIpForm(
            moi_params = MoiOptimize(
                deactivate_artificial_vars = false,
                enforce_integrality = false
            )
        ),
        essential_cut_gen_alg = CutCallbacks(call_robust_facultative = false),
        max_nb_iterations = 1000,
        log_print_frequency = 1,
        redcost_tol = 1e-5,
        cleanup_threshold = 10000,
        cleanup_ratio = 0.66,
        smoothing_stabilization = 0.0 # should be in [0, 1],
    )

Column generation algorithm that can be applied to formulation reformulated using
Dantzig-Wolfe decomposition. 

This algorithm first solves the linear relaxation of the master (master LP) using `restr_master_solve_alg`.
Then, it solves the subproblems by calling `pricing_prob_solve_alg` to get the columns that
have the best reduced costs and that hence, may improve the master LP's objective the most.

In order for the algorithm to converge towards the optimal solution of the master LP,
it suffices that the pricing oracle returns, at each iteration, a negative reduced cost solution if one exists. 
The algorithm stops when all subproblems fail to generate a column with negative
(positive) reduced cost in the case of a minimization (maximization) problem or when it
reaches the maximum number of iterations.

Parameters : 
- `restr_master_solve_alg`: algorithm to optimize the master LP
- `pricing_prob_solve_alg`: algorithm to optimize the subproblems
- `essential_cut_gen_alg`: algorithm to generate essential cuts which is run when the solution of the master LP is integer.

Options:
- `max_nb_iterations`: maximum number of iterations
- `log_print_frequency`: display frequency of iterations statistics

Undocumented parameters are in alpha version.

## About the ouput

At each iteration (depending on `log_print_frequency`), 
the column generation algorithm can display following statistics.

    <it= 90> <et=15.62> <mst= 0.02> <sp= 0.05> <cols= 4> <al= 0.00> <DB=  300.2921> <mlp=  310.3000> <PB=310.3000>

Here are their meanings :
- `it` stands for the current number of iterations of the algorithm
- `et` is the elapsed time in seconds since Coluna has started the optimisation
- `mst` is the time in seconds spent solving the master LP at the current iteration
- `sp` is the time in seconds spent solving the subproblems at the current iteration
- `cols` is the number of column generated by the subproblems at the current iteration
- `al` is the smoothing factor of the stabilisation at the current iteration (alpha version)
- `DB` is the dual bound of the master LP at the current iteration
- `mlp` is the objective value of the master LP at the current iteration
- `PB` is the objective value of the best primal solution found by Coluna at the current iteration
"""
@with_kw struct ColumnGeneration <: AbstractOptimizationAlgorithm
    restr_master_solve_alg = SolveLpForm(get_dual_solution=true)
    restr_master_optimizer_id = 1
    # TODO : pricing problem solver may be different depending on the
    #       pricing subproblem
    pricing_prob_solve_alg = SolveIpForm(
        moi_params = MoiOptimize(
            deactivate_artificial_vars = false,
            enforce_integrality = false
        )
    )
    essential_cut_gen_alg = CutCallbacks(call_robust_facultative=false)
    max_nb_iterations::Int64 = 1000
    log_print_frequency::Int64 = 1
    store_all_ip_primal_sols::Bool = false
    redcost_tol::Float64 = 1e-5
    solve_subproblems_parallel::Bool = false
    cleanup_threshold::Int64 = 10000
    cleanup_ratio::Float64 = 0.66
    smoothing_stabilization::Float64 = 0.0 # should be in [0, 1]
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL
end

stabilization_is_used(algo::ColumnGeneration) = !iszero(algo.smoothing_stabilization)

############################################################################################
# Errors and warnings
############################################################################################

"""
Error thrown when when a subproblem generates a column with negative (resp. positive) 
reduced cost in min (resp. max) problem that already exists in the master 
and that is already active. 
An active master column cannot have a negative reduced cost.
"""
struct ColumnAlreadyInsertedColGenError
    column_in_master::Bool
    column_is_active::Bool
    column_reduced_cost::Float64
    column_id::VarId
    master::Formulation{DwMaster}
    subproblem::Formulation{DwSp}
end

function Base.show(io::IO, err::ColumnAlreadyInsertedColGenError)
    msg = """
    Unexpected variable state during column insertion.
    ======
    Column id: $(err.column_id).
    Reduced cost of the column: $(err.column_reduced_cost).
    The column is in the master ? $(err.column_in_master).
    The column is active ? $(err.column_is_active).
    ======
    If the column is in the master and active, it means a subproblem found a solution with
    negative (minimization) / positive (maximization) reduced cost that is already active in
    the master. This should not happen.
    ======
    If you are using a pricing callback, make sure there is no bug in your code.
    If you are using a solver (e.g. GLPK, Gurobi...), please open an issue at https://github.com/atoptima/Coluna.jl/issues
    with an example that reproduces the bug.
    ======
    """
    println(io, msg)
end


function get_child_algorithms(algo::ColumnGeneration, reform::Reformulation) 
    child_algs = Tuple{AbstractAlgorithm,AbstractModel}[]
    push!(child_algs, (algo.restr_master_solve_alg, getmaster(reform)))
    push!(child_algs, (algo.essential_cut_gen_alg, getmaster(reform)))
    for (id, spform) in get_dw_pricing_sps(reform)
        push!(child_algs, (algo.pricing_prob_solve_alg, spform))
    end
    return child_algs
end

function get_units_usage(algo::ColumnGeneration, reform::Reformulation) 
    units_usage = Tuple{AbstractModel,UnitType,UnitPermission}[] 
    master = getmaster(reform)
    push!(units_usage, (master, MasterColumnsUnit, READ_AND_WRITE))
    push!(units_usage, (master, PartialSolutionUnit, READ_ONLY))
    if stabilization_is_used(algo)
        push!(units_usage, (master, ColGenStabilizationUnit, READ_AND_WRITE))
    end
    return units_usage
end

struct ReducedCostsCalculationHelper
    length::Int
    dwspvarids::Vector{VarId}
    perencosts::Vector{Float64}
    dwsprep_coefmatrix::DynamicSparseArrays.Transposed{DynamicSparseArrays.DynamicSparseMatrix{Coluna.MathProg.ConstrId, Coluna.MathProg.VarId, Float64}}
end

# Precompute information to speed-up calculation of reduced costs of original variables
# in the master of a given reformulation.
function ReducedCostsCalculationHelper(reform::Reformulation)
    dwspvarids = VarId[]
    perencosts = Float64[]

    master = getmaster(reform)
    for (varid, _) in getvars(master)
        if iscuractive(master, varid) && getduty(varid) <= AbstractMasterRepDwSpVar
            push!(dwspvarids, varid)
            push!(perencosts, getcurcost(master, varid))
        end
    end

    master_coefmatrix = getcoefmatrix(master)
    dwsprep_coefmatrix = dynamicsparse(ConstrId, VarId, Float64)
    for (constrid, _) in getconstrs(master)
        for (varid, coeff) in @view master_coefmatrix[constrid, :]
            if getduty(varid) <= AbstractMasterRepDwSpVar
                dwsprep_coefmatrix[constrid, varid] = coeff
            end
        end
    end
    closefillmode!(dwsprep_coefmatrix)
    return ReducedCostsCalculationHelper(
        length(dwspvarids), dwspvarids, perencosts, transpose(dwsprep_coefmatrix)
    )
end

function run!(algo::ColumnGeneration, env::Env, reform::Reformulation, input::OptimizationState)
    master = getmaster(reform)
    optstate = OptimizationState(master, input, false, false)

    stop = false

    set_ph3!(master) # mixed ph1 & ph2
    stop, _ = cg_main_loop!(algo, env, 3, optstate, reform)

    restart = true
    while should_do_ph_1(optstate) && restart && !stop
        set_ph1!(master, optstate)
        stop, _ = cg_main_loop!(algo, env, 1, optstate, reform)
        if !stop
            set_ph2!(master, optstate) # pure ph2
            stop, restart = cg_main_loop!(algo, env, 2, optstate, reform)
        end
    end

    @logmsg LogLevel(-1) string("ColumnGeneration terminated with status ", getterminationstatus(optstate))

    return optstate
end

function should_do_ph_1(optstate::OptimizationState)
    primal_lp_sol = get_lp_primal_sols(optstate)[1]
    if contains(primal_lp_sol, vid -> isanArtificialDuty(getduty(vid)))
        @logmsg LogLevel(-2) "Artificial variables in lp solution, need to do phase one"
        return true
    end

    @logmsg LogLevel(-2) "No artificial variables in lp solution, will not proceed to do phase one"
    return false
end

function set_ph1!(master::Formulation, optstate::OptimizationState)
    for (varid, _) in getvars(master)
        if !isanArtificialDuty(getduty(varid))
            setcurcost!(master, varid, 0.0)
        end
    end
    set_lp_dual_bound!(optstate, DualBound(master))
    set_ip_dual_bound!(optstate, DualBound(master))
    return
end

function set_ph2!(master::Formulation, optstate::OptimizationState)
    for (varid, var) in getvars(master)
        if isanArtificialDuty(getduty(varid))
            deactivate!(master, varid)
        else
            setcurcost!(master, varid, getperencost(master, var))
        end
    end
    set_lp_dual_bound!(optstate, DualBound(master))
    set_ip_dual_bound!(optstate, DualBound(master))
    set_lp_primal_bound!(optstate, PrimalBound(master))
    return
end

function set_ph3!(master::Formulation)
    for (varid, var) in getvars(master)
        if isanArtificialDuty(getduty(varid))
            activate!(master, varid)
        else
            setcurcost!(master, varid, getperencost(master, var))
        end
    end
    return
end

mutable struct SubprobInfo
    lb_constr_id::ConstrId
    ub_constr_id::ConstrId
    lb::Float64
    ub::Float64
    lb_dual::Float64
    ub_dual::Float64
    bestsol::Union{Nothing,PrimalSolution}
    valid_dual_bound_contrib::Float64
    pseudo_dual_bound_contrib::Float64
    isfeasible::Bool
end

function SubprobInfo(reform::Reformulation, spformid::FormId)
    master = getmaster(reform)
    lb_constr_id = get_dw_pricing_sp_lb_constrid(reform, spformid)
    ub_constr_id = get_dw_pricing_sp_ub_constrid(reform, spformid)
    lb = getcurrhs(master, lb_constr_id)
    ub = getcurrhs(master, ub_constr_id)
    return SubprobInfo(
        lb_constr_id, ub_constr_id, lb, ub, 0.0, 0.0, nothing, 0.0, 0.0, true
    )
end

function clear_before_colgen_iteration!(spinfo::SubprobInfo)
    spinfo.lb_dual = 0.0
    spinfo.ub_dual = 0.0
    spinfo.bestsol = nothing
    spinfo.valid_dual_bound_contrib = 0.0
    spinfo.pseudo_dual_bound_contrib = 0.0
    return
end

set_bestcol_id!(spinfo::SubprobInfo, varid::VarId) = spinfo.bestcol_id = varid

function compute_db_contributions!(
    spinfo::SubprobInfo, dualbound::DualBound{MaxSense}, primalbound::PrimalBound{MaxSense}
)
    value = getvalue(dualbound)
    spinfo.valid_dual_bound_contrib = value <= 0 ? value * spinfo.lb : value * spinfo.ub
    value = getvalue(primalbound)
    spinfo.pseudo_dual_bound_contrib = value <= 0 ? value * spinfo.lb : value * spinfo.ub
    return
end

function compute_db_contributions!(
    spinfo::SubprobInfo, dualbound::DualBound{MinSense}, primalbound::PrimalBound{MinSense}
)
    value = getvalue(dualbound)
    spinfo.valid_dual_bound_contrib = value >= 0 ? value * spinfo.lb : value * spinfo.ub
    value = getvalue(primalbound)
    spinfo.pseudo_dual_bound_contrib = value >= 0 ? value * spinfo.lb : value * spinfo.ub
    return
end

function compute_reduced_cost(
    stab_is_used, masterform::Formulation, spinfo::SubprobInfo,
    spsol::PrimalSolution, lp_dual_sol::DualSolution
)
    red_cost::Float64 = 0.0
    if stab_is_used
        master_coef_matrix = getcoefmatrix(masterform)
        for (varid, value) in spsol
            red_cost += getcurcost(masterform, varid) * value
            for (constrid, var_coeff) in @view master_coef_matrix[:,varid]
                red_cost -= value * var_coeff * lp_dual_sol[constrid]
            end
        end
    else
        red_cost = getvalue(spsol)
    end
    red_cost -= spinfo.lb_dual + spinfo.ub_dual
    return red_cost
end

function reduced_costs_of_solutions(
    stab_is_used, masterform::Formulation, spinfo::SubprobInfo,
    sp_optstate::OptimizationState, dualsol::DualSolution
)
    red_costs = Float64[]
    for sol in get_ip_primal_sols(sp_optstate)
        push!(red_costs, compute_reduced_cost(stab_is_used, masterform, spinfo, sol, dualsol))
    end
    return red_costs
end

function improving_red_cost(redcost::Float64, algo::ColumnGeneration, ::Type{MinSense})
    return redcost < 0.0 - algo.redcost_tol
end

function improving_red_cost(redcost::Float64, algo::ColumnGeneration, ::Type{MaxSense})
    return redcost > 0.0 + algo.redcost_tol
end

# Optimises the subproblem and returns the result (OptimizationState).
function _optimize_sp(spform, pricing_prob_solve_alg, env)
    input = OptimizationState(spform)
    output = run!(pricing_prob_solve_alg, env, spform, input)
    return output
end

# Subproblem optimisation can be run sequentially or in parallel.
# In both cases, it returns all results (OptimizationState) in a vector.
function _optimize_sps_in_parallel(spforms, pricing_prob_solve_alg, env)
    sp_optstates = Vector{OptimizationState}(undef, length(spforms))
    spuids = collect(keys(spforms))
    Threads.@threads for i in 1:length(spforms)
        spform = spsforms[spuids[i]]
        sp_optstates[i] = _optimize_sp(spform, pricing_prob_solve_alg, env)
    end
    return sp_optstates
end

function _optimize_sps(spforms, pricing_prob_solve_alg, env)
    sp_optstates = OptimizationState[]
    for (_, spform) in spforms
        push!(sp_optstates, _optimize_sp(spform, pricing_prob_solve_alg, env))
    end
    return sp_optstates
end

function insert_columns!(
    masterform::Formulation, sp_optstate::OptimizationState, redcosts_spsols::Vector{Float64},
    algo::ColumnGeneration, phase::Int
)
    nb_cols_generated = 0

    # Insert the primal solutions to the DW subproblem as column into the master
    bestsol = get_best_ip_primal_sol(sp_optstate)
    if !isnothing(bestsol) && getstatus(bestsol) == FEASIBLE_SOL

        # First we activate columns that are already in the pool.
        primal_sols_to_insert = PrimalSolution{Formulation{DwSp}}[]
        sols = get_ip_primal_sols(sp_optstate)
        for (sol, red_cost) in Iterators.zip(sols, redcosts_spsols)
            if improving_red_cost(red_cost, algo, getobjsense(masterform))
                col_id = get_column_from_pool(sol)
                if !isnothing(col_id)
                    if haskey(masterform, col_id) && !iscuractive(masterform, col_id)
                        activate!(masterform, col_id)
                        if phase == 1
                            setcurcost!(masterform, col_id, 0.0)
                        end
                        nb_cols_generated += 1
                    else
                        in_master = haskey(masterform, col_id)
                        is_active = iscuractive(masterform, col_id)
                        throw(ColumnAlreadyInsertedColGenError(
                            in_master, is_active, red_cost, col_id, masterform, sol.solution.model
                        ))
                    end
                else
                    push!(primal_sols_to_insert, sol)
                end
            end
        end

        # Then, we add the new columns (i.e. not in the pool).
        for sol in primal_sols_to_insert
            col_id = insert_column!(masterform, sol, "MC")
            if phase == 1
                setcurcost!(masterform, col_id, 0.0)
            end
            nb_cols_generated += 1
        end
        return nb_cols_generated
    end
    return -1
end

# this method must be redefined if subproblem is a custom model
function updatemodel!(
    form::Formulation, repr_vars_red_costs::Dict{VarId, Float64}, ::DualSolution
)
    for (varid, _) in getvars(form)
        setcurcost!(form, varid, get(repr_vars_red_costs, varid, 0.0))
    end
    return
end

function updatereducedcosts!(
    reform::Reformulation, redcostshelper::ReducedCostsCalculationHelper, masterdualsol::DualSolution
)
    redcosts = Dict{VarId,Float64}()
    result = redcostshelper.dwsprep_coefmatrix * masterdualsol.solution.sol
    for (i, varid) in enumerate(redcostshelper.dwspvarids)
        redcosts[varid] = redcostshelper.perencosts[i] - get(result, varid, 0.0)
    end
    for (_, spform) in get_dw_pricing_sps(reform)
        updatemodel!(spform, redcosts, masterdualsol)
    end
    return
end

function solve_sps_to_gencols!(
    spinfos::Dict{FormId,SubprobInfo}, algo::ColumnGeneration, env::Env, phase::Int64, 
    reform::Reformulation, redcostshelper::ReducedCostsCalculationHelper, lp_dual_sol::DualSolution, 
    smooth_dual_sol::DualSolution,
)
    masterform = getmaster(reform)
    spsforms = get_dw_pricing_sps(reform)

    # update reduced costs
    TO.@timeit Coluna._to "Update reduced costs" begin
        updatereducedcosts!(reform, redcostshelper, smooth_dual_sol)
    end

    # update the incumbent values of constraints
    for (_, constr) in getconstrs(masterform)
        setcurincval!(masterform, constr, 0.0)
    end
    for (constrid, val) in smooth_dual_sol
        setcurincval!(masterform, constrid, val)
    end

    sp_optstates = if algo.solve_subproblems_parallel
        _optimize_sps_in_parallel(spsforms, algo.pricing_prob_solve_alg, env)
    else
        _optimize_sps(spsforms, algo.pricing_prob_solve_alg, env)
    end

    nb_new_cols = 0
    for sp_optstate in sp_optstates
        # TODO: refactor
        get_best_ip_primal_sol(sp_optstate) === nothing && continue
        spuid = getuid(get_best_ip_primal_sol(sp_optstate).solution.model)
        spinfo = spinfos[spuid]
        # end

        compute_db_contributions!(
            spinfo, get_ip_dual_bound(sp_optstate), get_ip_primal_bound(sp_optstate)
        )

        redcosts_spsols = reduced_costs_of_solutions(
            stabilization_is_used(algo), masterform, spinfo, sp_optstate,
            lp_dual_sol
        )

        bestsol = get_best_ip_primal_sol(sp_optstate)
        if isnothing(bestsol) && algo.smoothing_stabilization == 1 && !iszero(spinfo.ub)
            msg = string(
                "To use automatic dual price smoothing, solutions to all pricing ",
                "subproblems must be available."
            )
            error(msg)
        end

        # Columns will be inserted only if the 
        nb_cols_sp = insert_columns!(
            masterform, sp_optstate, redcosts_spsols, algo, phase
        )

        if nb_cols_sp >= 0
            spinfo.bestsol = bestsol
        else
            # If a subproblem is infeasible, then the original formulation is
            # infeasible. Therefore we can stop the column generation.
            return -1
        end
        nb_new_cols += nb_cols_sp
    end

    return nb_new_cols
end

can_be_in_basis(algo::ColumnGeneration, ::Type{MinSense}, redcost::Float64) =
    redcost < 0 + algo.redcost_tol

can_be_in_basis(algo::ColumnGeneration, ::Type{MaxSense}, redcost::Float64) =
    redcost > 0 - algo.redcost_tol

function cleanup_columns(algo::ColumnGeneration, iteration::Int64, master::Formulation)

    # we do columns clean up only on every 10th iteration in order not to spend
    # the time retrieving the reduced costs
    # TO DO : master cleanup should be done on every iteration, for this we need
    # to quickly check the number of active master columns
    iteration % 10 != 0 && return

    cols_with_redcost = Vector{Pair{Variable,Float64}}()
    optimizer = getoptimizer(master, algo.restr_master_optimizer_id)
    for (id, var) in getvars(master)
        if getduty(id) <= MasterCol && iscuractive(master, var) && isexplicit(master, var)
            push!(cols_with_redcost, var => getreducedcost(master, optimizer, var))
        end
    end

    num_active_cols = length(cols_with_redcost)
    num_active_cols < algo.cleanup_threshold && return

    # sort active master columns by reduced cost
    reverse_order = getobjsense(master) == MinSense ? true : false
    sort!(cols_with_redcost, by=x -> x.second, rev=reverse_order)

    num_cols_to_keep = floor(Int64, num_active_cols * algo.cleanup_ratio)

    resize!(cols_with_redcost, num_active_cols - num_cols_to_keep)

    num_cols_removed::Int64 = 0
    for (var, redcost) in cols_with_redcost
        # we can remove column only if we are sure is it not in the basis
        # TO DO : we need to get the basis from the LP solver to have this verification
        if !can_be_in_basis(algo, getobjsense(master), redcost)
            deactivate!(master, var)
            num_cols_removed += 1
        end
    end
    @logmsg LogLevel(-1) "Cleaned up $num_cols_removed master columns"
    return
end

ph_one_infeasible_db(algo, db::DualBound{MinSense}) = getvalue(db) > algo.opt_atol
ph_one_infeasible_db(algo, db::DualBound{MaxSense}) = getvalue(db) < - algo.opt_atol

function update_lagrangian_dual_bound!(
    stabunit::ColGenStabilizationUnit, optstate::OptimizationState{F,S}, algo::ColumnGeneration,
    master::Formulation, puremastervars::Vector{Pair{VarId,Float64}}, dualsol::DualSolution,
    partialsol::PrimalSolution, spinfos::Dict{FormId,SubprobInfo}
) where {F,S}

    sense = getobjsense(master)

    puremastvars_contrib::Float64 = getvalue(partialsol)
    # if smoothing is not active the pure master variables contribution
    # is already included in the value of the dual solution
    if smoothing_is_active(stabunit)
        master_coef_matrix = getcoefmatrix(master)
        for (varid, mult) in puremastervars
            redcost = getcurcost(master, varid)
            for (constrid, var_coeff) in @view master_coef_matrix[:,varid]
                redcost -= var_coeff * dualsol[constrid]
            end
            mult = improving_red_cost(redcost, algo, sense) ?
                getcurub(master, varid) : getcurlb(master, varid)
            puremastvars_contrib += redcost * mult
        end
    end
    
    valid_lagr_bound = DualBound{S}(puremastvars_contrib + getbound(dualsol))
    for (spuid, spinfo) in spinfos
        valid_lagr_bound += spinfo.valid_dual_bound_contrib
    end

    update_ip_dual_bound!(optstate, valid_lagr_bound)
    update_lp_dual_bound!(optstate, valid_lagr_bound)

    if stabilization_is_used(algo)
        pseudo_lagr_bound = DualBound{S}(puremastvars_contrib + getbound(dualsol))
        for (spuid, spinfo) in spinfos
            pseudo_lagr_bound += spinfo.pseudo_dual_bound_contrib
        end
        update_stability_center!(stabunit, dualsol, valid_lagr_bound, pseudo_lagr_bound)
    end
    return
end

function compute_subgradient_contribution(
    algo::ColumnGeneration, stabunit::ColGenStabilizationUnit, master::Formulation,
    puremastervars::Vector{Pair{VarId,Float64}}, spinfos::Dict{FormId,SubprobInfo}
)
    sense = getobjsense(master)
    constrids = ConstrId[]
    constrvals = Float64[]

    if subgradient_is_needed(stabunit, algo.smoothing_stabilization)
        master_coef_matrix = getcoefmatrix(master)

        for (varid, mult) in puremastervars
            for (constrid, var_coeff) in @view master_coef_matrix[:,varid]
                push!(constrids, constrid)
                push!(constrvals, var_coeff * mult)
            end
        end

        for (_, spinfo) in spinfos
            iszero(spinfo.ub) && continue
            mult = improving_red_cost(getbound(spinfo.bestsol), algo, sense) ? spinfo.ub : spinfo.lb
            for (sp_var_id, sp_var_val) in spinfo.bestsol
                for (master_constrid, sp_var_coef) in @view master_coef_matrix[:,sp_var_id]
                    if !(getduty(master_constrid) <= MasterConvexityConstr)
                        push!(constrids, master_constrid)
                        push!(constrvals, sp_var_coef * sp_var_val * mult)
                    end
                end
            end
        end
    end

    return DualSolution(
        master, constrids, constrvals, VarId[], Float64[], ActiveBound[], 0.0, 
        UNKNOWN_SOLUTION_STATUS
    )
end

function move_convexity_constrs_dual_values!(
    spinfos::Dict{FormId,SubprobInfo}, dualsol::DualSolution
)
    newbound = getbound(dualsol)
    for (spuid, spinfo) in spinfos
        spinfo.lb_dual = dualsol[spinfo.lb_constr_id]
        spinfo.ub_dual = dualsol[spinfo.ub_constr_id]
        newbound -= (spinfo.lb_dual * spinfo.lb + spinfo.ub_dual * spinfo.ub)
    end
    constrids = Vector{ConstrId}()
    values = Vector{Float64}()
    for (constrid, value) in dualsol
        if !(getduty(constrid) <= MasterConvexityConstr)
            push!(constrids, constrid)
            push!(values, value)
        end
    end
    return DualSolution(
        getmodel(dualsol), constrids, values, VarId[], Float64[], ActiveBound[], newbound, 
        FEASIBLE_SOL
    )
end

function get_pure_master_vars(master::Formulation)
    puremastervars = Vector{Pair{VarId,Float64}}()
    for (varid, var) in getvars(master)
        if isanOriginalRepresentatives(getduty(varid)) &&
            iscuractive(master, var) && isexplicit(master, var)
            push!(puremastervars, varid => 0.0)
        end
    end
    return puremastervars
end

function change_values_sign!(dualsol::DualSolution)
    # note that the bound value remains the same
    for (constrid, value) in dualsol
        dualsol[constrid] = -value
    end
    return
end

# cg_main_loop! returns Tuple{Bool, Bool} :
# - first one is equal to true when colgen algorithm must stop.
# - second one is equal to true when colgen algorithm must restart;
#   if column generation stops at phase 3, it will restart at phase 3;
#   if column generation stops as phase 1 or 2, it will restart at phase 1.
function cg_main_loop!(
    algo::ColumnGeneration, env::Env, phase::Int, cg_optstate::OptimizationState, 
    reform::Reformulation
)
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    masterform = getmaster(reform)
    spinfos = Dict{FormId,SubprobInfo}()

    # collect multiplicity current bounds for each sp
    pure_master_vars = get_pure_master_vars(masterform)

    for (spid, spform) in get_dw_pricing_sps(reform)
        spinfos[spid] = SubprobInfo(reform, spid)
    end

    redcostshelper = ReducedCostsCalculationHelper(reform)
    iteration = 0
    essential_cuts_separated = false

    stabunit = if stabilization_is_used(algo)
        getstorageunit(masterform, ColGenStabilizationUnit)
    else
        #ColGenStabilizationUnit(masterform)
        ClB.new_storage_unit(ColGenStabilizationUnit, masterform)
    end

    partsolunit = getstorageunit(masterform, PartialSolutionUnit)
    partial_solution = get_primal_solution(partsolunit, masterform)

    init_stab_before_colgen_loop!(stabunit)

    while true
        for (_, spinfo) in spinfos
            clear_before_colgen_iteration!(spinfo)
        end

        rm_time = @elapsed begin
            rm_input = OptimizationState(masterform, ip_primal_bound=get_ip_primal_bound(cg_optstate))
            rm_optstate = run!(algo.restr_master_solve_alg, env, masterform, rm_input, algo.restr_master_optimizer_id)
        end

        if phase != 1 && getterminationstatus(rm_optstate) == INFEASIBLE
            @warn string("Solver returned that LP restricted master is infeasible or unbounded ",
            "(termination status = INFEASIBLE) during phase != 1.")
            setterminationstatus!(cg_optstate, INFEASIBLE)
            return true, false
        end

        lp_dual_sol = get_best_lp_dual_sol(rm_optstate)
        if lp_dual_sol === nothing
            err_msg = """
            Something unexpected happened when retrieving the dual solution to the LP restricted master.
            ======
            Phase : $phase
            Termination status of the solver after optimizing the master (should be OPTIMAL) : $(getterminationstatus(rm_optstate))
            Number of dual solutions (should be at least 1) : $(length(get_lp_dual_sols(rm_optstate)))
            ======
            Please open an issue at https://github.com/atoptima/Coluna.jl/issues with an example that reproduces the bug.
            """
            error(err_msg)
        end
        if getobjsense(masterform) == MaxSense
            # this is needed due to convention that MOI uses for signs of duals in the maximization case
            change_values_sign!(lp_dual_sol)
        end
        if lp_dual_sol !== nothing
            set_lp_dual_sol!(cg_optstate, lp_dual_sol)
        end
        lp_dual_sol = move_convexity_constrs_dual_values!(spinfos, lp_dual_sol)

        TO.@timeit Coluna._to "Getting primal solution" begin
        rm_sol = get_best_lp_primal_sol(rm_optstate)
        if rm_sol !== nothing
            set_lp_primal_sol!(cg_optstate, rm_sol)
            lp_bound = get_lp_primal_bound(rm_optstate) + getvalue(partial_solution)
            set_lp_primal_bound!(cg_optstate, lp_bound)

            dual_rm_sol = get_best_lp_dual_sol(rm_optstate)
            if dual_rm_sol !== nothing
                set_lp_dual_sol!(cg_optstate, dual_rm_sol)
            end

            if phase != 1 && !contains(rm_sol, varid -> isanArtificialDuty(getduty(varid)))
                proj_sol = proj_cols_on_rep(rm_sol, masterform)
                if isinteger(proj_sol) && isbetter(lp_bound, get_ip_primal_bound(cg_optstate))
                    # Essential cut generation mandatory when colgen finds a feasible solution
                    new_primal_sol = cat(rm_sol, partial_solution)
                    cutcb_input = CutCallbacksInput(new_primal_sol)
                    cutcb_output = run!(
                        algo.essential_cut_gen_alg, env, masterform, cutcb_input
                    )
                    if cutcb_output.nb_cuts_added == 0
                        update_ip_primal_sol!(cg_optstate, new_primal_sol)
                    else
                        essential_cuts_separated = true
                        if phase == 2 # because the new cuts may make the master infeasible
                            return false, true
                        end
                        redcostshelper = ReducedCostsCalculationHelper(reform)
                    end
                end
            end
        else
            @error string("Solver returned that the LP restricted master is feasible but ",
            "did not return a primal solution. ",
            "Please open an issue (https://github.com/atoptima/Coluna.jl/issues).")
        end
        end # @timeit

        TO.@timeit Coluna._to "Cleanup columns" begin
            cleanup_columns(algo, iteration, masterform)
        end

        iteration += 1

        TO.@timeit Coluna._to "Smoothing update" begin
            smooth_dual_sol = update_stab_after_rm_solve!(stabunit, algo.smoothing_stabilization, lp_dual_sol)
        end

        nb_new_columns = 0
        sp_time = 0
        while true
            sp_time += @elapsed begin
                nb_new_col = solve_sps_to_gencols!(
                    spinfos, algo, env, phase, reform, redcostshelper, lp_dual_sol, 
                    smooth_dual_sol
                )
            end

            if nb_new_col < 0
                @error "Infeasible subproblem."
                setterminationstatus!(cg_optstate, INFEASIBLE)
                return true, false
            end

            nb_new_columns += nb_new_col

            TO.@timeit Coluna._to "Update Lagrangian bound" begin
                update_lagrangian_dual_bound!(
                    stabunit, cg_optstate, algo, masterform, pure_master_vars, 
                    smooth_dual_sol, partial_solution, spinfos
                )
            end

            if stabilization_is_used(algo)
                TO.@timeit Coluna._to "Smoothing update" begin
                    smooth_dual_sol = update_stab_after_gencols!(
                        stabunit, algo.smoothing_stabilization, nb_new_col, lp_dual_sol, smooth_dual_sol,
                        compute_subgradient_contribution(algo, stabunit, masterform, pure_master_vars, spinfos)
                    )
                end
                smooth_dual_sol === nothing && break
            else
                break
            end
        end

        print_colgen_statistics(
            env, phase, iteration, stabunit.curalpha, cg_optstate, nb_new_columns, 
            rm_time, sp_time
        )

        update_stab_after_colgen_iteration!(stabunit)

        dual_bound = get_ip_dual_bound(cg_optstate)

        if ip_gap_closed(cg_optstate, atol=algo.opt_atol, rtol=algo.opt_rtol)
            setterminationstatus!(cg_optstate, OPTIMAL)
            @logmsg LogLevel(0) "Dual bound reached primal bound."
            return true, false
        end
        if phase == 1 && ph_one_infeasible_db(algo, dual_bound)
            db = - getvalue(DualBound(reform))
            pb = - getvalue(PrimalBound(reform))
            set_lp_dual_bound!(cg_optstate, DualBound(reform, db))
            set_lp_primal_bound!(cg_optstate, PrimalBound(reform, pb))
            setterminationstatus!(cg_optstate, INFEASIBLE)
            @logmsg LogLevel(0) "Phase one determines infeasibility."
            return true, false
        end
        if lp_gap_closed(cg_optstate, atol=algo.opt_atol, rtol=algo.opt_rtol) && !essential_cuts_separated
            @logmsg LogLevel(0) "Column generation algorithm has converged."
            setterminationstatus!(cg_optstate, OPTIMAL)
            set_lp_dual_sol!(cg_optstate, get_best_lp_dual_sol(cg_optstate))
            return false, false
        end
        if nb_new_columns == 0 && !essential_cuts_separated
            @logmsg LogLevel(0) "No new column generated by the pricing problems."
            setterminationstatus!(cg_optstate, OTHER_LIMIT)
            # If no columns are generated and lp gap is not closed then this col.gen. stage
            # is a heuristic one, so we do not run phase 1 to save time
            # Comment by @guimarqu : It may also be a bug
            return true, false
        end
        if iteration > algo.max_nb_iterations
            setterminationstatus!(cg_optstate, OTHER_LIMIT)
            @warn "Maximum number of column generation iteration is reached."
            return true, false
        end
        essential_cuts_separated = false
    end
    return false, false
end

function print_colgen_statistics(
    env::Env, phase::Int64, iteration::Int64, smoothalpha::Float64, 
    optstate::OptimizationState, nb_new_col::Int, mst_time::Float64, sp_time::Float64
)
    mlp = getvalue(get_lp_primal_bound(optstate))
    db = getvalue(get_lp_dual_bound(optstate))
    pb = getvalue(get_ip_primal_bound(optstate))
    phase_string = "  "
    if phase == 1
        phase_string = "# "
    elseif phase == 2
        phase_string = "##"
    end

    @printf(
        "%s<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cols=%2i> <al=%5.2f> <DB=%10.4f> <mlp=%10.4f> <PB=%.4f>\n",
        phase_string, iteration, elapsed_optim_time(env), mst_time, sp_time, nb_new_col, smoothalpha, db, mlp, pb
    )
    return
end

Base.@kwdef struct ColumnGeneration <: AbstractAlgorithm
    max_nb_iterations::Int = 1000
    optimality_tol::Float64 = 1e-5
end

# Data stored while algorithm is running
mutable struct ColGenRuntimeData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    params::ColumnGeneration
end

function ColGenRuntimeData(
    algparams::ColumnGeneration, form::Reformulation, node::Node
)
    inc = Incumbents(form.master.obj_sense)
    update_ip_primal_sol!(inc, get_ip_primal_sol(node.incumbents))
    return ColGenRuntimeData(inc, false, true, algparams)
end

# Data needed for another round of column generation
mutable struct ColumnGenerationResult <: AbstractAlgorithmResult
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the algorithm's prepare function
function prepare!(alg::ColumnGeneration, form, node)
    @logmsg LogLevel(-1) "Prepare ColumnGeneration."
    return
end

# Overload of the algorithm's run function
function run!(alg::ColumnGeneration, form::Reformulation, node::Node)
    @logmsg LogLevel(-1) "Run ColumnGeneration."
    algdata = ColGenRuntimeData(alg, form, node)
    result = cg_main_loop(algdata, form, 2)
    if should_do_ph_1(result)
        record!(form, node)
        set_ph_one(form.master)
        result = cg_main_loop(algdata, form, 1)
    end
    if result.proven_infeasible
        result.incumbents = Incumbents(getsense(result.incumbents))
    end
    if result.proven_infeasible
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status INFEASIBLE."
    else
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status FEASIBLE."
    end
    update!(node.incumbents, result.incumbents)
    return result
end

# Internal methods to the column generation
function should_do_ph_1(result::ColumnGenerationResult)
    primal_lp_sol = getsol(get_lp_primal_sol(result.incumbents))
    art_vars = filter(x->(getduty(x) isa ArtificialDuty), primal_lp_sol)
    if !isempty(art_vars)
        @logmsg LogLevel(-2) "Artificial variables in lp solution, need to do phase one"
        return true
    else
        @logmsg LogLevel(-2) "No artificial variables in lp solution, will not proceed to do phase one"
        return false
    end
end

function set_ph_one(master::Formulation)
    for (id, v) in Iterators.filter(x->(!(getduty(x) isa ArtificialDuty)), getvars(master))
        setcurcost!(master, v, 0.0)
    end
    return
end

function update_pricing_problem!(spform::Formulation, dual_sol::DualSolution)
    masterform = getmaster(spform)
    for (var_id, var) in Iterators.filter(_active_pricing_sp_var_ , getvars(spform))
        setcurcost!(spform, var, computereducedcost(masterform, var_id, dual_sol))
    end
    return false
end

function update_pricing_target!(spform::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
end

function record_solutions!(
    spform::Formulation, 
    sols::Vector{PrimalSolution{S}}
)::Vector{VarId} where {S}

    recorded_solution_ids = Vector{VarId}()
    for sol in sols
        if contrib_improves_mlp(getbound(sol))
            (insertion_status, col_id) = setprimalsol!(spform, sol)
            if insertion_status
                push!(recorded_solution_ids, col_id)
            else
                @warn string("column already exists as", col_id)
            end

        end
    end
    
    return recorded_solution_ids
end

function insert_cols_in_master!(
    masterform::Formulation,
    spform::Formulation, 
    solution_ids::Vector{VarId}
) 
    sp_uid = getuid(spform)
    nb_of_gen_col = 0
    for sol_id in solution_ids
        nb_of_gen_col += 1
        spsol = getprimalsolmatrix(spform)[:;sol_id]
        name = string("MC",sol_id) #name = string("MC", sp_uid, "_", ref)
        cost = computesolvalue(masterform, spsol)
        lb = 0.0
        ub = Inf
        kind = Continuous
        duty = MasterCol
        sense = Positive
        mc = setcol_from_sp_primalsol!(
            masterform,
            spform,
            sol_id,
            name,
            duty;
            cost = cost,
            lb = lb,
            ub = ub,
            kind = kind,
            sense = sense
        )
        @logmsg LogLevel(-2) string("Generated column : ", name)
    end
    return nb_of_gen_col
end

contrib_improves_mlp(sp_primal_bound::PrimalBound{MinSense}) = (sp_primal_bound < 0.0 - 1e-8)
contrib_improves_mlp(sp_primal_bound::PrimalBound{MaxSense}) = (sp_primal_bound > 0.0 + 1e-8)

function compute_pricing_db_contrib(
    spform::Formulation, sp_sol_primal_bound::PrimalBound{S}, sp_lb::Float64,
    sp_ub::Float64
) where {S}
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost * multiplicty
    if contrib_improves_mlp(sp_sol_primal_bound)
        contrib = sp_sol_primal_bound * sp_ub
    else
        contrib = sp_sol_primal_bound * sp_lb
    end
    return contrib
end

function solve_sp_to_gencol!(
    masterform::Formulation,
    spform::Formulation,
    dual_sol::DualSolution,
    sp_lb::Float64,
    sp_ub::Float64
)::Tuple{Bool,Vector{VarId},Float64}
    
    recorded_solution_ids = Vector{VarId}()
    sp_is_feasible = true

     #dual_bound_contrib = 0 # Not used
    #pseudo_dual_bound_contrib = 0 # Not used

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_col(princing_prob)
    #     return flag_cannot_generate_more_col
    # end

    # Compute target
    update_pricing_target!(spform)

    # Reset var bounds, var cost, sp minCost
    if update_pricing_problem!(spform, dual_sol) # Never returns true
        #     This code is never executed because update_pricing_prob always returns false
        #     @logmsg LogLevel(-3) "pricing prob is infeasible"
        #     # In case one of the subproblem is infeasible, the master is infeasible
        #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
        #     return flag_is_sp_infeasible
    end

    # if alg.colgen_stabilization != nothing && true #= TODO add conds =#
    #     # switch off the reduced cost estimation when stabilization is applied
    # end

    # Solve sub-problem and insert generated columns in master
    # @logmsg LogLevel(-3) "optimizing pricing prob"
    TO.@timeit _to "Pricing subproblem" begin
        opt_result = optimize!(spform)
    end

    pricing_db_contrib = compute_pricing_db_contrib(
        spform, getprimalbound(opt_result), sp_lb, sp_ub
    )

    if !isfeasible(opt_result)
        sp_is_feasible = false 
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return sp_is_feasible, recorded_solution_ids, defaultprimalboundvalue(getobjsense(spform))
    end

    recorded_solution_ids = record_solutions!(
        spform, getprimalsols(opt_result)
    )

    return sp_is_feasible, recorded_solution_ids, pricing_db_contrib
end

function solve_sps_to_gencols!(
    reform::Reformulation,
    dual_sol::DualSolution{S},
    sp_lbs::Dict{FormId, Float64},
    sp_ubs::Dict{FormId, Float64}
) where {S}
    nb_new_cols = 0
    dual_bound_contrib = DualBound{S}(0.0)
    masterform = getmaster(reform)
    sps = get_dw_pricing_sp(reform)
    recorded_sp_solution_ids = Dict{FormId, Vector{VarId}}()
    sp_dual_bound_contribs = Dict{FormId, Float64}()

    ### BEGIN LOOP TO BE PARALLELIZED
    for spform in sps
        sp_uid = getuid(spform)
        gen_status , new_sp_solution_ids, sp_dual_contrib = solve_sp_to_gencol!(
            masterform, spform, dual_sol, sp_lbs[sp_uid], sp_ubs[sp_uid]
        )
        if gen_status # else Sp is infeasible: contrib = Inf
            recorded_sp_solution_ids[sp_uid] = new_sp_solution_ids
        end
        sp_dual_bound_contribs[sp_uid] = sp_dual_contrib #float(contrib)
    end
    ### END LOOP TO BE PARALLELIZED

    nb_new_cols = 0
    for spform in sps
        sp_uid = getuid(spform)
        dual_bound_contrib += sp_dual_bound_contribs[sp_uid]
        nb_new_cols += insert_cols_in_master!(masterform, spform, recorded_sp_solution_ids[sp_uid]) 
    end
    
    
    return (nb_new_cols, dual_bound_contrib)
end

function compute_master_db_contrib(
    algdata::ColGenRuntimeData, restricted_master_sol_value::PrimalBound{S}
) where {S}
    # TODO: will change with stabilization
    return DualBound{S}(restricted_master_sol_value)
end

function update_lagrangian_db!(
    algdata::ColGenRuntimeData, restricted_master_sol_value::PrimalBound{S},
    pricing_sp_dual_bound_contrib::DualBound{S}
) where {S}
    lagran_bnd = DualBound{S}(0.0)
    lagran_bnd += compute_master_db_contrib(algdata, restricted_master_sol_value)
    lagran_bnd += pricing_sp_dual_bound_contrib
    update_ip_dual_bound!(algdata.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_restricted_master!(master::Formulation)
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit _to "LP restricted master" optimize!(master)
    end
    return (isfeasible(opt_result), getprimalbound(opt_result), 
    getprimalsols(opt_result), getdualsols(opt_result), elapsed_time)
end

function generatecolumns!(
    algdata::ColGenRuntimeData, reform::Reformulation, master_val, 
    dual_sol, sp_lbs, sp_ubs
)
    nb_new_columns = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_col, sp_db_contrib =  solve_sps_to_gencols!(reform, dual_sol, sp_lbs, sp_ubs)
        nb_new_columns += nb_new_col
        update_lagrangian_db!(algdata, master_val, sp_db_contrib)
        if nb_new_col < 0
            # subproblem infeasibility leads to master infeasibility
            return -1
        end
        break # TODO : rm
    end
    return nb_new_columns
end

ph_one_infeasible_db(db::DualBound{MinSense}) = getvalue(db) > (0.0 + 1e-5)
ph_one_infeasible_db(db::DualBound{MaxSense}) = getvalue(db) < (0.0 - 1e-5)

function cg_main_loop(
    algdata::ColGenRuntimeData, reform::Reformulation, phase::Int
)::ColumnGenerationResult
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    masterform = reform.master
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    for spform in reform.dw_pricing_subprs
        sp_uid = getuid(spform)
        lb_convexity_constr_id = reform.dw_pricing_sp_lb[sp_uid]
        ub_convexity_constr_id = reform.dw_pricing_sp_ub[sp_uid]
        sp_lbs[sp_uid] = getcurrhs(getconstr(masterform, lb_convexity_constr_id))
        sp_ubs[sp_uid] = getcurrhs(getconstr(masterform, ub_convexity_constr_id))
    end

    while true
        master_status, master_val, primal_sols, dual_sols, master_time =
            solve_restricted_master!(masterform)

        if (phase != 1 && (master_status == MOI.INFEASIBLE
            || master_status == MOI.INFEASIBLE_OR_UNBOUNDED))
            @error "Solver returned that restricted master LP is infeasible or unbounded (status = $master_status) during phase != 1."
            return ColumnGenerationResult(algdata.incumbents, true)
        end

        update_lp_primal_sol!(algdata.incumbents, primal_sols[1])
        update_lp_dual_sol!(algdata.incumbents, dual_sols[1])
        if isinteger(primal_sols[1]) && !contains(primal_sols[1], MasterArtVar)
            update_ip_primal_sol!(algdata.incumbents, primal_sols[1])
        end

        # TODO: cleanup restricted master columns        

        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_col = generatecolumns!(
                algdata, reform, master_val, dual_sols[1], sp_lbs, sp_ubs
            )
        end

        if nb_new_col < 0
            @error "Infeasible subproblem."
            return ColumnGenerationResult(algdata.incumbents, true)
        end

        print_intermediate_statistics(
            algdata, nb_new_col, nb_cg_iterations, master_time, sp_time
        )

        # TODO: update colgen stabilization

        dual_bound = get_ip_dual_bound(algdata.incumbents)
        primal_bound = get_lp_primal_bound(algdata.incumbents)     
        ip_primal_bound = get_ip_primal_bound(algdata.incumbents)

        if diff(dual_bound, ip_primal_bound) < algdata.params.optimality_tol
            algdata.has_converged = false # ???
            @logmsg LogLevel(1) "Dual bound reached primal bound."
            return ColumnGenerationResult(algdata.incumbents, false)
        end
        if phase == 1 && ph_one_infeasible_db(dual_bound)
            algdata.is_feasible = false
            @logmsg LogLevel(1) "Phase one determines infeasibility."
            return ColumnGenerationResult(algdata.incumbents, true)
        end
        if nb_new_col == 0 || gap(primal_bound, dual_bound) < algdata.params.optimality_tol
            @logmsg LogLevel(1) "Column Generation Algorithm has converged."
            algdata.has_converged = true
            return ColumnGenerationResult(algdata.incumbents, false)
        end
        if nb_cg_iterations > algdata.params.max_nb_iterations
            @warn "Maximum number of column generation iteration is reached."
            return ColumnGenerationResult(algdata.incumbents, false)
        end
    end
    return ColumnGenerationResult(algdata.incumbents, false)
end

function print_intermediate_statistics(
    algdata::ColGenRuntimeData, nb_new_col::Int, nb_cg_iterations::Int,
    mst_time::Float64, sp_time::Float64
)
    mlp = getvalue(get_lp_primal_bound(algdata.incumbents))
    db = getvalue(get_ip_dual_bound(algdata.incumbents))
    pb = getvalue(get_ip_primal_bound(algdata.incumbents))
    @printf(
        "<it=%i> <et=%i> <mst=%.3f> <sp=%.3f> <cols=%i> <mlp=%.4f> <DB=%.4f> <PB=%.4f>\n",
        nb_cg_iterations, _elapsed_solve_time(), mst_time, sp_time, nb_new_col, mlp, db, pb
    )
    return
end

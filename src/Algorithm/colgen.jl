using ..Coluna # to remove when merging to the master branch

Base.@kwdef struct ColumnGeneration <: AbstractOptimizationAlgorithm
    max_nb_iterations::Int = 1000
    optimality_tol::Float64 = 1e-5
    log_print_frequency::Int = 1
    store_all_ip_primal_sols::Bool = false
end

# Data stored while algorithm is running
mutable struct ColGenRuntimeData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    ip_primal_sols::Vector{PrimalSolution}
    phase::Int64
end

function ColGenRuntimeData(
    algparams::ColumnGeneration, form::Reformulation, ipprimalbound::PrimalBound
)
    sense = form.master.obj_sense
    inc = Incumbents(sense)
    update_ip_primal_bound!(inc, ipprimalbound)
    return ColGenRuntimeData(inc, false, true, [], 2)
end

# # Data needed for another round of column generation
# mutable struct ColumnGenerationResult <: AbstractAlgorithmResult
#     incumbents::Incumbents
#     proven_infeasible::Bool
# end

# Overload of the algorithm's prepare function
# function prepare!(alg::ColumnGeneration, form, node)
#     @logmsg LogLevel(-1) "Prepare ColumnGeneration."
#     return
# end

# Overload of the algorithm's run function
function run!(algo::ColumnGeneration, reform::Reformulation, input::OptimizationInput)::OptimizationOutput    

    @logmsg LogLevel(-1) "Run ColumnGeneration."

    initincumb = getincumbents(input)
    data = ColGenRuntimeData(algo, reform, Coluna.MathProg.get_ip_primal_bound(initincumb))

    cg_main_loop!(algo, data, reform)
    masterform = getmaster(reform)
    if should_do_ph_1(masterform, data)
        set_ph_one(masterform, data)        
        cg_main_loop!(algo, data, reform)
        # TO DO : to implement unsetting phase one !!
        # TO DO : to implement repeating of phase two in the case phase 1 succeded
    end

    if data.is_feasible
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status FEASIBLE."
    else
        data.incumbents = Incumbents(getsense(data.incumbents))
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status INFEASIBLE."
    end

    if !algo.store_all_ip_primal_sols && length(get_ip_primal_sol(data.incumbents)) > 0
        push!(data.ip_primal_sols, get_ip_primal_sol(data.incumbents))
    end

    sense = getsense(initincumb)    
    return OptimizationOutput(
        OptimizationResult{sense}(
            data.has_converged ? OPTIMAL : OTHER_LIMIT, 
            data.is_feasible ? FEASIBLE : INFEASIBLE, 
            get_ip_primal_bound(data.incumbents), get_ip_dual_bound(data.incumbents), 
            data.ip_primal_sols, Vector{DualSolution{sense}}()
        ), 
        Coluna.MathProg.get_lp_primal_sol(data.incumbents), Coluna.MathProg.get_lp_dual_bound(data.incumbents)
    )
end

# Internal methods to the column generation
function should_do_ph_1(master::Formulation, data::ColGenRuntimeData)
    ip_gap(data.incumbents) <= 0.00001 && return false
    primal_lp_sol = Coluna.MathProg.get_lp_primal_sol(data.incumbents)
    if contains(master, primal_lp_sol, MasterArtVar)
        @logmsg LogLevel(-2) "Artificial variables in lp solution, need to do phase one"
        return true
    else
        @logmsg LogLevel(-2) "No artificial variables in lp solution, will not proceed to do phase one"
        return false
    end
end

function set_ph_one(master::Formulation, data::ColGenRuntimeData)
    for (id, v) in Iterators.filter(x->(!isanArtificialDuty(getduty(x))), getvars(master))
        setcurcost!(master, v, 0.0)
    end
    data.phase = 1
    return
end

function update_pricing_problem!(spform::Formulation, dual_sol::DualSolution)
    masterform = getmaster(spform)
    for (var_id, var) in getvars(spform)
        if getcurisactive(spform, var) && getduty(var) <= AbstractDwSpVar
            redcost = computereducedcost(masterform, var_id, dual_sol)
            setcurcost!(spform, var, redcost)
        end
    end
    return false
end

function update_pricing_target!(spform::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
end

function record_solutions!(
    spform::Formulation, sols::Vector{PrimalSolution{S}}
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
    masterform::Formulation, spform::Formulation, sp_solution_ids::Vector{VarId}
) 
    sp_uid = getuid(spform)
    nb_of_gen_col = 0

    for sol_id in sp_solution_ids
        nb_of_gen_col += 1
        name = string("MC_", getsortuid(sol_id)) 
        lb = 0.0
        ub = Inf
        kind = Continuous
        duty = MasterCol
        sense = Positive
        mc = setcol_from_sp_primalsol!(
            masterform, spform, sol_id, name, duty; lb = lb, ub = ub, 
            kind = kind, sense = sense
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
    masterform::Formulation, spform::Formulation, dual_sol::DualSolution,
    sp_lb::Float64, sp_ub::Float64
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
    TO.@timeit Coluna._to "Pricing subproblem" begin
        opt_result = optimize!(spform)
    end

    pricing_db_contrib = compute_pricing_db_contrib(
        spform, getprimalbound(opt_result), sp_lb, sp_ub
    )

    if !isfeasible(opt_result)
        sp_is_feasible = false 
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return sp_is_feasible, recorded_solution_ids, PrimalBound(spform)
    end

    recorded_solution_ids = record_solutions!(
        spform, getprimalsols(opt_result)
    )

    return sp_is_feasible, recorded_solution_ids, pricing_db_contrib
end

function solve_sps_to_gencols!(
    reform::Reformulation, dual_sol::DualSolution{S}, 
    sp_lbs::Dict{FormId, Float64}, sp_ubs::Dict{FormId, Float64}
) where {S}
    nb_new_cols = 0
    dual_bound_contrib = DualBound{S}(0.0)
    masterform = getmaster(reform)
    sps = get_dw_pricing_sps(reform)
    recorded_sp_solution_ids = Dict{FormId, Vector{VarId}}()
    sp_dual_bound_contribs = Dict{FormId, Float64}()

    ### BEGIN LOOP TO BE PARALLELIZED
    for (spuid, spform) in sps
        gen_status, new_sp_solution_ids, sp_dual_contrib = solve_sp_to_gencol!(
            masterform, spform, dual_sol, sp_lbs[spuid], sp_ubs[spuid]
        )
        if gen_status # else Sp is infeasible: contrib = Inf
            recorded_sp_solution_ids[spuid] = new_sp_solution_ids
        end
        sp_dual_bound_contribs[spuid] = sp_dual_contrib #float(contrib)
    end
    ### END LOOP TO BE PARALLELIZED

    nb_new_cols = 0
    for (spuid, spform) in sps
        dual_bound_contrib += sp_dual_bound_contribs[spuid]
        nb_new_cols += insert_cols_in_master!(masterform, spform, recorded_sp_solution_ids[spuid]) 
    end
    
    
    return (nb_new_cols, dual_bound_contrib)
end

function compute_master_db_contrib(
    alg::ColGenRuntimeData, restricted_master_sol_value::PrimalBound{S}
) where {S}
    # TODO: will change with stabilization
    return DualBound{S}(restricted_master_sol_value)
end

function calculate_lagrangian_db(
    data::ColGenRuntimeData, restricted_master_sol_value::PrimalBound{S},
    pricing_sp_dual_bound_contrib::DualBound{S}
) where {S}
    lagran_bnd = DualBound{S}(0.0)
    lagran_bnd += compute_master_db_contrib(data, restricted_master_sol_value)
    lagran_bnd += pricing_sp_dual_bound_contrib
    return lagran_bnd
end

function solve_restricted_master!(master::Formulation)
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit Coluna._to "LP restricted master" optimize!(master)
    end
    return (isfeasible(opt_result), getprimalbound(opt_result), 
    getprimalsols(opt_result), getdualsols(opt_result), elapsed_time)
end

function generatecolumns!(
    data::ColGenRuntimeData, reform::Reformulation, master_val, 
    dual_sol, sp_lbs, sp_ubs
)
    nb_new_columns = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_col, sp_db_contrib =  solve_sps_to_gencols!(reform, dual_sol, sp_lbs, sp_ubs)
        nb_new_columns += nb_new_col
        lagran_bnd = calculate_lagrangian_db(data, master_val, sp_db_contrib)
        update_ip_dual_bound!(data.incumbents, lagran_bnd)
        update_lp_dual_bound!(data.incumbents, lagran_bnd)
        if nb_new_col < 0
            # subproblem infeasibility leads to master infeasibility
            return -1
        end
        break # TODO : rm
    end
    return nb_new_columns
end

ph_one_infeasible_db(db::DualBound{MinSense}) = Coluna.Containers.getvalue(db) > (0.0 + 1e-5)
ph_one_infeasible_db(db::DualBound{MaxSense}) = Coluna.Containers.getvalue(db) < (0.0 - 1e-5)

function cg_main_loop!(algo::ColumnGeneration, data::ColGenRuntimeData, reform::Reformulation)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    masterform = getmaster(reform)
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    for (sp_uid, spform) in get_dw_pricing_sps(reform)
        lb_convexity_constr_id = reform.dw_pricing_sp_lb[sp_uid]
        ub_convexity_constr_id = reform.dw_pricing_sp_ub[sp_uid]
        sp_lbs[sp_uid] = getcurrhs(masterform, lb_convexity_constr_id)
        sp_ubs[sp_uid] = getcurrhs(masterform, ub_convexity_constr_id)
    end

    while true
        master_status, master_val, primal_sols, dual_sols, master_time =
            solve_restricted_master!(masterform)

        if (data.phase != 1 && (master_status == MOI.INFEASIBLE
            || master_status == MOI.INFEASIBLE_OR_UNBOUNDED))
            @error "Solver returned that restricted master LP is infeasible or unbounded 
                    (status = $master_status) during phase != 1."
            data.is_feasible = false        
            return 
        end

        if update_lp_primal_sol!(data.incumbents, primal_sols[1])
            if isinteger(primal_sols[1]) && !contains(masterform, primal_sols[1], MasterArtVar) &&
               Coluna.MathProg.update_ip_primal_bound!(data.incumbents, master_val)
                if algo.store_all_ip_primal_sols
                    push!(data.ip_primal_sols, primal_sols[1])
                else
                    update_ip_primal_sol!(data.incumbents, primal_sols[1])
                end
            end
        else
            # even if the current lp solution is not better than the best one
            # we should update one (the best lp solution should always be the last one)
            data.incumbents.lp_primal_sol = primal_sols[1]
        end 

        # TODO: cleanup restricted master columns        

        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_col = generatecolumns!(
                data, reform, master_val, dual_sols[1], sp_lbs, sp_ubs
            )
        end

        if nb_new_col < 0
            @error "Infeasible subproblem."
            data.is_feasible = false        
            return 
        end

        print_intermediate_statistics(
            data, nb_new_col, nb_cg_iterations, master_time, sp_time
        )

        # TODO: update colgen stabilization

        dual_bound = get_ip_dual_bound(data.incumbents)
        primal_bound = get_lp_primal_bound(data.incumbents)     
        ip_primal_bound = get_ip_primal_bound(data.incumbents)

        if diff(dual_bound, ip_primal_bound) < algo.optimality_tol
            data.has_converged = true
            @logmsg LogLevel(1) "Dual bound reached primal bound."
            return 
        end
        if data.phase == 1 && ph_one_infeasible_db(dual_bound)
            data.is_feasible = false
            @logmsg LogLevel(1) "Phase one determines infeasibility."
            return 
        end
        if nb_new_col == 0 || gap(primal_bound, dual_bound) < algo.optimality_tol
            @logmsg LogLevel(1) "Column Generation Algorithm has converged."
            data.has_converged = true
            return 
        end
        if nb_cg_iterations > algo.max_nb_iterations
            @warn "Maximum number of column generation iteration is reached."
            return 
        end
    end
    return 
end

function print_intermediate_statistics(
    algdata::ColGenRuntimeData, nb_new_col::Int, nb_cg_iterations::Int,
    mst_time::Float64, sp_time::Float64
)
    # Ruslan : does not work without Coluna.Containers, I do not understand why
    mlp = Coluna.Containers.getvalue(get_lp_primal_bound(algdata.incumbents))
    db = Coluna.Containers.getvalue(get_ip_dual_bound(algdata.incumbents))
    pb = Coluna.Containers.getvalue(get_ip_primal_bound(algdata.incumbents))
    @printf(
        "<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cols=%2i> <mlp=%10.4f> <DB=%10.4f> <PB=%.4f>\n",
        nb_cg_iterations, Coluna._elapsed_solve_time(), mst_time, sp_time, nb_new_col, mlp, db, pb
    )
    return
end

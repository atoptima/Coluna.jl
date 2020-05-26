"""
    Coluna.Algorithm.ColumnGeneration(
        restr_master_solve_alg = SolveLpForm(get_dual_solution = true)
        pricing_prob_solve_alg = SolveIpForm(
            deactivate_artificial_vars = false, 
            enforce_integrality = false, 
            log_level = 2
        ),
        max_nb_iterations::Int = 1000
        optimality_tol::Float64 = 1e-5
        log_print_frequency::Int = 1
        store_all_ip_primal_sols::Bool = false
        redcost_tol::Float = 1e-5
        cleanup_threshold::Int = 10000
        cleanup_ratio::Float = 0.66
    )

Column generation algorithm. It applies `restr_master_solve_alg` to solve the linear 
restricted master and `pricing_prob_solve_alg` to solve the subproblems.
 
"""
Base.@kwdef struct ColumnGeneration <: AbstractOptimizationAlgorithm
    restr_master_solve_alg = SolveLpForm(get_dual_solution = true)
    #TODO : pricing problem solver may be different depending on the
    #       pricing subproblem
    pricing_prob_solve_alg = SolveIpForm(deactivate_artificial_vars = false,
                                         enforce_integrality = false,
                                         log_level = 2)
    max_nb_iterations::Int64 = 1000
    optimality_tol::Float64 = 1e-5
    log_print_frequency::Int64 = 1
    store_all_ip_primal_sols::Bool = false
    redcost_tol::Float64 = 1e-5
    solve_subproblems_parallel::Bool = false
    cleanup_threshold::Int64 = 10000
    cleanup_ratio::Float64 = 0.66
    smoothing_stabilization::Float64 = 0.0 # should be in [0, 1]
end

stabilization_is_used(algo::ColumnGeneration) = !iszero(algo.smoothing_stabilization)

function get_storages_usage!(
    algo::ColumnGeneration, reform::Reformulation, storages_usage::StoragesUsageDict
)
    master = getmaster(reform)
    add_storage!(storages_usage, master, MasterColumnsStorage)
    if stabilization_is_used(algo)
        add_storage!(storages_usage, master, ColGenStabilizationStorage)
    end
   
    get_storages_usage!(algo.restr_master_solve_alg, master, storages_usage)
    for (id, spform) in get_dw_pricing_sps(reform)
        get_storages_usage!(algo.pricing_prob_solve_alg, spform, storages_usage)
    end
end

function get_storages_to_restore!(
    algo::ColumnGeneration, reform::Reformulation, storages_to_restore::StoragesToRestoreDict
)
    master = getmaster(reform)
    add_storage!(storages_to_restore, master, MasterColumnsStorage, READ_AND_WRITE)
    if stabilization_is_used(algo)
        add_storage!(storages_to_restore, master, ColGenStabilizationStorage, READ_AND_WRITE)
    end

    get_storages_to_restore!(algo.restr_master_solve_alg, master, storages_to_restore)
    for (id, spform) in get_dw_pricing_sps(reform)
        get_storages_to_restore!(algo.pricing_prob_solve_alg, spform, storages_to_restore)
    end
end

struct ReducedCostsVector
    length::Int
    varids::Vector{VarId}
    perencosts::Vector{Float64}
    form::Vector{Formulation}
end

function ReducedCostsVector(varids::Vector{VarId}, form::Vector{Formulation})
    len = length(varids)
    perencosts = zeros(Float64, len)
    p = sortperm(varids)
    permute!(varids, p)
    permute!(form, p)
    for i in 1:len
        perencosts[i] = getcurcost(getmaster(form[i]), varids[i])
    end
    return ReducedCostsVector(len, varids, perencosts, form)
end

function run!(algo::ColumnGeneration, data::ReformData, input::OptimizationInput)::OptimizationOutput    
    reform = getreform(data)
    master = getmaster(reform)
    optstate = CopyBoundsAndStatusesFromOptState(master, getoptstate(input), false)
    
    set_ph3!(master) # mixed ph1 & ph2
    stop = cg_main_loop!(algo, 3, optstate, data)

    if !stop && should_do_ph_1(optstate)
        set_ph1!(master, optstate)        
        stop = cg_main_loop!(algo, 1, optstate, data)
        if !stop
            set_ph2!(master, optstate) # pure ph2
            cg_main_loop!(algo, 2, optstate, data)
        end
    end

    @logmsg LogLevel(-1) string("ColumnGeneration terminated with status ", getfeasibilitystatus(optstate))

    return OptimizationOutput(optstate)
end

function should_do_ph_1(optstate::OptimizationState)
    primal_lp_sol = get_lp_primal_sols(optstate)[1]
    if contains(primal_lp_sol, vid -> isanArtificialDuty(getduty(vid)))
        @logmsg LogLevel(-2) "Artificial variables in lp solution, need to do phase one"
        return true
    else
        @logmsg LogLevel(-2) "No artificial variables in lp solution, will not proceed to do phase one"
        return false
    end
end

function set_ph1!(master::Formulation, optstate::OptimizationState)
    for (varid, var) in getvars(master)
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

function update_pricing_target!(spform::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
end

function insert_cols_in_master!(
    phase::Int64, masterform::Formulation, spform::Formulation, sp_solution_ids::Vector{VarId}
) 
    sp_uid = getuid(spform)
    nb_of_gen_col = 0
    best_col = nothing

    for (i, sol_id) in enumerate(sp_solution_ids)
        nb_of_gen_col += 1
        name = string("MC_", getsortuid(sol_id))
        lb = 0.0
        ub = Inf
        kind = Continuous
        duty = MasterCol
        mc = setcol_from_sp_primalsol!(
            masterform, spform, sol_id, name, duty; lb = lb, ub = ub, kind = kind
        )        
        if phase == 1
            setcurcost!(masterform, mc, 0.0)
        end
        i == 1 && best_col = mc
        @logmsg LogLevel(-2) string("Generated column : ", name)
    end

    return (nb_of_gen_col, best_col)
end

function contrib_improves_mlp(algo::ColumnGeneration, ::Type{MinSense}, sp_primal_bound::Float64)
    return sp_primal_bound < 0.0 - algo.redcost_tol
end

function contrib_improves_mlp(algo::ColumnGeneration, ::Type{MaxSense}, sp_primal_bound::Float64)
    return sp_primal_bound > 0.0 + algo.redcost_tol
end

function contrib_improves_mlp(algo::ColumnGeneration, sp_primal_bound::PrimalBound{MinSense})
    return sp_primal_bound < 0.0 - algo.redcost_tol
end

function contrib_improves_mlp(algo::ColumnGeneration, sp_primal_bound::PrimalBound{MaxSense})
    return sp_primal_bound > 0.0 + algo.redcost_tol
end

function compute_pricing_db_contrib(
    algo::ColumnGeneration, spform::Formulation, sp_sol_primal_bound::PrimalBound, sp_lb::Float64,
    sp_ub::Float64
)
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost * multiplicty
    if contrib_improves_mlp(algo, sp_sol_primal_bound)
        contrib = sp_sol_primal_bound * sp_ub
    else
        contrib = sp_sol_primal_bound * sp_lb
    end
    return contrib
end

function solve_sp_to_gencol!(
    algo::ColumnGeneration, masterform::Formulation, spdata::ModelData, dual_sol::DualSolution,
    sp_lb::Float64, sp_ub::Float64
)::Tuple{Bool,Vector{VarId},Vector{VarId},Float64}

    spform = getmodel(spdata)
    recorded_solution_ids = Vector{VarId}()
    sp_solution_ids_to_activate = Vector{VarId}()
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
    #if update_pricing_problem!(spform, dual_sol) # Never returns true
        #     This code is never executed because update_pricing_prob always returns false
        #     @logmsg LogLevel(-3) "pricing prob is infeasible"
        #     # In case one of the subproblem is infeasible, the master is infeasible
        #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
        #     return flag_is_sp_infeasible
    #end

    # if alg.colgen_stabilization != nothing && true #= TODO add conds =#
    #     # switch off the reduced cost estimation when stabilization is applied
    # end

    # Solve sub-problem and insert generated columns in master
    # @logmsg LogLevel(-3) "optimizing pricing prob"
    output = run!(algo.pricing_prob_solve_alg, spdata, OptimizationInput(OptimizationState(spform)))
    sp_optstate = getoptstate(output)

    pricing_db_contrib = compute_pricing_db_contrib(algo, spform, get_ip_primal_bound(sp_optstate), sp_lb, sp_ub)

    if !isfeasible(sp_optstate)
        sp_is_feasible = false
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return sp_is_feasible, recorded_solution_ids, PrimalBound(spform)
    end

    if nb_ip_primal_sols(sp_optstate) > 0
        for sol in get_ip_primal_sols(sp_optstate)
            if contrib_improves_mlp(algo, getobjsense(spform), getvalue(sol)) # has negative reduced cost
                insertion_status, col_id = setprimalsol!(spform, sol)
                if insertion_status
                    push!(recorded_solution_ids, col_id)
                elseif !insertion_status && !iscuractive(masterform, col_id)
                    push!(sp_solution_ids_to_activate, col_id)
                else
                    msg = """
                    Column already exists as $(getname(masterform, col_id)) and is already active.
                    """
                    @warn string(msg)
                end
            end
        end
    end

    return sp_is_feasible, recorded_solution_ids, sp_solution_ids_to_activate, pricing_db_contrib
end


function updatereducedcosts!(reform::Reformulation, redcostsvec::ReducedCostsVector, dualsol::DualSolution)
    redcosts = deepcopy(redcostsvec.perencosts)
    master = getmaster(reform)
    sign = getobjsense(master) == MinSense ? -1 : 1
    matrix = getcoefmatrix(master)

    crm = matrix.rows_major

    constr_key_pos::Int = 1
    next_constr_key_pos::Int = 2

    row_start = 0
    row_end = 0
    row_pos = 0

    terms = Dict{VarId, Float64}(id => 0.0 for id in redcostsvec.varids)

    for dual_pos in 1:length(dualsol.sol.array)
        entry = dualsol.sol.array[dual_pos]
        if entry !== nothing
            constrid, val = entry
            while constr_key_pos <= length(crm.col_keys) && crm.col_keys[constr_key_pos] != constrid
                constr_key_pos += 1
            end
            (constr_key_pos > length(crm.col_keys)) && break
            next_constr_key_pos = constr_key_pos + 1
            while next_constr_key_pos <= length(crm.col_keys) && crm.col_keys[next_constr_key_pos] === nothing
                next_constr_key_pos += 1
            end

            row_start = crm.pcsc.semaphores[constr_key_pos] + 1
            row_end = length(crm.pcsc.pma.array)
            if next_constr_key_pos <= length(crm.col_keys)
                row_end = crm.pcsc.semaphores[next_constr_key_pos] - 1
            end

            for row_pos in row_start:row_end
                entry = crm.pcsc.pma.array[row_pos]
                if entry !== nothing
                    row_varid, coeff = entry
                    if getduty(row_varid) <= AbstractMasterRepDwSpVar
                        terms[row_varid] = get(terms, row_varid, 0.0) + val * coeff
                    end
                end
            end
            constr_key_pos = next_constr_key_pos
        end
    end

    for (i, varid) in enumerate(redcostsvec.varids)
        setcurcost!(redcostsvec.form[i], varid, redcosts[i] + sign * terms[varid])
    end
    return redcosts
end

function solve_sps_to_gencols!(
    algo::ColumnGeneration, phase::Int64, data::ReformData, redcostsvec::ReducedCostsVector, 
    dual_sol::DualSolution, sp_lbs::Dict{FormId, Float64}, sp_ubs::Dict{FormId, Float64}
)
    reform = getreform(data)
    masterform = getmaster(reform)
    nb_new_cols = 0
    dual_bound_contrib = DualBound(masterform, 0.0)
    masterform = getmaster(reform)
    spsdatas = get_dw_pricing_datas(data)
    recorded_sp_solution_ids = Dict{FormId, Vector{VarId}}()
    sp_solution_to_activate = Dict{FormId, Vector{VarId}}()
    sp_dual_bound_contribs = Dict{FormId, Float64}()
    best_cols_ids_and_bounds = Vector{Tuple{VarId, Float64, Float64}}()

    # update reduced costs
    updatereducedcosts!(reform, redcostsvec, dual_sol)

    ### BEGIN LOOP TO BE PARALLELIZED
    if algo.solve_subproblems_parallel
        spuids = collect(keys(spsdatas))
        Threads.@threads for key in 1:length(spuids)
            spuid = spuids[key]
            spdata = spsdatas[spuid]
            gen_status, new_sp_sol_ids, sp_sol_ids_to_activate, sp_dual_contrib = solve_sp_to_gencol!(
                algo, masterform, spdata, dual_sol, sp_lbs[spuid], sp_ubs[spuid]
            )
            if gen_status # else Sp is infeasible: contrib = Inf
                recorded_sp_solution_ids[spuid] = new_sp_sol_ids
                sp_solution_to_activate[spuid] = sp_sol_ids_to_activate
            end
            sp_dual_bound_contribs[spuid] = sp_dual_contrib #float(contrib)
        end
    else
        for (spuid, spdata) in spsdatas
            gen_status, new_sp_sol_ids, sp_sol_ids_to_activate, sp_dual_contrib = solve_sp_to_gencol!(
                algo, masterform, spdata, dual_sol, sp_lbs[spuid], sp_ubs[spuid]
            )
            if gen_status # else Sp is infeasible: contrib = Inf
                recorded_sp_solution_ids[spuid] = new_sp_sol_ids
                sp_solution_to_activate[spuid] = sp_sol_ids_to_activate
            end
            sp_dual_bound_contribs[spuid] = sp_dual_contrib #float(contrib)
        end
    end
    ### END LOOP TO BE PARALLELIZED

    nb_new_cols = 0
    for (spuid, spdata) in spsdatas
        dual_bound_contrib += sp_dual_bound_contribs[spuid]
        nb_of_gen_cols, best_col = insert_cols_in_master!(
            phase, masterform, getmodel(spdata), recorded_sp_solution_ids[spuid]
        )
        nb_new_cols += nb_of_gen_cols
        if algo.smoothing_stabilization == 1.0
            push!(best_cols_ids_and_bounds, (getid(best_col), sp_lbs[spuid], sp_ubs[spuid]))
        end
        for colid in sp_solution_to_activate[spuid]
            activate!(masterform, colid)
            nb_new_cols += 1
        end
    end

    if algo.smoothing_stabilization == 1 && length(best_cols_ids_and_bounds) < length(get_dw_pricing_datas(data))
        @error string("Solutions to all pricing subproblems should be available in order ",
                      " to used automatic dual price smoothing")
    end

    return (nb_new_cols, dual_bound_contrib, best_sp_solution_ids)
end

function compute_master_db_contrib(
    restricted_master_sol_value::PrimalBound{S}
) where {S}
    # TODO: will change with stabilization
    return DualBound{S}(restricted_master_sol_value)
end

function calculate_lagrangian_db(
    restricted_master_sol_value::PrimalBound{S},
    pricing_sp_dual_bound_contrib::DualBound{S}
) where {S}
    lagran_bnd = DualBound{S}(0.0)
    lagran_bnd += compute_master_db_contrib(restricted_master_sol_value)
    lagran_bnd += pricing_sp_dual_bound_contrib
    return lagran_bnd
end

#stopped here
# function generatecolumns!(
#     algo::ColumnGeneration, optstate::OptimizationState, phase::Int64, data::ReformData, 
#     redcostsvec::ReducedCostsVector, master_val, dual_sol, sp_lbs, sp_ubs
# )
#     nb_new_columns = 0
#     while true # TODO Replace this condition when starting implement stabilization
#         nb_new_col, sp_db_contrib =  solve_sps_to_gencols!(algo, phase, data, redcostsvec, dual_sol, sp_lbs, sp_ubs)
#         nb_new_columns += nb_new_col
#         lagran_bnd = calculate_lagrangian_db(master_val, sp_db_contrib)
#         update_ip_dual_bound!(optstate, lagran_bnd)
#         update_lp_dual_bound!(optstate, lagran_bnd)
#         if nb_new_col < 0
#             # subproblem infeasibility leads to master infeasibility
#             return -1
#         end
#         break # TODO : rm
#     end
#     return nb_new_columns
# end

can_be_in_basis(algo::ColumnGeneration, ::Type{MinSense}, redcost::Float64) =
    redcost < 0 + algo.redcost_tol

can_be_in_basis(algo::ColumnGeneration, ::Type{MaxSense}, redcost::Float64) =
    redcost > 0 - algo.redcost_tol

function cleanup_columns(algo::ColumnGeneration, iteration::Int64, data::ReformData)

    # we do columns clean up only on every 10th iteration in order not to spend 
    # the time retrieving the reduced costs
    # TO DO : master cleanup should be done on every iteration, for this we need
    # to quickly check the number of active master columns
    iteration % 10 != 0 && return

    cols_with_redcost = Vector{Pair{Variable, Float64}}()
    master = getmodel(getmasterdata(data))
    for (id, var) in getvars(master)
        if getduty(id) <= MasterCol && iscuractive(master, var) && isexplicit(master, var)
            push!(cols_with_redcost, var => getreducedcost(master, var))            
        end
    end

    num_active_cols = length(cols_with_redcost)
    num_active_cols < algo.cleanup_threshold && return

    # sort active master columns by reduced cost
    reverse_order = getobjsense(master) == MinSense ? true : false
    sort!(cols_with_redcost, by = x -> x.second, rev=reverse_order)

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
end        

ph_one_infeasible_db(algo, db::DualBound{MinSense}) = getvalue(db) > algo.optimality_tol
ph_one_infeasible_db(algo, db::DualBound{MaxSense}) = getvalue(db) < - algo.optimality_tol

function cg_main_loop!(
    algo::ColumnGeneration, phase::Int, cg_optstate::OptimizationState, data::ReformData
)
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    reform = getreform(data)
    masterform = getmaster(reform)
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    dwspvars = Vector{VarId}()
    dwspforms = Vector{Formulation}()

    for (spid, spform) in get_dw_pricing_sps(reform)
        lb_convexity_constr_id = reform.dw_pricing_sp_lb[spid]
        ub_convexity_constr_id = reform.dw_pricing_sp_ub[spid]
        sp_lbs[spid] = getcurrhs(masterform, lb_convexity_constr_id)
        sp_ubs[spid] = getcurrhs(masterform, ub_convexity_constr_id)

        for (varid, var) in getvars(spform)
            if iscuractive(spform, varid) && getduty(varid) <= AbstractDwSpVar
                push!(dwspvars, varid)
                push!(dwspforms, spform)
            end
        end
    end

    redcostsvec = ReducedCostsVector(dwspvars, dwspforms)
    iteration = 0

    stabstorage = stabilization_is_used(algo) ? getstorage(getmasterdata(data), ColGenStabilizationStorage) : ColGenStabStorage()

    while true
        rm_time = @elapsed begin
            rm_input = OptimizationInput(
                OptimizationState(masterform, ip_primal_bound = get_ip_primal_bound(cg_optstate))
            )
            rm_output = run!(algo.restr_master_solve_alg, getmasterdata(data), rm_input)
        end
        rm_optstate = getoptstate(rm_output)
        master_val = get_lp_primal_bound(rm_optstate)

        if phase != 1 && !isfeasible(rm_optstate)
            status = getfeasibilitystatus(rm_optstate)
            @warn string("Solver returned that LP restricted master is infeasible or unbounded ",
            "(feasibility status = " , status, ") during phase != 1.")
            setfeasibilitystatus!(cg_optstate, status)
            return true
        end

        lp_dual_sol = DualSolution(masterform)
        if nb_lp_dual_sols(rm_optstate) > 0
            lp_dual_sol = get_best_lp_dual_sol(rm_optstate)
        else
            @error string("Solver returned that the LP restricted master is feasible but ",
            "did not return a dual solution. ",
            "Please open an issue (https://github.com/atoptima/Coluna.jl/issues).")
        end

        if nb_lp_primal_sols(rm_optstate) > 0
            set_lp_primal_sol!(cg_optstate, get_best_lp_primal_sol(rm_optstate))
            set_lp_primal_bound!(cg_optstate, get_lp_primal_bound(rm_optstate))
        else
            @error string("Solver returned that the LP restricted master is feasible but ",
            "did not return a primal solution. ",
            "Please open an issue (https://github.com/atoptima/Coluna.jl/issues).")
        end

        update_all_ip_primal_solutions!(cg_optstate, rm_optstate)

        TO.@timeit Coluna._to "Cleanup columns" begin
            cleanup_columns(algo, iteration, data)        
        end

        iteration += 1

        smooth_dual_sol = init_stab_after_rm_solve!(stabstorage, algo.smoothing_stabilization, lp_dual_sol)

        nb_new_columns = 0
        sp_time = 0
        while true
            sp_time += @elapsed begin
                nb_new_col, sp_db_contrib, best_cols_ids_and_bounds =  solve_sps_to_gencols!(
                    algo, phase, data, redcostsvec, smooth_dual_sol, sp_lbs, sp_ubs
                )
            end
            nb_new_columns += nb_new_col
            
            lagran_bnd = calculate_lagrangian_db(master_val, sp_db_contrib)
            update_ip_dual_bound!(cg_optstate, lagran_bnd)
            update_lp_dual_bound!(cg_optstate, lagran_bnd)
            if nb_new_col < 0
                @error "Infeasible subproblem."
                setfeasibilitystatus!(cg_optstate, INFEASIBLE)
                return true
            end

            smooth_dual_sol = update_stab_after_gencols!(
                stabstorage, algo.smoothing_stabilization, nb_new_col, lp_dual_sol, smooth_dual_sol, best_cols_ids_and_bounds
            )

            smooth_dual_sol === nothing && break
        end    
    
        print_colgen_statistics(phase, iteration, stabstorage.curalpha, cg_optstate, nb_new_columns, rm_time, sp_time)

        update_stab_after_colgen_iteration!(stabstorage)

        dual_bound = get_ip_dual_bound(cg_optstate)
        primal_bound = get_lp_primal_bound(cg_optstate)
        ip_primal_bound = get_ip_primal_bound(cg_optstate)

        if ip_gap(cg_optstate) < algo.optimality_tol
            setterminationstatus!(cg_optstate, OPTIMAL)
            @logmsg LogLevel(0) "Dual bound reached primal bound."
            return true
        end
        if phase == 1 && ph_one_infeasible_db(algo, dual_bound)
            db = - getvalue(DualBound(reform))
            pb = - getvalue(PrimalBound(reform))
            set_lp_dual_bound!(cg_optstate, DualBound(reform, db))
            set_lp_primal_bound!(cg_optstate, PrimalBound(reform, pb))
            setfeasibilitystatus!(cg_optstate, INFEASIBLE)
            @logmsg LogLevel(0) "Phase one determines infeasibility."
            return true
        end
        if nb_new_columns == 0 || lp_gap(cg_optstate) < algo.optimality_tol
            @logmsg LogLevel(0) "Column Generation Algorithm has converged."
            setterminationstatus!(cg_optstate, OPTIMAL)
            return false
        end
        if iteration > algo.max_nb_iterations
            setterminationstatus!(cg_optstate, OTHER_LIMIT)
            @warn "Maximum number of column generation iteration is reached."
            return true
        end
    end
    return false
end

function print_colgen_statistics(
    phase::Int64, iteration::Int64, smoothalpha::Float64, optstate::OptimizationState, nb_new_col::Int, mst_time::Float64, sp_time::Float64
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
        phase_string, iteration, Coluna._elapsed_solve_time(), mst_time, sp_time, nb_new_col, smoothalpha, db, mlp, pb
    )
    return
end

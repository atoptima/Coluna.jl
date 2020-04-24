Base.@kwdef struct ColumnGeneration <: AbstractOptimizationAlgorithm
    max_nb_iterations::Int = 1000
    optimality_tol::Float64 = 1e-5
    log_print_frequency::Int = 1
    store_all_ip_primal_sols::Bool = false
end

# Data stored while algorithm is running
mutable struct ColGenRuntimeData
    optstate::OptimizationState
    phase::Int64
end

function ColGenRuntimeData(
    algo::ColumnGeneration, reform::Reformulation, nodestate::OptimizationState
)
    optstate = CopyBoundsAndStatusesFromOptState(getmaster(reform), nodestate, false)
    return ColGenRuntimeData(optstate, 2)
end

struct ReducedCostsVector
    length::Int
    varids::Vector{VarId}
    perenecosts::Vector{Float64}
    form::Vector{Formulation}
end

function ReducedCostsVector(varids::Vector{VarId}, form::Vector{Formulation})
    len = length(varids)
    perenecosts = zeros(Float64, len)
    p = sortperm(varids)
    permute!(varids, p)
    permute!(form, p)
    for i in 1:len
        perenecosts[i] = getperenecost(form[i], varids[i])
    end
    return ReducedCostsVector(len, varids, perenecosts, form)
end

getoptstate(data::ColGenRuntimeData) = data.optstate

function run!(algo::ColumnGeneration, reform::Reformulation, input::OptimizationInput)::OptimizationOutput    
    data = ColGenRuntimeData(algo, reform, getoptstate(input))
    optstate = getoptstate(data)

    cg_main_loop!(algo, data, reform)
    masterform = getmaster(reform)
    if should_do_ph_1(masterform, data)
        set_ph_one(masterform, data)        
        cg_main_loop!(algo, data, reform)
        # TO DO : to implement unsetting phase one !!
        # TO DO : to implement repeating of phase two in the case phase 1 succeded
    end

    @logmsg LogLevel(-1) string("ColumnGeneration terminated with status ", getfeasibilitystatus(optstate))

    return OptimizationOutput(optstate)
end

# Internal methods to the column generation
function should_do_ph_1(master::Formulation, data::ColGenRuntimeData)
    ip_gap(getoptstate(data)) <= 0.00001 && return false
    primal_lp_sol = get_lp_primal_sols(getoptstate(data))[1]
    if contains(primal_lp_sol, vid -> isanArtificialDuty(getduty(vid)))
        @logmsg LogLevel(-2) "Artificial variables in lp solution, need to do phase one"
        return true
    else
        @logmsg LogLevel(-2) "No artificial variables in lp solution, will not proceed to do phase one"
        return false
    end
end

function set_ph_one(master::Formulation, data::ColGenRuntimeData)
    for (varid, var) in getvars(master)
        isanArtificialDuty(getduty(varid)) && continue
        setcurcost!(master, varid, 0.0)
    end
    data.phase = 1
    return
end

function update_pricing_target!(spform::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
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

contrib_improves_mlp(::Type{MinSense}, sp_primal_bound::Float64) = (sp_primal_bound < 0.0 - 1e-8)
contrib_improves_mlp(::Type{MaxSense}, sp_primal_bound::Float64) = (sp_primal_bound > 0.0 + 1e-8)
contrib_improves_mlp(sp_primal_bound::PrimalBound{MinSense}) = (sp_primal_bound < 0.0 - 1e-8)
contrib_improves_mlp(sp_primal_bound::PrimalBound{MaxSense}) = (sp_primal_bound > 0.0 + 1e-8)

function compute_pricing_db_contrib(
    spform::Formulation, sp_sol_primal_bound::PrimalBound, sp_lb::Float64,
    sp_ub::Float64
)
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
)::Tuple{Bool,Vector{VarId},Vector{VarId},Float64}
    
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
    ipform = SolveIpForm(deactivate_artificial_vars = false, enforce_integrality = false, log_level = 2)
    TO.@timeit Coluna._to "Pricing subproblem" begin
        output = run!(ipform, spform, OptimizationInput(OptimizationState(spform)))
    end
    sp_optstate = getoptstate(output)

    pricing_db_contrib = compute_pricing_db_contrib(
        spform, get_ip_primal_bound(sp_optstate), sp_lb, sp_ub
    )

    if !isfeasible(sp_optstate)
        sp_is_feasible = false 
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return sp_is_feasible, recorded_solution_ids, PrimalBound(spform)
    end

    if nb_ip_primal_sols(sp_optstate) > 0
        for sol in get_ip_primal_sols(sp_optstate)
            if contrib_improves_mlp(getobjsense(spform), getvalue(sol)) # has negative reduced cost
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
    redcosts = deepcopy(redcostsvec.perenecosts)
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
    reform::Reformulation, redcostsvec::ReducedCostsVector, dual_sol::DualSolution, 
    sp_lbs::Dict{FormId, Float64}, sp_ubs::Dict{FormId, Float64}
)
    masterform = getmaster(reform)
    nb_new_cols = 0
    dual_bound_contrib = DualBound(masterform, 0.0)
    masterform = getmaster(reform)
    sps = get_dw_pricing_sps(reform)
    recorded_sp_solution_ids = Dict{FormId, Vector{VarId}}()
    sp_solution_to_activate = Dict{FormId, Vector{VarId}}()
    sp_dual_bound_contribs = Dict{FormId, Float64}()

    # update reduced costs
    updatereducedcosts!(reform, redcostsvec, dual_sol)

    ### BEGIN LOOP TO BE PARALLELIZED
    for (spuid, spform) in sps
        gen_status, new_sp_solution_ids, sp_solution_ids_to_activate, sp_dual_contrib = solve_sp_to_gencol!(
            masterform, spform, dual_sol, sp_lbs[spuid], sp_ubs[spuid]
        )
        if gen_status # else Sp is infeasible: contrib = Inf
            recorded_sp_solution_ids[spuid] = new_sp_solution_ids
            sp_solution_to_activate[spuid] = sp_solution_ids_to_activate
        end
        sp_dual_bound_contribs[spuid] = sp_dual_contrib #float(contrib)
    end
    ### END LOOP TO BE PARALLELIZED

    nb_new_cols = 0
    for (spuid, spform) in sps
        dual_bound_contrib += sp_dual_bound_contribs[spuid]
        nb_new_cols += insert_cols_in_master!(masterform, spform, recorded_sp_solution_ids[spuid])
        for colid in sp_solution_to_activate[spuid]
            activate!(masterform, colid)
            nb_new_cols += 1
        end
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

#stopped here
function generatecolumns!(
    data::ColGenRuntimeData, reform::Reformulation, redcostsvec::ReducedCostsVector, 
    master_val, dual_sol, sp_lbs, sp_ubs
)
    cg_optstate = getoptstate(data)
    nb_new_columns = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_col, sp_db_contrib =  solve_sps_to_gencols!(reform, redcostsvec, dual_sol, sp_lbs, sp_ubs)
        nb_new_columns += nb_new_col
        lagran_bnd = calculate_lagrangian_db(data, master_val, sp_db_contrib)
        update_ip_dual_bound!(cg_optstate, lagran_bnd)
        update_lp_dual_bound!(cg_optstate, lagran_bnd)
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

function cg_main_loop!(algo::ColumnGeneration, data::ColGenRuntimeData, reform::Reformulation)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
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

    cg_optstate = getoptstate(data)
    redcostsvec = ReducedCostsVector(dwspvars, dwspforms)

    while true
        rm_time = @elapsed begin
            rm_input = OptimizationInput(
                OptimizationState(masterform, ip_primal_bound = get_ip_primal_bound(cg_optstate))
            )
            rm_output = run!(SolveLpForm(get_dual_solution = true), masterform, rm_input)
        end
        rm_optstate = getoptstate(rm_output)
        master_val = get_lp_primal_bound(rm_optstate)

        if data.phase != 1 && !isfeasible(rm_optstate)
            status = getfeasibilitystatus(rm_optstate)
            @warn string("Solver returned that LP restricted master is infeasible or unbounded ",
            "(feasibility status = " , status, ") during phase != 1.")
            setfeasibilitystatus!(cg_optstate, status) 
            return
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

        # TODO: cleanup restricted master columns        

        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_col = generatecolumns!(
                data, reform, redcostsvec, master_val, lp_dual_sol, sp_lbs, sp_ubs
            )
        end

        if nb_new_col < 0
            @error "Infeasible subproblem."
            setfeasibilitystatus!(cg_optstate, INFEASIBLE) 
            return 
        end

        print_colgen_statistics(cg_optstate, nb_new_col, nb_cg_iterations, rm_time, sp_time)

        # TODO: update colgen stabilization

        dual_bound = get_ip_dual_bound(cg_optstate)
        primal_bound = get_lp_primal_bound(cg_optstate)     
        ip_primal_bound = get_ip_primal_bound(cg_optstate)

        if ip_gap(cg_optstate) < algo.optimality_tol
            setterminationstatus!(cg_optstate, OPTIMAL) 
            @logmsg LogLevel(1) "Dual bound reached primal bound."
            return 
        end
        if data.phase == 1 && ph_one_infeasible_db(dual_bound)
            db = - getvalue(DualBound(reform))
            pb = - getvalue(PrimalBound(reform))
            set_lp_dual_bound!(cg_optstate, DualBound(reform, db))
            set_lp_primal_bound!(cg_optstate, PrimalBound(reform, pb))
            setfeasibilitystatus!(cg_optstate, INFEASIBLE) 
            @logmsg LogLevel(1) "Phase one determines infeasibility."
            return 
        end
        if nb_new_col == 0 || lp_gap(cg_optstate) < algo.optimality_tol
            @logmsg LogLevel(1) "Column Generation Algorithm has converged."
            setterminationstatus!(cg_optstate, OPTIMAL) 
            return 
        end
        if nb_cg_iterations > algo.max_nb_iterations
            setterminationstatus!(cg_optstate, OTHER_LIMIT)
            @warn "Maximum number of column generation iteration is reached."
            return 
        end
    end
    return 
end

function print_colgen_statistics(
    optstate::OptimizationState, nb_new_col::Int, nb_cg_iterations::Int,
    mst_time::Float64, sp_time::Float64
)
    mlp = getvalue(get_lp_primal_bound(optstate))
    db = getvalue(get_lp_dual_bound(optstate))
    pb = getvalue(get_ip_primal_bound(optstate))
    @printf(
        "<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cols=%2i> <DB=%10.4f> <mlp=%10.4f> <PB=%.4f>\n",
        nb_cg_iterations, Coluna._elapsed_solve_time(), mst_time, sp_time, nb_new_col, db, mlp, pb
    )
    return
end

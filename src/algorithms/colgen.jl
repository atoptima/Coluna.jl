Base.@kwdef struct ColumnGeneration <: AbstractAlgorithm
    option::Bool = false
end

mutable struct ColumnGenTmpRecord <: AbstractAlgorithmTmpRecord
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
end

function ColumnGenTmpRecord(S::Type{<:AbstractObjSense}, node_inc::Incumbents)
    i = Incumbents(S)
    set_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    return ColumnGenTmpRecord(i, false, true)
end

# Data needed for another round of column generation
mutable struct ColumnGenerationRecord <: AbstractAlgorithmResult
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the algorithm's prepare function
function prepare!(algo::ColumnGeneration, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Prepare ColumnGeneration."
    return
end

function should_do_ph_1(cg_rec::ColumnGenerationRecord)
    primal_lp_sol = getsol(get_lp_primal_sol(cg_rec.incumbents))
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
    for (id, v) in filter(x->(!(getduty(x[2]) isa ArtificialDuty)), getvars(master))
        setcurcost!(master, v, 0.0)
    end
    return
end

function run!(algo::ColumnGeneration, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Run ColumnGeneration."
    algdataa = ColumnGenTmpRecord(form.master.obj_sense, node.incumbents)
    cg_rec = cg_main_loop(algdataa, form, 2)
    if should_do_ph_1(cg_rec)
        record!(form, node)
        set_ph_one(form.master)
        cg_rec = cg_main_loop(algdataa, form, 1)
    end
    if cg_rec.proven_infeasible
        cg_rec.incumbents = Incumbents(getsense(cg_rec.incumbents))
    end
    if cg_rec.proven_infeasible
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status INFEASIBLE."
    else
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status FEASIBLE."
    end
    set!(node.incumbents, cg_rec.incumbents)
    return cg_rec
end

# Internal methods to the column generation
function update_pricing_problem!(spform::Formulation, dual_sol::DualSolution)

    masterform = spform.parent_formulation

    for (var_id, var) in filter(_active_pricing_sp_var_ , getvars(spform))
        setcurcost!(spform, var, computereducedcost(masterform, var_id, dual_sol))
    end

    return false
end

function update_pricing_target!(spform::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
end

function insert_cols_in_master!(masterform::Formulation,
                               spform::Formulation,
                               sp_sols::Vector{PrimalSolution{S}}) where {S}

    sp_uid = getuid(spform)
    nb_of_gen_col = 0

    for sp_sol in sp_sols
        if contrib_improves_mlp(getbound(sp_sol))
            nb_of_gen_col += 1
            ref = getvarcounter(masterform) + 1
            name = string("MC", sp_uid, "_", ref)
            resetsolvalue(masterform, sp_sol)
            lb = 0.0
            ub = Inf
            kind = Continuous
            duty = MasterCol
            sense = Positive
            mc = setprimaldwspsol!(
                masterform, name, sp_sol, duty; lb = lb, ub = ub,
                kind = kind, sense = sense
            )
            @logmsg LogLevel(-2) string("Generated column : ", name)

            # TODO: check if column exists
            #== mc_id = getid(mc)
            id_of_existing_mc = - 1
            partialsol_matrix = getpartialsolmatrix(masterform)
            for (col, col_members) in columns(partialsol_matrix)
                if (col_members == partialsol_matrix[:, mc_id])
                    id_of_existing_mc = col[1]
                    break
                end
            end
            if (id_of_existing_mc != mc_id)
                @warn string("column already exists as", id_of_existing_mc)
            end
            ==#
        end
    end

    return nb_of_gen_col
end

contrib_improves_mlp(sp_primal_bound::PrimalBound{MinSense}) = (sp_primal_bound < 0.0 - 1e-8)
contrib_improves_mlp(sp_primal_bound::PrimalBound{MaxSense}) = (sp_primal_bound > 0.0 + 1e-8)

function compute_pricing_db_contrib(spform::Formulation,
                                    sp_sol_primal_bound::PrimalBound{S},
                                    sp_lb::Float64,
                                    sp_ub::Float64) where {S}
    # Since convexity constraints are not automated and there is no stab
    # the pricing_dual_bound_contrib is just the reduced cost * multiplicty
    if contrib_improves_mlp(sp_sol_primal_bound)
        contrib = sp_sol_primal_bound * sp_ub
    else
        contrib = sp_sol_primal_bound * sp_lb
    end
    return contrib
end

function solve_sp_to_gencol!(masterform::Formulation,
                     spform::Formulation,
                     dual_sol::DualSolution,
                     sp_lb::Float64,
                     sp_ub::Float64)

    #flag_need_not_generate_more_col = 0 # Not used
    flag_is_sp_infeasible = -1
    #flag_cannot_generate_more_col = -2 # Not used
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
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end

    insertion_status = insert_cols_in_master!(
        masterform, spform, getprimalsols(opt_result)
    )

    return insertion_status, pricing_db_contrib
end

function solve_sps_to_gencols!(reformulation::Reformulation,
                  dual_sol::DualSolution{S},
                  sp_lbs::Dict{FormId, Float64},
                  sp_ubs::Dict{FormId, Float64}) where {S}

    nb_new_cols = 0
    dual_bound_contrib = DualBound{S}(0.0)
    masterform = getmaster(reformulation)
    sps = get_dw_pricing_sp(reformulation)
    for spform in sps
        sp_uid = getuid(spform)
        gen_status, contrib = solve_sp_to_gencol!(masterform, spform, dual_sol, sp_lbs[sp_uid], sp_ubs[sp_uid])

        if gen_status > 0
            nb_new_cols += gen_status
            dual_bound_contrib += float(contrib)
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, Inf)
        end
    end
    return (nb_new_cols, dual_bound_contrib)
end

function compute_master_db_contrib(algdata::ColumnGenTmpRecord,
                                   restricted_master_sol_value::PrimalBound{S}) where {S}
    # TODO: will change with stabilization
    return DualBound{S}(restricted_master_sol_value)
end

function update_lagrangian_db!(algdata::ColumnGenTmpRecord,
                               restricted_master_sol_value::PrimalBound{S},
                               pricing_sp_dual_bound_contrib::DualBound{S}) where {S}
    lagran_bnd = DualBound{S}(0.0)
    lagran_bnd += compute_master_db_contrib(algdata, restricted_master_sol_value)
    lagran_bnd += pricing_sp_dual_bound_contrib
    set_ip_dual_bound!(algdata.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_restricted_master!(master::Formulation)
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit _to "LP restricted master" optimize!(master)
    end
    return (isfeasible(opt_result), getprimalbound(opt_result), 
    getprimalsols(opt_result), getdualsols(opt_result), elapsed_time)
end

function generatecolumns!(algdata::ColumnGenTmpRecord, reform::Reformulation,
                          master_val, dual_sol, sp_lbs, sp_ubs)
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

function cg_main_loop(algdata::ColumnGenTmpRecord,
                      reformulation::Reformulation, 
                      phase::Int)::ColumnGenerationRecord
    setglobalstrategy!(reformulation, GlobalStrategy(SimpleBnP, SimpleBranching, DepthFirst))
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    masterform = reformulation.master
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    for spform in reformulation.dw_pricing_subprs
        sp_uid = getuid(spform)
        lb_convexity_constr_id = reformulation.dw_pricing_sp_lb[sp_uid]
        ub_convexity_constr_id = reformulation.dw_pricing_sp_ub[sp_uid]
        sp_lbs[sp_uid] = getcurrhs(getconstr(masterform, lb_convexity_constr_id))
        sp_ubs[sp_uid] = getcurrhs(getconstr(masterform, ub_convexity_constr_id))
    end

    while true
        master_status, master_val, primal_sols, dual_sols, master_time =
            solve_restricted_master!(masterform)

        if (phase != 1 && (master_status == MOI.INFEASIBLE
            || master_status == MOI.INFEASIBLE_OR_UNBOUNDED))
            @error "Solver returned that restricted master LP is infeasible or unbounded (status = $master_status) during phase != 1."
            return ColumnGenerationRecord(algdata.incumbents, true)
        end

        set_lp_primal_sol!(algdata.incumbents, primal_sols[1])
        set_lp_dual_sol!(algdata.incumbents, dual_sols[1])
        if isinteger(primal_sols[1]) && !contains(primal_sols[1], MasterArtVar)
            set_ip_primal_sol!(algdata.incumbents, primal_sols[1])
        end

        # TODO: cleanup restricted master columns        

        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_col = generatecolumns!(
                algdata, reformulation, master_val, dual_sols[1], sp_lbs, sp_ubs
            )
        end

        if nb_new_col < 0
            @error "Infeasible subproblem."
            return ColumnGenerationRecord(algdata.incumbents, true)
        end

        print_intermediate_statistics(
            algdata, nb_new_col, nb_cg_iterations, master_time, sp_time
        )

        # TODO: update colgen stabilization

        dual_bound = get_ip_dual_bound(algdata.incumbents)
        primal_bound = get_lp_primal_bound(algdata.incumbents)     
        cur_gap = gap(primal_bound, dual_bound)
        
        if phase == 1 && ph_one_infeasible_db(dual_bound)
            algdata.is_feasible = false
            @logmsg LogLevel(0) "Phase one determines infeasibility."
            return ColumnGenerationRecord(algdata.incumbents, true)
        end
        if nb_new_col == 0 || cur_gap < 0.00001 #_params_.relative_optimality_tolerance
            @logmsg LogLevel(0) "Column Generation Algorithm has converged." #nb_new_col cur_gap
            algdata.has_converged = true
            return ColumnGenerationRecord(algdata.incumbents, false)
        end
        if nb_cg_iterations > 1000 ##TDalgdata.max_nb_cg_iterations
            @warn "Maximum number of column generation iteration is reached."
            return ColumnGenerationRecord(algdata.incumbents, false)
        end
    end
    return ColumnGenerationRecord(algdata.incumbents, false)
end

function print_intermediate_statistics(algdata::ColumnGenTmpRecord,
                                       nb_new_col::Int,
                                       nb_cg_iterations::Int,
                                       mst_time::Float64, sp_time::Float64)
    mlp = getvalue(get_lp_primal_bound(algdata.incumbents))
    db = getvalue(get_ip_dual_bound(algdata.incumbents))
    pb = getvalue(get_ip_primal_bound(algdata.incumbents))
    @printf(
            "<it=%i> <et=%i> <mst=%.3f> <sp=%.3f> <cols=%i> <mlp=%.4f> <DB=%.4f> <PB=%.4f>\n",
            nb_cg_iterations, _elapsed_solve_time(), mst_time, sp_time, nb_new_col, mlp, db, pb
    )
end

struct ColumnGeneration <: AbstractAlgorithm end

mutable struct ColumnGenerationData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
end

function ColumnGenerationData(S::Type{<:AbstractObjSense}, node_inc::Incumbents)
    i = Incumbents(S)
    set_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    return ColumnGenerationData(i, false, true)
end

# Data needed for another round of column generation
mutable struct ColumnGenerationRecord <: AbstractAlgorithmRecord
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the algorithm's prepare function
function prepare!(::Type{ColumnGeneration}, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Prepare ColumnGeneration."
    return
end

function should_do_ph_1(cg_rec::ColumnGenerationRecord)
    primal_lp_sol = getsol(get_lp_primal_sol(cg_rec.incumbents))
    art_vars = filter(x->(getduty(x[2]) isa ArtificialDuty), primal_lp_sol)
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
        setcost!(master, v, 0.0)
    end
    return
end

function run!(::Type{ColumnGeneration}, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Run ColumnGeneration."
    algorithm_data = ColumnGenerationData(form.master.obj_sense, node.incumbents)
    cg_rec = cg_main_loop(algorithm_data, form, 2)
    if should_do_ph_1(cg_rec)
        record!(form, node)
        set_ph_one(form.master)
        cg_rec = cg_main_loop(algorithm_data, form, 1)
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
function update_pricing_problem!(sp_form::Formulation, dual_sol::DualSolution)

    master_form = sp_form.parent_formulation

    for (var_id, var) in filter(_active_pricing_sp_var_ , getvars(sp_form))
        setcost!(sp_form, var, computereducedcost(master_form, var_id, dual_sol))
    end

    return false
end

function update_pricing_target!(sp_form::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
end

function insert_cols_in_master!(master_form::Formulation,
                               sp_form::Formulation,
                               sp_sols::Vector{PrimalSolution{S}}) where {S}

    sp_uid = getuid(sp_form)
    nb_of_gen_col = 0

    for sp_sol in sp_sols
        if contrib_improves_mlp(getbound(sp_sol))
            nb_of_gen_col += 1
            ref = getvarcounter(master_form) + 1
            name = string("MC", sp_uid, "_", ref)
            resetsolvalue(master_form, sp_sol)
            lb = 0.0
            ub = Inf
            kind = Continuous
            duty = MasterCol
            sense = Positive
            mc = setprimalspsol!(
                master_form, name, sp_sol, duty; lb = lb, ub = ub,
                kind = kind, sense = sense
            )
            @logmsg LogLevel(-2) string("Generated column : ", name)

            # TODO: check if column exists
            #== mc_id = getid(mc)
            id_of_existing_mc = - 1
            partialsol_matrix = getpartialsolmatrix(master_form)
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

function compute_pricing_db_contrib(sp_form::Formulation,
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

function gencol!(master_form::Formulation,
                     sp_form::Formulation,
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
    update_pricing_target!(sp_form)

    # Reset var bounds, var cost, sp minCost
    if update_pricing_problem!(sp_form, dual_sol) # Never returns true
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
        opt_result = optimize!(sp_form)
    end

    pricing_db_contrib = compute_pricing_db_contrib(
        sp_form, getprimalbound(opt_result), sp_lb, sp_ub
    )
    # @show pricing_dual_bound_contrib

    if !isfeasible(opt_result)
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return flag_is_sp_infeasible
    end

    insertion_status = insert_cols_in_master!(
        master_form, sp_form, getprimalsols(opt_result)
    )

    return insertion_status, pricing_db_contrib
end

function gencols!(reformulation::Reformulation,
                  dual_sol::DualSolution{S},
                  sp_lbs::Dict{FormId, Float64},
                  sp_ubs::Dict{FormId, Float64}) where {S}

    nb_new_cols = 0
    dual_bound_contrib = DualBound{S}(0.0)
    master_form = getmaster(reformulation)
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)
        gen_status, contrib = gencol!(master_form, sp_form, dual_sol, sp_lbs[sp_uid], sp_ubs[sp_uid])

        if gen_status > 0
            nb_new_cols += gen_status
            dual_bound_contrib += float(contrib)
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, Inf)
        end
    end
    return (nb_new_cols, dual_bound_contrib)
end

function compute_master_db_contrib(alg::ColumnGenerationData,
                                   restricted_master_sol_value::PrimalBound{S}) where {S}
    # TODO: will change with stabilization
    return DualBound{S}(restricted_master_sol_value)
end

function update_lagrangian_db!(alg::ColumnGenerationData,
                               restricted_master_sol_value::PrimalBound{S},
                               pricing_sp_dual_bound_contrib::DualBound{S}) where {S}
    lagran_bnd = DualBound{S}(0.0)
    lagran_bnd += compute_master_db_contrib(alg, restricted_master_sol_value)
    lagran_bnd += pricing_sp_dual_bound_contrib
    set_ip_dual_bound!(alg.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_restricted_master!(master::Formulation)
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit _to "LP restricted master" optimize!(master)
    end
    return (isfeasible(opt_result), getprimalbound(opt_result), 
    getprimalsols(opt_result), getbestdualsol(opt_result), elapsed_time)
end

function generatecolumns!(alg::ColumnGenerationData, reform::Reformulation,
                          master_val, dual_sol, sp_lbs, sp_ubs)
    nb_new_columns = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_col, sp_db_contrib =  gencols!(reform, dual_sol, sp_lbs, sp_ubs)
        nb_new_columns += nb_new_col
        update_lagrangian_db!(alg, master_val, sp_db_contrib)
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

function cg_main_loop(alg::ColumnGenerationData, reformulation::Reformulation, 
                      phase::Int)
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    master_form = reformulation.master
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    for sp_form in reformulation.dw_pricing_subprs
        sp_uid = getuid(sp_form)
        lb_convexity_constr_id = reformulation.dw_pricing_sp_lb[sp_uid]
        ub_convexity_constr_id = reformulation.dw_pricing_sp_ub[sp_uid]
        sp_lbs[sp_uid] = getcurrhs(getconstr(master_form, lb_convexity_constr_id))
        sp_ubs[sp_uid] = getcurrhs(getconstr(master_form, ub_convexity_constr_id))
    end

    while true
        master_status, master_val, primal_sols, dual_sol, master_time =
            solve_restricted_master!(master_form)

        if (phase != 1 && (master_status == MOI.INFEASIBLE
            || master_status == MOI.INFEASIBLE_OR_UNBOUNDED))
            @error "Solver returned that restricted master LP is infeasible or unbounded (status = $master_status) during phase != 1."
            return ColumnGenerationRecord(alg.incumbents, true)
        end

        set_lp_primal_sol!(alg.incumbents, primal_sols[1])
        set_lp_dual_sol!(alg.incumbents, dual_sol)
        if isinteger(primal_sols[1])
            set_ip_primal_sol!(alg.incumbents, primal_sols[1])
        end

        # TODO: cleanup restricted master columns        

        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_col = generatecolumns!(
                alg, reformulation, master_val, dual_sol, sp_lbs, sp_ubs
            )
        end

        if nb_new_col < 0
            @error "Infeasible subproblem."
            return ColumnGenerationRecord(alg.incumbents, true)
        end

        print_intermediate_statistics(
            alg, nb_new_col, nb_cg_iterations, master_time, sp_time
        )

        # TODO: update colgen stabilization

        lb = get_ip_dual_bound(alg.incumbents)
        ub = min(
            get_lp_primal_bound(alg.incumbents), get_ip_primal_bound(alg.incumbents)
        )

        if phase == 1 && ph_one_infeasible_db(lb)
            alg.is_feasible = false
            @logmsg LogLevel(0) "Phase one determines infeasibility."
            return ColumnGenerationRecord(alg.incumbents, true)
        end
        if nb_new_col == 0 || diff(lb + 0.00001, ub) < 0
            alg.has_converged = true
            return ColumnGenerationRecord(alg.incumbents, false)
        end
        if nb_cg_iterations > 1000 ##TDalg.max_nb_cg_iterations
            @warn "Maximum number of column generation iteration is reached."
            return ColumnGenerationRecord(alg.incumbents, false)
        end
    end
    return ColumnGenerationRecord(alg.incumbents)
end

function print_intermediate_statistics(alg::ColumnGenerationData,
                                       nb_new_col::Int,
                                       nb_cg_iterations::Int,
                                       mst_time::Float64, sp_time::Float64)
    mlp = getvalue(get_lp_primal_bound(alg.incumbents))
    db = getvalue(get_ip_dual_bound(alg.incumbents))
    pb = getvalue(get_ip_primal_bound(alg.incumbents))
    @printf(
            "<it=%i> <et=%i> <mst=%.3f> <sp=%.3f> <cols=%i> <mlp=%.4f> <DB=%.4f> <PB=%.4f>\n",
            nb_cg_iterations, _elapsed_solve_time(), mst_time, sp_time, nb_new_col, mlp, db, pb
    )
end

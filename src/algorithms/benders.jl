struct BendersCutGeneration <: AbstractAlgorithm
    option_use_reduced_cost::Bool
end
BendersCutGeneration() = BendersCutGeneration(false)

mutable struct BendersCutGenerationData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    spform_phase::Dict{Int, FormulationPhase}
    spform_phase_applied::Dict{Int, Bool}
    #slack_cost_increase::Float64
    #slack_cost_increase_applied::Bool
end

function allphasesapplied(algdata::BendersCutGenerationData)
    for (key, applied) in algdata.spform_phase_applied
        !applied && return false
    end
    return true
end

function BendersCutGenerationData(S::Type{<:AbstractObjSense}, node_inc::Incumbents)
    i = Incumbents(S)
    set_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    
    return BendersCutGenerationData(i, false, true, Dict{FormId, FormulationPhase}(), Dict{FormId, Bool}())#0.0, true)
end

# Data needed for another round of column generation
struct BendersCutGenerationRecord <: AbstractAlgorithmRecord
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the solver interface
function prepare!(::Type{BendersCutGeneration}, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Prepare BendersCutGeneration."
    return
end

function run!(::Type{BendersCutGeneration}, form, node, strategy_rec, params)
    algdata = BendersCutGenerationData(form.master.obj_sense, node.incumbents)
    @logmsg LogLevel(-1) "Run BendersCutGeneration."
    Base.@time bend_rec = bend_cutting_plane_main_loop(algdata, form)
    set!(node.incumbents, bend_rec.incumbents)
    return bend_rec
end

function update_bendersep_slackvar_cost_for_ph1!(spform::Formulation)
    #==It is not enough to set cost 1 to mu var, the nu var needs to take cost 0 for a pure phase 1
    for (varid, var) in filter(_active_BendSpSlackFirstStage_var_, getvars(spform))
        setcurcost!(spform, var, 1.0)
    end
==#
    for (var_id, var) in filter(_active_ , getvars(spform))
        if getduty(var) == BendSpSlackFirstStageVar
            setcurcost!(sp_form, var, 1.0)
        else
            setcurcost!(sp_form, var, 0.0)
        end
    end
    return
end

update_bendersep_slackvar_cost_for_ph2!(spform::Formulation) = return

function update_bendersep_slackvar_cost_for_hyb_ph!(spform::Formulation)
    for (varid, var) in filter(_active_, getvars(spform))
        setcurcost!(spform, var, getperenecost(spform, var))
    end
    return
end

function update_bendersep_problem!(
    algdata::BendersCutGenerationData, spform::Formulation, 
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}
) where {S}
    masterform = spform.parent_formulation

    spform_uid = getuid(spform)
    phase_applied = algdata.spform_phase_applied[spform_uid]
    if !phase_applied
        phase_to_apply = algdata.spform_phase[spform_uid]
        if phase_to_apply == PurePhase1
            update_bendersep_slackvar_cost_for_ph1!(spform)
        elseif phase_to_apply == HybridPhase
            update_bendersep_slackvar_cost_for_hybph!(spform)
        end
        algdata.spform_phase_applied[spform_uid] = true
    end
    
    # Update rhs of technological constraints
    for (constrid, constr) in filter(_active_BendSpMaster_constr_ , getconstrs(spform))
        setcurrhs!(spform, constr, computereducedrhs(spform, constrid, master_primal_sol))
    end
    
    # Update bounds on slack var "BendSpSlackFirstStageVar"
    cursol = getsol(master_primal_sol)
    for (varid, var) in filter(_active_BendSpSlackFirstStage_var_ , getvars(spform))
        if haskey(cursol, varid)
            #setcurlb!(var, getperenelb(var) - cur_sol[var_id])
            setcurub!(var, getpereneub(var) - cursol[varid])
        end
        
    end

    #option_use_reduced_cost = false

    # if option_use_reduced_cost
    #     for (var_id, var) in filter(_active_BendSpSlackFirstStage_var_ , getvars(sp_form))
    #         cost = getcurcost(var)
    #         #@show getname(var) cost
    #         rc = computereducedcost(master_form, var_id, master_dual_sol)
    #         #@show getname(var) rc
    #         setcurcost!(sp_form, var, rc)
    #     end
    # end

    return false

end


function update_bendersep_target!(sp_form::Formulation)
    # println("bendersep target will only be needed after automating convexity constraints")
end


function insert_cuts_in_master!(master_form::Formulation,
                                sp_form::Formulation,
                                spresult::OptimizationResult{S}) where {S}
    
    primal_sols = getprimalsols(spresult)
    dual_sols = getdualsols(spresult)
    sp_uid = getuid(sp_form)
    nb_of_gen_cuts = 0
    sense = (S == MinSense ?  Greater : Less)

    N = length(dual_sols)
    if length(primal_sols) < N
        N = length(primal_sols)
    end
    
    for k in 1:N
        primal_sol = primal_sols[k]
        dual_sol = dual_sols[k]
        # the solution value represent the cut violation at this stage
        if getvalue(dual_sol) > 0.0001 # TODO the cut feasibility tolerance
            nb_of_gen_cuts += 1
            ref = getconstrcounter(master_form) + 1
            name = string("BC", sp_uid, "_", ref)
            resetsolvalue(sp_form, dual_sol) # now the sol value represents the dual sol value
            kind = Core
            duty = MasterBendCutConstr
            bc = setprimaldualbendspsol!(
                master_form, sp_form, name, primal_sol, dual_sol, duty; 
                kind = kind, sense = sense)
          
            @logmsg LogLevel(-2) string("Generated cut : ", name)
            #@show bc

            # TODO: check if cut exists
            #== mc_id = getid(mc)
            id_of_existing_mc = - 1
            primalspsol_matrix = getprimaldwspsolmatrix(master_form)
            for (col, col_members) in columns(primalspsol_matrix)
                if (col_members == primalspsol_matrix[:, mc_id])
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

    return nb_of_gen_cuts
end

function compute_bendersep_pb_contrib(
    algdata::BendersCutGenerationData, spform::Formulation, spsol::OptimizationResult{S}
) where {S}
    dualsol = getbestdualsol(spsol)
    contrib = getvalue(dualsol)

        #== primalsol = getsol(getbestprimalsol(spsol))
    for (var, value) in filter(var -> getduty(var) <: BendSpSlackFirstStageVar, primalsol)
        contrib -= alg.slack_cost_increase * value
    end    
   if -1e-5 <= contrib <= 1e-5
        alg.slack_cost_increase += 1
        alg.slack_cost_increase_applied = false
    end
==#
    return contrib
end

function solve_sp_to_gencut!(
    algdata::BendersCutGenerationData, masterform::Formulation, 
    spform::Formulation, master_primal_sol::PrimalSolution{S},
    master_dual_sol::DualSolution{S}
) where {S}

    flag_is_sp_infeasible = -1

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_cut(sp_form)
    #     return flag_cannot_generate_more_cut
    # end

    # Compute target
    update_bendersep_target!(spform)

    # Reset var bounds, var cost, sp minCost
    if update_bendersep_problem!(algdata, spform, master_primal_sol, master_dual_sol) # Never returns true
        #     This code is never executed because update_bendersep_prob always returns false
        #     @logmsg LogLevel(-3) "bendersep prob is infeasible"
        #     # In case one of the subproblem is infeasible, the master is infeasible
        #     compute_bendersep_primal_bound_contrib(alg, bendersep_prob)
        #     return flag_is_sp_infeasible
    end

    # if alg.bendcutgen_stabilization != nothing && true #= TODO add conds =#
    #     # switch off the reduced cost estimation when stabilization is applied
    # end

    # Solve sub-problem and insert generated cuts in master
    # @logmsg LogLevel(-3) "optimizing bendersep prob"
    TO.@timeit _to "Bender Sep SubProblem" begin
        optresult = optimize!(spform)
    end
    
    bendersep_pb_contrib = compute_bendersep_pb_contrib(algdata, spform, optresult)
    # @show bendersep_primal_bound_contrib
    
    if !isfeasible(optresult) # if status != MOI.OPTIMAL
        # @logmsg LogLevel(-3) "bendersep prob is infeasible"
        return flag_is_sp_infeasible
    end

    primalsol = getbestprimalsol(optresult)
    spsol_relaxed = contains(primalsol, BendSpSlackFirstStageVar)

    primal_bound_correction = 0.0

    if spsol_relaxed      
        if -1e-5 <= getprimalbound(optresult) <= 1e-5
            spform_uid = getuid(spform)
            algdata.spform_phase[spform_uid] = PurePhase1
            algdata.spform_phase_applied[spform_uid] = false

            # TODO : rerun the subproblem here with the modification. (split this method)
        else
            for (var, value) in filter(var -> getduty(var) <: BendSpSlackFirstStageVar, getsol(primalsol))
                if S == MinSense
                    primal_bound_correction += value
                else
                    primal_bound_correction -= value
                end
            end
        end
    end
    
    insertion_status = insert_cuts_in_master!(masterform, spform, optresult)
    
    return insertion_status, spsol_relaxed, primal_bound_correction, bendersep_pb_contrib
end

function solve_sps_to_gencuts!(
    algdata::BendersCutGenerationData, reform::Reformulation, 
    primalsol::PrimalSolution{S}, dualsol::DualSolution{S}
) where {S}
    nb_new_cuts = 0
    spsols_relaxed = false
    total_pb_correction = 0.0
    total_pb_contrib = 0.0
    masterform = getmaster(reform)
    sps = get_benders_sep_sp(reform)
    for spform in sps
        gen_status, spsol_relaxed, pb_correction, pb_contrib =
            solve_sp_to_gencut!(algdata, masterform, spform, primalsol, dualsol)

        spsols_relaxed |= spsol_relaxed
        total_pb_correction += pb_correction
        total_pb_contrib += pb_contrib
        
        if gen_status > 0
            nb_new_cuts += gen_status
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, false, 0.0, 0.0) # TODO : correct those numbers
        end
        # TODO : here gen_status = 0 ???
    end
    if spsols_relaxed
        total_pb_correction = defaultprimalboundvalue(S)
    end
    return (nb_new_cuts, spsols_relaxed, total_pb_correction, total_pb_contrib)
end


function compute_master_pb_contrib(algdata::BendersCutGenerationData,
                                   restricted_master_sol_value::DualBound{S}) where {S}
    # TODO: will change with stabilization
    return PrimalBound{S}(restricted_master_sol_value)
end

function update_lagrangian_pb!(algdata::BendersCutGenerationData,
                               restricted_master_sol_dual_sol::DualSolution{S},
                               bendersep_sp_primal_bound_contrib) where {S}
    restricted_master_sol_value = getbound(restricted_master_sol_dual_sol)
    lagran_bnd = PrimalBound{S}(0.0)
    lagran_bnd += compute_master_pb_contrib(algdata, restricted_master_sol_value)
    lagran_bnd += bendersep_sp_primal_bound_contrib
    set_lp_primal_bound!(algdata.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_relaxed_master!(master::Formulation)
    #@show "function solve_relaxed_master!(master::Formulation)"
    elapsed_time = @elapsed begin
        optresult = TO.@timeit _to "relaxed master" optimize!(master)
    end
    #@show optresult
    return optresult, elapsed_time
end

function generatecuts!(
    algdata::BendersCutGenerationData, reform::Reformulation,
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}
)::Tuple{Int, Bool} where {S}
    master_form = reform.master
    
    masterpureconstr = constr -> getduty(constr) == MasterPureConstr
    filtered_dual_sol = filter(masterpureconstr, master_dual_sol)

    ## TODO stabilization : move the following code inside a loop
    nb_new_cuts, spsols_relaxed, pb_correction, sp_pb_contrib =
        solve_sps_to_gencuts!(
            algdata, reform, master_primal_sol, filtered_dual_sol
        )
    update_lagrangian_pb!(algdata, master_dual_sol, sp_pb_contrib)
    if nb_new_cuts < 0
        # subproblem infeasibility leads to master infeasibility
        return (-1, false)
    end
    # end TODO

    setvalue!(master_primal_sol, getvalue(master_primal_sol) + pb_correction)
    return nb_new_cuts, spsols_relaxed
end

function bend_cutting_plane_main_loop(
    algdata::BendersCutGenerationData, reform::Reformulation,
)::BendersCutGenerationRecord

    nb_bc_iterations = 0
    master_form = getmaster(reform)

    for spform in get_benders_sep_sp(reform)
        spform_uid = getuid(spform) 
        algdata.spform_phase[spform_uid] = HybridPhase
        algdata.spform_phase_applied[spform_uid] = true
    end

    while true
        optresult, master_time = solve_relaxed_master!(master_form)

        if getfeasibilitystatus(optresult) == INFEASIBLE
            sense = getobjsense(master_form)
            db = - DualBound{sense}()
            pb = - PrimalBound{sense}()
            set_lp_dual_bound!(algdata.incumbents, db)
            set_lp_primal_bound!(algdata.incumbents, pb)
            return BendersCutGenerationRecord(algdata.incumbents, true)
        end
           
        master_dual_sol = getbestdualsol(optresult)
        master_primal_sol = getbestprimalsol(optresult)

        if !isfeasible(optresult) || master_primal_sol == nothing || master_dual_sol == nothing
            error("Benders algorithm:  the relaxed master LP is infeasible or unboundedhas no solution.")
            return BendersCutGenerationRecord(algdata.incumbents, true)
        end

        set_lp_dual_sol!(algdata.incumbents, master_dual_sol)
        dual_bound = get_lp_dual_bound(algdata.incumbents)
        
        # TODO: cleanup restricted master columns        

        nb_bc_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_cuts, one_spsol_is_a_relaxed_sol =
                generatecuts!(
                    algdata, reform, master_primal_sol, master_dual_sol
                )
        end
        #@show nb_new_cuts, one_spsol_is_a_relaxed_sol, primal_bound_correction

        if nb_new_cuts < 0
            @error "infeasible subproblem."
            return BendersCutGenerationRecord(algdata.incumbents, true)
        end

        # TODO: update bendcutgen stabilization

        if  !one_spsol_is_a_relaxed_sol
            set_lp_primal_sol!(algdata.incumbents, master_primal_sol)
            primal_bound = get_lp_primal_bound(algdata.incumbents)
            #@show primal_bound
            cur_gap = gap(primal_bound, dual_bound)

            # TODO : replace with isinteger(master_primal_sol)  # ISSUE 179
            sol_integer = true
            for (var, val) in filter(var -> getperenekind(var) != Continuous, getsol(master_primal_sol))
                if !isinteger(val)
                    sol_integer = false
                    break
                end
            end
            if sol_integer
                set_ip_primal_sol!(algdata.incumbents, master_primal_sol)
            end
        end

        print_intermediate_statistics(
            algdata, nb_new_cuts, nb_bc_iterations, master_time, sp_time
        )

        if nb_new_cuts == 0 && allphasesapplied(algdata)
            #@show "Benders Speration Algorithm has converged." nb_new_cut cur_gap
            algdata.has_converged = true
            break
        end
        
        primal_bound = get_lp_primal_bound(algdata.incumbents)
        cur_gap = gap(primal_bound, dual_bound)
        if cur_gap < 0.00001
            println("Should stop because pb = $primal_bound & db = $dual_bound")
            # TODO : problem with the gap
            #break
        end
        
        if nb_bc_iterations >= 100 #algdata.max_nb_bc_iterations
            @warn "Maximum number of cut generation iteration is reached."
            algdata.is_feasible = false
            break
        end
    end

    return BendersCutGenerationRecord(algdata.incumbents, false)
end

function print_intermediate_statistics(algdata::BendersCutGenerationData,
                                       nb_new_cut::Int,
                                       nb_bc_iterations::Int,
                                       mst_time::Float64, sp_time::Float64)
    mlp = getvalue(get_lp_dual_bound(algdata.incumbents))
    db = getvalue(get_ip_dual_bound(algdata.incumbents))
    pb = getvalue(get_ip_primal_bound(algdata.incumbents))
    @printf(
            "<it=%i> <et=%i> <mst=%.3f> <sp=%.3f> <cuts=%i> <mlp=%.4f> <DB=%.4f> <PB=%.4f>\n",
            nb_bc_iterations, _elapsed_solve_time(), mst_time, sp_time, nb_new_cut, mlp, db, pb
    )
end

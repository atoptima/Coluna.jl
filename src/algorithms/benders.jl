Base.@kwdef struct BendersCutGeneration <: AbstractAlgorithm
    option_use_reduced_cost::Bool = false
    option_increase_cost_in_hybrid_phase::Bool = false
    feasibility_tol::Float64 = 1e-5
    optimality_tol::Float64 = 1e-5
    max_nb_iterations::Int = 100
end

#BendersCutGeneration() = BendersCutGeneration(false)

mutable struct BendersCutGenTmpRecord <: AbstractAlgorithmTmpRecord
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    spform_phase::Dict{Int, FormulationPhase}
    spform_phase_applied::Dict{Int, Bool}
    #slack_cost_increase::Float64
    #slack_cost_increase_applied::Bool
end

function allphasesapplied(algdata::BendersCutGenTmpRecord)
    for (key, applied) in algdata.spform_phase_applied
        !applied && return false
    end
    return true
end

function all_sp_in_phase2(algdata::BendersCutGenTmpRecord)
    for (key, phase) in algdata.spform_phase
        phase != PurePhase2 && return false
    end
    return true
end

function BendersCutGenTmpRecord(S::Type{<:AbstractObjSense}, node_inc::Incumbents)
    i = Incumbents(S)
    set_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    
    return BendersCutGenTmpRecord(i, false, true, Dict{FormId, FormulationPhase}(), Dict{FormId, Bool}())#0.0, true)
end

# Data needed for another round of column generation
struct BendersCutGenerationRecord <: AbstractAlgorithmResult
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the solver interface
function prepare!(algo::BendersCutGeneration, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Prepare BendersCutGeneration."
    return
end

function run!(algo::BendersCutGeneration, form, node, strategy_rec, params)
    algdata = BendersCutGenTmpRecord(form.master.obj_sense, node.incumbents)
    @logmsg LogLevel(-1) "Run BendersCutGeneration."
    Base.@time bend_rec = bend_cutting_plane_main_loop(algo, algdata, form)
    set!(node.incumbents, bend_rec.incumbents)
    return bend_rec
end

function update_bendersep_slackvar_cost_for_ph1!(spform::Formulation)
    for (varid, var) in filter(_active_ , getvars(spform))
        if getduty(var) == BendSpSlackFirstStageVar
            setcurcost!(spform, var, 1.0)
        else
            setcurcost!(spform, var, 0.0)
        end
        # TODO if previous phase is  a pure phase 2, reset current ub
    end
    return
end

function update_bendersep_slackvar_cost_for_ph2!(spform::Formulation) 
    for (varid, var) in filter(_active_ , getvars(spform))
        if getduty(var) == BendSpSlackFirstStageVar
            setcurcost!(spform, var, 0.0)
            setub!(spform, var, 0.0)
        else
            setcurcost!(spform, var, getperenecost(var))
        end
        @show "phase2" var
    end
    return
end

function update_bendersep_slackvar_cost_for_hyb_ph!(spform::Formulation)
    for (varid, var) in filter(_active_, getvars(spform))
        setcurcost!(spform, var, getperenecost(var))
        # TODO if previous phase is  a pure phase 2, reset current ub
    end
    return
end

function update_bendersep_problem!(
    algo::BendersCutGeneration, algdata::BendersCutGenTmpRecord, spform::Formulation, 
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}
) where {S}
    masterform = spform.parent_formulation

     
    # Update rhs of technological constraints
    for (constrid, constr) in filter(_active_BendSpMaster_constr_ , getconstrs(spform))
        setcurrhs!(spform, constr, computereducedrhs(spform, constrid, master_primal_sol))
    end
    
    # Update bounds on slack var "BendSpSlackFirstStageVar"
    cursol = getsol(master_primal_sol)
    for (varid, var) in filter(_active_BendSpSlackFirstStage_var_ , getvars(spform))
        if haskey(cursol, varid)
            #setcurlb!(var, getperenelb(var) - cur_sol[var_id])
            setub!(spform, var, getpereneub(var) - cursol[varid])
        end
    end

    if algo.option_use_reduced_cost
        for (var_id, var) in filter(_active_BendSpSlackFirstStage_var_ , getvars(spform))
            cost = getcurcost(var)
            #@show getname(var) cost
            rc = computereducedcost(masterform, var_id, master_dual_sol)
            #@show getname(var) rc
            setcurcost!(spform, var, rc)
        end
    end

    return false

end

function update_bendersep_phase!(
    algo::BendersCutGeneration, algdata::BendersCutGenTmpRecord, spform::Formulation
) 

    # Update objective function
    spform_uid = getuid(spform)
    phase_applied = algdata.spform_phase_applied[spform_uid]
    if !phase_applied
        phase_to_apply = algdata.spform_phase[spform_uid]
        if phase_to_apply == HybridPhase
            update_bendersep_slackvar_cost_for_hyb_ph!(spform)
        elseif phase_to_apply == PurePhase1
            update_bendersep_slackvar_cost_for_ph1!(spform)
        elseif phase_to_apply == PurePhase2
            update_bendersep_slackvar_cost_for_ph2!(spform)
        end
        algdata.spform_phase_applied[spform_uid] = true
    end
    

    return false

end


function update_bendersep_target!(spform::Formulation)
    # println("bendersep target will only be needed after automating convexity constraints")
end


function insert_cuts_in_master!(algdata, masterform::Formulation,
                                spform::Formulation,
                                spresult::OptimizationResult{S}) where {S}
    primal_sols = getprimalsols(spresult)
    dual_sols = getdualsols(spresult)
    sp_uid = getuid(spform)
    nb_of_gen_cuts = 0
    sense = (S == MinSense ? Greater : Less)

    N = length(dual_sols)
    if length(primal_sols) < N
        N = length(primal_sols)
    end
    
    for k in 1:N
        primal_sol = primal_sols[k]
        dual_sol = dual_sols[k]
        # the solution value represent the cut violation at this stage
        if getvalue(dual_sol) > 0.0001 || algdata.spform_phase[getuid(spform)] == PurePhase1 # TODO the cut feasibility tolerance
            nb_of_gen_cuts += 1
            ref = getconstrcounter(masterform) + 1
            name = string("BC", sp_uid, "_", ref)
            resetsolvalue(spform, dual_sol) # now the sol value represents the dual sol value
            kind = Core
            duty = MasterBendCutConstr
            bc = setprimaldualbendspsol!(
                masterform, spform, name, primal_sol, dual_sol, duty; 
                kind = kind, sense = sense
            )
          
            @logmsg LogLevel(-2) string("Generated cut : ", name)
            #@show bc

            # TODO: check if cut exists
            #== mc_id = getid(mc)
            id_of_existing_mc = - 1
            primalspsol_matrix = getprimaldwspsolmatrix(masterform)
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

function compute_bendsp_lagrangian_bound_contrib(
    algdata::BendersCutGenTmpRecord, spform::Formulation, spsol::OptimizationResult{S}
) where {S}
    dualsol = getbestdualsol(spsol)
    contrib = getvalue(dualsol)
    return contrib
end

function solve_sp_to_gencut!(
    algo::BendersCutGeneration, algdata::BendersCutGenTmpRecord, masterform::Formulation, 
    spform::Formulation, master_primal_sol::PrimalSolution{S},
    master_dual_sol::DualSolution{S}, phase::FormulationPhase
) where {S}

    flag_is_sp_infeasible = -1

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_cut(spform)
    #     return flag_cannot_generate_more_cut
    # end

    spform_uid = getuid(spform)
    bendsp_primal_bound_contrib = 0.0
    insertion_status = 0
    spsol_relaxed = false
    bendsp_lagrangian_bound_contrib =  0.0
    
    # Reset to  separation phase
    if algdata.spform_phase[spform_uid] != phase
        algdata.spform_phase_applied[spform_uid] = false
        algdata.spform_phase[spform_uid] = phase
    end

    # Compute target
    update_bendersep_target!(spform)

    # Reset var bounds, constr rhs
    if update_bendersep_problem!(algo, algdata, spform, master_primal_sol, master_dual_sol) # Never returns true
        #     This code is never executed because update_bendersep_prob always returns false
        #     @logmsg LogLevel(-3) "bendersep prob is infeasible"
        #     # In case one of the subproblem is infeasible, the master is infeasible
        #     compute_bendersep_primal_bound_contrib(alg, bendersep_prob)
        #     return flag_is_sp_infeasible
    end

    while true

        update_bendersep_phase!(algo, algdata, spform)
                # if alg.bendcutgen_stabilization != nothing && true #= TODO add conds =#
        #     # switch off the reduced cost estimation when stabilization is applied
        # end

        @show algdata.spform_phase[spform_uid]
        
        # Solve sub-problem and insert generated cuts in master
        # @logmsg LogLevel(-3) "optimizing bendersep prob"
        TO.@timeit _to "Bender Sep SubProblem" begin
            optresult = optimize!(spform)
        end

        if !isfeasible(optresult) # if status != MOI.OPTIMAL
            # @logmsg LogLevel(-3) "bendersep prob is infeasible"
            return flag_is_sp_infeasible
        end

        bendsp_lagrangian_bound_contrib = compute_bendsp_lagrangian_bound_contrib(algdata, spform, optresult)

        primalsol = getbestprimalsol(optresult)
        spsol_relaxed = contains(primalsol, BendSpSlackFirstStageVar)

        bendsp_primal_bound_contrib = 0.0
        # compute bendsp_primal_bound_contrib which stands for the sum of nu var,
        # i.e. the second stage cost as it would appear as 
        # the separation subproblem objective in a pure phase 2
        for (var, value) in filter(var -> getduty(var) <: BendSpSlackSecondStageCostVar, getsol(primalsol))
            if S == MinSense
                bendsp_primal_bound_contrib += value
            else
                bendsp_primal_bound_contrib -= value
            end
        end
        @show bendsp_primal_bound_contrib
        
        if - algo.feasibility_tol <= getprimalbound(optresult) <= algo.feasibility_tol
        # no cuts are generated since there is no violation 
            if spsol_relaxed
                if algdata.spform_phase[spform_uid] == PurePhase2
                    @show "ERROR : in PurePhase2, art var were not supposed to be in sp forlumation "
                    break
                end
                if algdata.spform_phase[spform_uid] == PurePhase1
                    @show "ERROR : in PurePhase1, if art var were in sol, the objective should be strictly positive "
                    break
                end
                # algdata.spform_phase[spform_uid] == HybridPhase
                algdata.spform_phase[spform_uid] = PurePhase1
                algdata.spform_phase_applied[spform_uid] = false
                continue
            else
                if algdata.spform_phase[spform_uid] != PurePhase1
                    # no more cut to generate
                    break
                else #  one more phase to try
                    algdata.spform_phase[spform_uid] = PurePhase2
                    algdata.spform_phase_applied[spform_uid] = false
                    continue
                end             
            end
            
        else # a cut can be generated since there is a violation
            insertion_status = insert_cuts_in_master!(algdata, masterform, spform, optresult)
            if spsol_relaxed &&  algo.option_increase_cost_in_hybrid_phase
                #check algdata.spform_phase[spform_uid] == HybridPhase
                # Todo increase cost
                #continue
            end
            break
        end
    end
    return insertion_status, spsol_relaxed, bendsp_primal_bound_contrib, bendsp_lagrangian_bound_contrib
end

        
 #==       if spsol_relaxed
            if - feasibility_tol <= getprimalbound(optresult) <= feasibility_tol
                spform_uid = getuid(spform)
                algdata.spform_phase[spform_uid] = PurePhase1
                algdata.spform_phase_applied[spform_uid] = false
                continue
            else
                for (var, value) in filter(var -> getduty(var) <: BendSpSlackFirstStageVar, getsol(primalsol))
                    if S == MinSense
                        bendsp_primal_bound_contrib += value
                    else
                        bendsp_primal_bound_contrib -= value
                    end
                end
            end
        end
        insertion_status = insert_cuts_in_master!(algdata, masterform, spform, optresult)
       
        if !spsol_relaxed && -1e-5 <= getprimalbound(optresult) <= 1e-5
            spform_uid = getuid(spform)
            if algdata.spform_phase[spform_uid] == PurePhase1
                algdata.spform_phase_applied[spform_uid] = false
                algdata.spform_phase[spform_uid] = HybridPhase
            end
        end
        
        return insertion_status, spsol_relaxed, bendsp_primal_bound_contrib, bendsp_lagrangian_bound_contrib
    end
    return
==#

function solve_sps_to_gencuts!(
    algo::BendersCutGeneration, algdata::BendersCutGenTmpRecord, reform::Reformulation, 
    primalsol::PrimalSolution{S}, dualsol::DualSolution{S}, phase::FormulationPhase
) where {S}
    nb_new_cuts = 0
    spsols_relaxed = false
    total_pb_correction = 0.0
    total_pb_contrib = 0.0
    masterform = getmaster(reform)
    sps = get_benders_sep_sp(reform)
    for spform in sps
        gen_status, spsol_relaxed, bendsp_primal_bound_contrib, bendsp_lagrangian_bound_contrib =
            solve_sp_to_gencut!(algo, algdata, masterform, spform, primalsol, dualsol, phase)

        spsols_relaxed |= spsol_relaxed
        total_pb_correction += bendsp_primal_bound_contrib
        total_pb_contrib += bendsp_lagrangian_bound_contrib
        
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


function compute_master_pb_contrib(algdata::BendersCutGenTmpRecord,
                                   restricted_master_sol_value::DualBound{S}) where {S}
    # TODO: will change with stabilization
    return PrimalBound{S}(restricted_master_sol_value)
end

function update_lagrangian_pb!(algdata::BendersCutGenTmpRecord,
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
    algo::BendersCutGeneration, algdata::BendersCutGenTmpRecord, reform::Reformulation,
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}, phase::FormulationPhase
)::Tuple{Int, Bool, PrimalBound{S}} where {S}
    masterform = reform.master
    
    masterpureconstr = constr -> getduty(constr) == MasterPureConstr
    filtered_dual_sol = filter(masterpureconstr, master_dual_sol)

    ## TODO stabilization : move the following code inside a loop
    nb_new_cuts, spsols_relaxed, pb_correction, sp_pb_contrib =
        solve_sps_to_gencuts!(
            algo, algdata, reform, master_primal_sol, filtered_dual_sol, phase
        )
    update_lagrangian_pb!(algdata, master_dual_sol, sp_pb_contrib)
    if nb_new_cuts < 0
        # subproblem infeasibility leads to master infeasibility
        return (-1, false)
    end
    # end TODO
    primal_bound = PrimalBound{S}(getvalue(master_primal_sol) + pb_correction)
    #setvalue!(master_primal_sol, getvalue(master_primal_sol) + pb_correction)
    return nb_new_cuts, spsols_relaxed, primal_bound
end

function bend_cutting_plane_main_loop(
    algo::BendersCutGeneration, algdata::BendersCutGenTmpRecord, reform::Reformulation,
)::BendersCutGenerationRecord

    nb_bc_iterations = 0
    masterform = getmaster(reform)

    for spform in get_benders_sep_sp(reform)
        spform_uid = getuid(spform) 
        algdata.spform_phase[spform_uid] = HybridPhase
        algdata.spform_phase_applied[spform_uid] = true
    end
 

    while true # loop on master solution
        nb_new_cuts = 0
        cur_gap = 0.0
        
        optresult, master_time = solve_relaxed_master!(masterform)

        if getfeasibilitystatus(optresult) == INFEASIBLE
            sense = getobjsense(masterform)
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
        @show dual_bound
        
                

        phase = HybridPhase

        while true # loop on separation phases
            
            nb_bc_iterations += 1

            # generate new cuts by solving the subproblems
            sp_time = @elapsed begin
                nb_new_cuts, one_spsol_is_a_relaxed_sol, primal_bound  =
                    generatecuts!(
                        algo, algdata, reform, master_primal_sol, master_dual_sol, phase
                    )
            end
            @show nb_new_cuts, one_spsol_is_a_relaxed_sol, primal_bound

            if nb_new_cuts < 0
                @error "infeasible subproblem."
                return BendersCutGenerationRecord(algdata.incumbents, true)
            end

            # TODO: update bendcutgen stabilization
            set_lp_primal_sol!(algdata.incumbents, master_primal_sol)
            set_lp_primal_bound!(algdata.incumbents, primal_bound)
            cur_gap = gap(primal_bound, dual_bound)

            if !one_spsol_is_a_relaxed_sol                
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
                    set_ip_primal_bound!(algdata.incumbents, primal_bound)
                end
            end

            print_intermediate_statistics(
                algdata, nb_new_cuts, nb_bc_iterations, master_time, sp_time
            )
            
            if nb_new_cuts > 0
                @show " cuts have been found"
                break # loop on separation phases
            else # nb_new_cuts == 0
                if phase == HybridPhase
                    phase = PurePhase1
                    continue
                else
                    break # loop on separation phases
                end               
            end
            
            
            
            if cur_gap < algo.optimality_tol
                println("Should stop because pb = $primal_bound & db = $dual_bound")
                # TODO : problem with the gap
                 break # loop on separation phases
            end
            
            if nb_bc_iterations >= algo.max_nb_iterations
                @warn "Maximum number of cut generation iteration is reached."
                algdata.is_feasible = false
                break # loop on separation phases
            end
            
        end # loop on separation phases
        
        if cur_gap < algo.optimality_tol
            break # loop on master lp solution 
        end
        
        if nb_bc_iterations >= algo.max_nb_iterations
            @warn "Maximum number of cut generation iteration is reached."
            algdata.is_feasible = false
            break # loop on master lp solution 
        end
        
        if nb_new_cuts == 0 
            @show "Benders Speration Algorithm has converged." nb_new_cut cur_gap
            algdata.has_converged = true
            break # loop on master lp solution          
        end
        
    end  # loop on master lp solution 

    return BendersCutGenerationRecord(algdata.incumbents, false)
end

function print_intermediate_statistics(algdata::BendersCutGenTmpRecord,
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

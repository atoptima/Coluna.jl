Base.@kwdef struct BendersCutGeneration <: AbstractAlgorithm
    option_use_reduced_cost::Bool = false
    option_increase_cost_in_hybrid_phase::Bool = false
    feasibility_tol::Float64 = 1e-5
    optimality_tol::Float64 = 1e-5
    max_nb_iterations::Int = 100
end

mutable struct BendersCutGenData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    spform_phase::Dict{Int, FormulationPhase}
    spform_phase_applied::Dict{Int, Bool}
    #slack_cost_increase::Float64
    #slack_cost_increase_applied::Bool
end

function all_sp_in_phase2(algdata::BendersCutGenData)
    for (key, phase) in algdata.spform_phase
        phase != PurePhase2 && return false
    end
    return true
end

function BendersCutGenData(S::Type{<:Coluna.AbstractSense}, node_inc::Incumbents)
    i = Incumbents(S)
    update_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    
    return BendersCutGenData(i, false, true, Dict{FormId, FormulationPhase}(), Dict{FormId, Bool}())#0.0, true)
end

# Data needed for another round of column generation
struct BendersCutGenerationRecord <: AbstractAlgorithmResult
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the solver interface
function prepare!(algo::BendersCutGeneration, form, node)
    @logmsg LogLevel(-1) "Prepare BendersCutGeneration."
    return
end

function run!(algo::BendersCutGeneration, form, node)
    algdata = BendersCutGenData(form.master.obj_sense, node.incumbents)
    @logmsg LogLevel(-1) "Run BendersCutGeneration."
    Base.@time bend_rec = bend_cutting_plane_main_loop(algo, algdata, form)
    update!(node.incumbents, bend_rec.incumbents)
    return bend_rec
end

function update_benders_sp_slackvar_cost_for_ph1!(spform::Formulation)
    for (varid, var) in getvars(spform)
        getcurisactive(spform, varid) || continue
        if getduty(varid) == BendSpSlackFirstStageVar
            setcurcost!(spform, var, 1.0)
        else
            setcurcost!(spform, var, 0.0)
        end
        # TODO if previous phase is  a pure phase 2, reset current ub
    end
    return
end

function update_benders_sp_slackvar_cost_for_ph2!(spform::Formulation) 
    for (varid, var) in getvars(spform)
        getcurisactive(spform, varid) || continue
        if getduty(varid) == BendSpSlackFirstStageVar
            setcurcost!(spform, var, 0.0)
            setcurub!(spform, var, 0.0)
        else
            setcurcost!(spform, var, getperenecost(spform, var))
        end
    end
    return
end

function update_benders_sp_slackvar_cost_for_hyb_ph!(spform::Formulation)
    for (varid, var) in getvars(spform)
        getcurisactive(spform, varid) || continue
        setcurcost!(spform, var, getperenecost(spform, var))
        # TODO if previous phase is  a pure phase 2, reset current ub
    end
    return
end

function update_benders_sp_problem!(
    algo::BendersCutGeneration, algdata::BendersCutGenData, spform::Formulation, 
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}
) where {S}
    masterform = spform.parent_formulation

     # Update rhs of technological constraints
    for (constrid, constr) in getconstrs(spform)
        getcurisactive(spform, constrid) || continue
        getduty(constrid) <= AbstractBendSpMasterConstr || continue
        setcurrhs!(spform, constr, computereducedrhs(spform, constrid, master_primal_sol))
    end
    
    # Update bounds on slack var "BendSpSlackFirstStageVar"
    for (varid, var) in getvars(spform)
        getcurisactive(spform, varid) || continue
        getduty(varid) <= BendSpSlackFirstStageVar || continue
        if haskey(master_primal_sol, varid)
            #setcurlb!(var, getperenelb(var) - cur_sol[varid])
            setcurub!(spform, var, getpereneub(spform, var) - master_primal_sol[varid])
        end
    end

    if algo.option_use_reduced_cost
        for (varid, var) in getvars(spform)
            getcurisactive(spform, varid) || continue
            getduty(varid) <= BendSpSlackFirstStageVar || continue
            cost = getcurcost(spform, var)
            rc = computereducedcost(masterform, varid, master_dual_sol)
            setcurcost!(spform, var, rc)
        end
    end

    return false
end

function update_benders_sp_phase!(
    algo::BendersCutGeneration, algdata::BendersCutGenData, spform::Formulation
) 
    # Update objective function
    spform_uid = getuid(spform)
    phase_applied = algdata.spform_phase_applied[spform_uid]
    if !phase_applied
        phase_to_apply = algdata.spform_phase[spform_uid]
        if phase_to_apply == HybridPhase
            update_benders_sp_slackvar_cost_for_hyb_ph!(spform)
        elseif phase_to_apply == PurePhase1
            update_benders_sp_slackvar_cost_for_ph1!(spform)
        elseif phase_to_apply == PurePhase2
            update_benders_sp_slackvar_cost_for_ph2!(spform)
        end
        algdata.spform_phase_applied[spform_uid] = true
    end
    return false
end

function reset_benders_sp_phase!(algdata::BendersCutGenData, reform::Reformulation)
    for (spuid, spform) in get_benders_sep_sps(reform)
        # Reset to  separation phase
        if algdata.spform_phase[spuid] != HybridPhase
            algdata.spform_phase_applied[spuid] = false
            algdata.spform_phase[spuid] = HybridPhase
        end
    end
    return
end

function update_benders_sp_target!(spform::Formulation)
    # println("benders_sp target will only be needed after automating convexity constraints")
end

function record_solutions!(
    algo::BendersCutGeneration, algdata::BendersCutGenData, spform::Formulation,
    spresult::OptimizationResult{S}
)::Vector{ConstrId} where {S}

    recorded_dual_solution_ids = Vector{ConstrId}()

    #primal_sols = getprimalsols(spresult)
    dual_sols = getdualsols(spresult)

    for dual_sol in dual_sols
        if getvalue(dual_sol) > algo.feasibility_tol 
            (insertion_status, dual_sol_id) = setdualsol!(spform, dual_sol)
            if insertion_status
                push!(recorded_dual_solution_ids, dual_sol_id)
            else
                @warn string("dual sol already exists as ", dual_sol_id)
            end

        end
    end

    return recorded_dual_solution_ids 
end

function insert_cuts_in_master!(
    masterform::Formulation, spform::Formulation, sp_dualsol_ids::Vector{ConstrId},
)
    sp_uid = getuid(spform)
    nb_of_gen_cuts = 0
    sense = (getobjsense(masterform) == MinSense ? Greater : Less)

    for dual_sol_id in sp_dualsol_ids
        nb_of_gen_cuts += 1
        name = string("BC_", getsortuid(dual_sol_id))
        kind = MathProg.Core
        duty = MasterBendCutConstr
        bc = setcut_from_sp_dualsol!(
            masterform,
            spform,
            dual_sol_id,
            name,
            duty;
            kind = kind,
            sense = sense
        )
        
        @logmsg LogLevel(-2) string("Generated cut : ", name)
    end

    return nb_of_gen_cuts
end

function compute_benders_sp_lagrangian_bound_contrib(
    algdata::BendersCutGenData, spform::Formulation, spsol::OptimizationResult{S}
) where {S}
    dualsol = getbestdualsol(spsol)
    contrib = getvalue(dualsol)
    return contrib
end

function solve_sp_to_gencut!(
    algo::BendersCutGeneration, algdata::BendersCutGenData,
    masterform::Formulation, spform::Formulation,
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S},
    up_to_phase::FormulationPhase
)::Tuple{Bool, Bool, Vector{ConstrId}, Float64, Float64} where {S}

    recorded_dual_solution_ids = Vector{ConstrId}()
    sp_is_feasible = true

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_cut(spform)
    #     return flag_cannot_generate_more_cut
    # end

    spform_uid = getuid(spform)
    benders_sp_primal_bound_contrib = 0.0
    benders_sp_lagrangian_bound_contrib =  0.0

    insertion_status = 0
    spsol_relaxed = false

    # Compute target
    update_benders_sp_target!(spform)

    # Reset var bounds, constr rhs
    if update_benders_sp_problem!(algo, algdata, spform, master_primal_sol, master_dual_sol) # Never returns true
        #     This code is never executed because update_benders_sp_prob always returns false
        #     @logmsg LogLevel(-3) "benders_sp prob is infeasible"
        #     # In case one of the subproblem is infeasible, the master is infeasible
        #     compute_benders_sp_primal_bound_contrib(alg, benders_sp_prob)
        #     return flag_is_sp_infeasible
    end


    while true # loop on phases

        update_benders_sp_phase!(algo, algdata, spform)
                # if alg.bendcutgen_stabilization != nothing && true #= TODO add conds =#
        #     # switch off the reduced cost estimation when stabilization is applied
        # end
        
        # Solve sub-problem and insert generated cuts in master
        # @logmsg LogLevel(-3) "optimizing benders_sp prob"
        TO.@timeit Coluna._to "Bender Sep SubProblem" begin
            optresult = optimize!(spform)
        end

        if !isfeasible(optresult) # if status != MOI.OPTIMAL
            sp_is_feasible = false 
            # @logmsg LogLevel(-3) "benders_sp prob is infeasible"
            bd = PrimalBound(spform) 
            return sp_is_feasible, spsol_relaxed, recorded_dual_solution_ids, bd, bd
        end

        benders_sp_lagrangian_bound_contrib = compute_benders_sp_lagrangian_bound_contrib(algdata, spform, optresult)

        primalsol = getbestprimalsol(optresult)
        spsol_relaxed = contains(spform, primalsol, BendSpSlackFirstStageVar)

        benders_sp_primal_bound_contrib = 0.0
        # compute benders_sp_primal_bound_contrib which stands for the sum of nu var,
        # i.e. the second stage cost as it would appear as 
        # the separation subproblem objective in a pure phase 2
        for (varid, value) in primalsol 
            if getduty(varid) <= BendSpSlackSecondStageCostVar
                if S == MinSense
                    benders_sp_primal_bound_contrib += value
                else
                    benders_sp_primal_bound_contrib -= value
                end
            end
        end
        
        if - algo.feasibility_tol <= getprimalbound(optresult) <= algo.feasibility_tol
        # no cuts are generated since there is no violation 
            if spsol_relaxed
                if algdata.spform_phase[spform_uid] == PurePhase2
                    error("In PurePhase2, art var were not supposed to be in sp forlumation ")
                end
                if algdata.spform_phase[spform_uid] == PurePhase1
                    error("In PurePhase1, if art var were in sol, the objective should be strictly positive.")
                end
                # algdata.spform_phase[spform_uid] == HybridPhase
                algdata.spform_phase[spform_uid] = PurePhase1
                algdata.spform_phase_applied[spform_uid] = false
                if PurePhase1 > up_to_phase
                    break
                end
                # else
                continue
            else
                if algdata.spform_phase[spform_uid] != PurePhase1
                    # no more cut to generate
                    break
                else #  one more phase to try
                    algdata.spform_phase[spform_uid] = PurePhase2
                    algdata.spform_phase_applied[spform_uid] = false
                    if PurePhase2 > up_to_phase
                        break
                    end
                    # else
                    continue
                end             
            end
            
        else # a cut can be generated since there is a violation
            recorded_dual_solution_ids = record_solutions!(algo, algdata, spform, optresult)
            if spsol_relaxed && algo.option_increase_cost_in_hybrid_phase
                #check algdata.spform_phase[spform_uid] == HybridPhase
                # Todo increase cost
                #continue
            end
            break
        end
    end
    
    return sp_is_feasible, spsol_relaxed,
    recorded_dual_solution_ids,
    benders_sp_primal_bound_contrib,
    benders_sp_lagrangian_bound_contrib
end

        

function solve_sps_to_gencuts!(
    algo::BendersCutGeneration, algdata::BendersCutGenData, 
    reform::Reformulation,  master_primalsol::PrimalSolution{S}, 
    master_dualsol::DualSolution{S}, up_to_phase::FormulationPhase
) where {S}
    
    nb_new_cuts = 0
    spsols_relaxed = false
    total_pb_correction = 0.0
    total_pb_contrib = 0.0
    masterform = getmaster(reform)
    sps = get_benders_sep_sps(reform)
    recorded_sp_dual_solution_ids = Dict{FormId, Vector{ConstrId}}()
    sp_pb_corrections = Dict{FormId, Float64}()
    sp_pb_contribs = Dict{FormId, Float64}()
    spsol_relaxed_status = Dict{FormId, Bool}()
    insertion_status = Dict{FormId, Bool}()


    ### BEGIN LOOP TO BE PARALLELIZED
    for (spuid, spform) in sps
        recorded_sp_dual_solution_ids[spuid] = Vector{ConstrId}()
        gen_status, spsol_relaxed, recorded_dual_solution_ids, benders_sp_primal_bound_contrib, benders_sp_lagrangian_bound_contrib = solve_sp_to_gencut!(
            algo, algdata, masterform, spform,
            master_primalsol, master_dualsol,
            up_to_phase
        )
        if gen_status # else Sp is infeasible: contrib = Inf
            recorded_sp_dual_solution_ids[spuid] = recorded_dual_solution_ids
        end        
        sp_pb_corrections[spuid] = benders_sp_primal_bound_contrib
        sp_pb_contribs[spuid] = benders_sp_lagrangian_bound_contrib
        insertion_status[spuid] = gen_status
        spsol_relaxed_status[spuid] = spsol_relaxed
    end
    ### END LOOP TO BE PARALLELIZED

    global_gen_status = true
    for (spuid, spform) in sps
        global_gen_status &= insertion_status[spuid]
        spsols_relaxed |= spsol_relaxed_status[spuid]
        total_pb_correction += sp_pb_corrections[spuid] 
        total_pb_contrib += sp_pb_contribs[spuid]
        nb_new_cuts += insert_cuts_in_master!(masterform, spform, recorded_sp_dual_solution_ids[spuid])
    end
    
    if spsols_relaxed
        total_pb_correction = PrimalBound(getmaster(reform))
    end
    return (nb_new_cuts, spsols_relaxed, total_pb_correction, total_pb_contrib)
end


function compute_master_pb_contrib(algdata::BendersCutGenData, master::Formulation,
                                   restricted_master_sol_value::DualBound{S}) where {S}
    # TODO: will change with stabilization
    return PrimalBound(master, getvalue(restricted_master_sol_value))
end

function update_lagrangian_pb!(algdata::BendersCutGenData, reform::Reformulation,
                               restricted_master_sol_dual_sol::DualSolution{S},
                               benders_sp_sp_primal_bound_contrib) where {S}
    master = getmaster(reform)
    restricted_master_sol_value = getbound(restricted_master_sol_dual_sol)
    lagran_bnd = PrimalBound(master, 0.0)
    lagran_bnd += compute_master_pb_contrib(algdata, master, restricted_master_sol_value)
    lagran_bnd += benders_sp_sp_primal_bound_contrib
    set_lp_primal_bound!(algdata.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_relaxed_master!(master::Formulation)
    elapsed_time = @elapsed begin
        optresult = TO.@timeit Coluna._to "relaxed master" optimize!(master)
    end
    return optresult, elapsed_time
end

function generatecuts!(
    algo::BendersCutGeneration, algdata::BendersCutGenData, reform::Reformulation,
    master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}, phase::FormulationPhase
)::Tuple{Int, Bool, PrimalBound{S}} where {S}
    masterform = getmaster(reform)
    filtered_dual_sol = filter(elem -> getduty(elem[1]) == MasterPureConstr, master_dual_sol)

    ## TODO stabilization : move the following code inside a loop
    nb_new_cuts, spsols_relaxed, pb_correction, sp_pb_contrib =
        solve_sps_to_gencuts!(
            algo, algdata, reform, master_primal_sol, filtered_dual_sol, phase
        )
    update_lagrangian_pb!(algdata, reform, master_dual_sol, sp_pb_contrib)
    if nb_new_cuts < 0
        # subproblem infeasibility leads to master infeasibility
        return (-1, false)
    end
    # end TODO
    #primal_bound = PrimalBound(masterform, getvalue(master_primal_sol) + getvalue(pb_correction))
    primal_bound = getbound(master_primal_sol) + pb_correction
    #setvalue!(master_primal_sol, getvalue(master_primal_sol) + pb_correction)
    return nb_new_cuts, spsols_relaxed, primal_bound
end

function bend_cutting_plane_main_loop(
    algo::BendersCutGeneration, algdata::BendersCutGenData, reform::Reformulation,
)::BendersCutGenerationRecord

    nb_bc_iterations = 0
    masterform = getmaster(reform)
    one_spsol_is_a_relaxed_sol = false
    master_primal_sol = nothing
    primal_bound = PrimalBound(masterform)
    
    for (spuid, spform) in get_benders_sep_sps(reform)
        algdata.spform_phase[spuid] = HybridPhase
        algdata.spform_phase_applied[spuid] = true
    end
 

    while true # loop on master solution
        nb_new_cuts = 0
        cur_gap = 0.0
        
        optresult, master_time = solve_relaxed_master!(masterform)

        if getfeasibilitystatus(optresult) == INFEASIBLE
            db = - DualBound(masterform)
            pb = - PrimalBound(masterform)
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

        update_lp_dual_sol!(algdata.incumbents, master_dual_sol)
        dual_bound = get_lp_dual_bound(algdata.incumbents)
        update_lp_dual_bound!(algdata.incumbents, dual_bound)
        update_ip_dual_bound!(algdata.incumbents, dual_bound)
                
        reset_benders_sp_phase!(algdata, reform) # phase = HybridPhase

        for up_to_phase in (HybridPhase,PurePhase1,PurePhase2)  # loop on separation phases
            nb_bc_iterations += 1

            # generate new cuts by solving the subproblems
            sp_time = @elapsed begin
                nb_new_cuts, one_spsol_is_a_relaxed_sol, primal_bound  =
                    generatecuts!(
                        algo, algdata, reform, master_primal_sol, master_dual_sol, up_to_phase
                    )
            end

            if nb_new_cuts < 0
                #@error "infeasible subproblem."
                return BendersCutGenerationRecord(algdata.incumbents, true)
            end

            # TODO: update bendcutgen stabilization
            update_lp_primal_sol!(algdata.incumbents, master_primal_sol)
            set_lp_primal_bound!(algdata.incumbents, primal_bound)
            cur_gap = gap(primal_bound, dual_bound)
            
            print_intermediate_statistics(
                algdata, nb_new_cuts, nb_bc_iterations, master_time, sp_time
            )
            
            
            if cur_gap < algo.optimality_tol
                @logmsg LogLevel(1) "Should stop because pb = $primal_bound & db = $dual_bound"
                # TODO : problem with the gap
                 break # loop on separation phases
            end
            
            if nb_bc_iterations >= algo.max_nb_iterations
                @warn "Maximum number of cut generation iteration is reached."
                algdata.is_feasible = false
                break # loop on separation phases
            end
            
            if nb_new_cuts > 0
                @logmsg LogLevel(0) "Cuts have been found."
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
            @logmsg LogLevel(0) "Benders Speration Algorithm has converged." nb_new_cut cur_gap
            algdata.has_converged = true
            break # loop on master lp solution          
        end
        
    end  # loop on master lp solution 

    if !one_spsol_is_a_relaxed_sol                
        # TODO : replace with isinteger(master_primal_sol)  # ISSUE 179
        sol_integer = true
        for (varid, val) in master_primal_sol
            if getperenekind(masterform, varid) != Continuous
                round_down_val = Float64(val, RoundDown)
                round_up_val = Float64(val, RoundUp)
                
                if round_down_val < round_up_val - algo.feasibility_tol #!isinteger(truncated_val)
                    sol_integer = false
                    break
                end
            end
        end
        if sol_integer
            update_ip_primal_sol!(algdata.incumbents, master_primal_sol)
            update_ip_primal_bound!(algdata.incumbents, primal_bound)
        end
    end
    return BendersCutGenerationRecord(algdata.incumbents, false)
end

function print_intermediate_statistics(algdata::BendersCutGenData,
                                       nb_new_cut::Int,
                                       nb_bc_iterations::Int,
                                       mst_time::Float64, sp_time::Float64)
    mlp = getvalue(get_lp_dual_bound(algdata.incumbents))
    db = getvalue(get_ip_dual_bound(algdata.incumbents))
    pb = getvalue(get_ip_primal_bound(algdata.incumbents))
    @printf(
            "<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cuts=%i> <mlp=%10.4f> <DB=%10.4f> <PB=%10.4f>\n",
            nb_bc_iterations, Coluna._elapsed_solve_time(), mst_time, sp_time, nb_new_cut, mlp, db, pb
    )
end

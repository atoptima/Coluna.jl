struct BendersCutGeneration <: AbstractAlgorithm
    option_use_reduced_cost::Bool
end
BendersCutGeneration() = BendersCutGeneration(false)

mutable struct BendersCutGenerationData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    sp_formulation_phase::Dict{Int, FormulationPhase}
    slack_cost_increase::Float64
    slack_cost_increase_applied::Bool
end

function BendersCutGenerationData(S::Type{<:AbstractObjSense}, node_inc::Incumbents)
    i = Incumbents(S)
    set_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    
    return BendersCutGenerationData(i, false, true, Dict{String, FormulationPhase}(), 0.0, true)
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
    algorithm_data = BendersCutGenerationData(form.master.obj_sense, node.incumbents)
    @logmsg LogLevel(-1) "Run BendersCutGeneration."
    Base.@time bend_rec = bend_cutting_plane_main_loop(algorithm_data, form, 1)
    set!(node.incumbents, bend_rec.incumbents)
    return bend_rec
end



function update_bendersep_problem!(alg_data::BendersCutGenerationData, sp_form::Formulation, master_primal_sol::PrimalSolution{S}, master_dual_sol::DualSolution{S}) where {S}

    master_form = sp_form.parent_formulation

    if haskey(alg_data.sp_formulation_phase, getuid(sp_form))
        current_status = alg_data.sp_formulation_phase[getuid(sp_form)]
        if current_status == PurePhase1
            for (var_id, var) in filter(_active_ , getvars(sp_form))
                setcurcost!(sp_form, var, getperenecost(sp_form, var))
            end
            alg_data.sp_formulation_phase[getuid(sp_form)] = HybridPhase
        end
    end
    
    # Update rhs of technological constraints
    for (constr_id, constr) in filter(_active_BendSpMaster_constr_ , getconstrs(sp_form))
        setcurrhs!(sp_form, constr, computereducedrhs(sp_form, constr_id, master_primal_sol))
    end
    
    # Update bounds on slack var "BendSpSlackFirstStageVar"
    cur_sol = getsol(master_primal_sol)
    for (var_id, var) in filter(_active_BendSpSlackFirstStage_var_ , getvars(sp_form))
        if haskey(cur_sol, var_id)
            #setcurlb!(var, getperenelb(var) - cur_sol[var_id])
            setcurub!(var, getpereneub(var) - cur_sol[var_id])
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

    #==
if !alg_data.slack_cost_increase_applied
        println("\e[35m slack cost increase. \e[00m")
        for (var_id, var) in filter(_active_BendSpSlackFirstStage_var_, getvars(sp_form))
            cost = getcurcost(var) + alg_data.slack_cost_increase
            setcurcost!(sp_form, var, cost)
        end
        alg_data.slack_cost_increase_applied = true
    end
==#
    return false

end

function reset_bendersep_to_feasibility_problem!(alg_data::BendersCutGenerationData, sp_form::Formulation) 

    for (var_id, var) in filter(_active_ , getvars(sp_form))
        if getduty(var) == BendSpSlackFirstStageVar
            setcurcost!(sp_form, var, 1.0)
        else
            setcurcost!(sp_form, var, 0.0)
        end
    end
    alg_data.sp_formulation_phase[getuid(sp_form)] = PurePhase1 #FormulationPhase

    return false

end



function update_bendersep_target!(sp_form::Formulation)
    # println("bendersep target will only be needed after automating convexity constraints")
end


function insert_cuts_in_master!(master_form::Formulation,
                                sp_form::Formulation,
                                primal_sols::Vector{PrimalSolution{S}},
                                dual_sols::Vector{DualSolution{S}}) where {S}
    

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

function compute_bendersep_pb_contrib(alg, sp_form::Formulation,
                                      spsol)
    contrib = getdualbound(spsol)
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

function solve_sp_to_gencut!(alg_data::BendersCutGenerationData, master_form::Formulation,
                 sp_form::Formulation,
                 master_primal_sol::PrimalSolution{S},
                 master_dual_sol::DualSolution{S}) where {S}
    
    #flag_need_not_generate_more_cut = 0 # Not used
    flag_is_sp_infeasible = -1
    #flag_cannot_generate_more_cut = -2 # Not used
    #primal_bound_contrib = 0 # Not used
    #pseudo_primal_bound_contrib = 0 # Not used

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_cut(sp_form)
    #     return flag_cannot_generate_more_cut
    # end

    # Compute target
    update_bendersep_target!(sp_form)


    # Reset var bounds, var cost, sp minCost
    if update_bendersep_problem!(alg_data, sp_form, master_primal_sol, master_dual_sol) # Never returns true
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
        opt_result = optimize!(sp_form)
    end
    
    bendersep_pb_contrib = compute_bendersep_pb_contrib(alg_data, sp_form, opt_result)
    # @show bendersep_primal_bound_contrib
    
    if !isfeasible(opt_result) # if status != MOI.OPTIMAL
        # @logmsg LogLevel(-3) "bendersep prob is infeasible"
        return flag_is_sp_infeasible
    end

    

    primal_sols = getprimalsols(opt_result)

    spsol_is_a_relaxed_sol = contains(primal_sols[1], BendSpSlackFirstStageVar)

    primal_bound_correction = PrimalBound{S}(0.0)

    if spsol_is_a_relaxed_sol       
        if -1e-5 <= getprimalbound(opt_result) <= 1e-5
            reset_bendersep_to_feasibility_problem!(alg_data, sp_form)

            TO.@timeit _to "Resolve Bender Sep SubProblem" begin
                opt_result = optimize!(sp_form)
            end
            if !isfeasible(opt_result) # if status != MOI.OPTIMAL
                # @logmsg LogLevel(-3) "bendersep prob is infeasible"
                return flag_is_sp_infeasible
            end
            primal_bound_correction = defaultprimalboundvalue(S)

            primal_sols = getprimalsols(opt_result)

            spsol_is_a_relaxed_sol = contains(primal_sols[1], BendSpSlackFirstStageVar)
        else
            sp_primal_sol_const_slack = filter(primal_sols[1], BendSpSlackSecondStageCostVar)
            
            if S == MinSense
                for (id, value) in getrecords(sp_primal_sol_const_slack)
                    primal_bound_correction += PrimalBound{S}(value)
                end
            else
                for (id, value) in getrecords(sp_primal_sol_const_slack)
                    primal_bound_correction -= PrimalBound{S}(value)
                end
            end
        end
        
    end
    
    insertion_status = insert_cuts_in_master!(master_form, sp_form, primal_sols, getdualsols(opt_result))
    
    return insertion_status, spsol_is_a_relaxed_sol, primal_bound_correction, bendersep_pb_contrib
end

function solve_sps_to_gencuts!(alg_data::BendersCutGenerationData, reformulation::Reformulation,
                  primal_sol::PrimalSolution{S},
                  dual_sol::DualSolution{S}) where {S}

    nb_new_cuts = 0
    relaxation_status = false
    total_primal_bound_correction = PrimalBound{S}(0.0)
    primal_bound_contrib = PrimalBound{S}(0.0)
    master_form = getmaster(reformulation)
    sps = get_benders_sep_sp(reformulation)
    for sp_form in sps
        sp_uid = getuid(sp_form)
        gen_status, spsol_is_a_relaxed_sol, primal_bound_correction, contrib =
            solve_sp_to_gencut!(alg_data, master_form, sp_form, primal_sol, dual_sol)

        if spsol_is_a_relaxed_sol
            relaxation_status = true
            total_primal_bound_correction += primal_bound_correction
        else
            total_primal_bound_correction = defaultprimalboundvalue(S)
        end
        
        if gen_status > 0
            nb_new_cuts += gen_status
            primal_bound_contrib += float(contrib)
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, Inf)
        end
    end
    return (nb_new_cuts, relaxation_status, total_primal_bound_correction, primal_bound_contrib)
end


function compute_master_pb_contrib(alg_data::BendersCutGenerationData,
                                   restricted_master_sol_value::DualBound{S}) where {S}
    # TODO: will change with stabilization
    return PrimalBound{S}(restricted_master_sol_value)
end

function update_lagrangian_pb!(alg_data::BendersCutGenerationData,
                               restricted_master_sol_value::DualBound{S},
                               bendersep_sp_primal_bound_contrib::PrimalBound{S}) where {S}
    lagran_bnd = PrimalBound{S}(0.0)
    lagran_bnd += compute_master_pb_contrib(alg_data, restricted_master_sol_value)
    lagran_bnd += bendersep_sp_primal_bound_contrib
    set_lp_primal_bound!(alg_data.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_relaxed_master!(master::Formulation)
    #@show "function solve_relaxed_master!(master::Formulation)"
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit _to "relaxed master" optimize!(master)
    end
    #@show opt_result
    return opt_result, elapsed_time
end



function generatecuts!(alg_data::BendersCutGenerationData,
                       reform::Reformulation,
                       master_val::DualBound{S},
                       master_primal_sol::PrimalSolution{S},
                       master_dual_sol::DualSolution{S}) where {S}

    # Filter the dual solution
    master_form = reform.master
    
    #==fonction = c -> getduty(getconstr(master_form, c[1])) == MasterPureConstr
    for id_val in dual_sol.sol
        @show id_val
        @show id_val[1]
        @show getconstr(master_form, id_val[1])
        @show getduty(getconstr(master_form, id_val[1]))
        @show fonction(id_val)
   end==#

    fonction = constr -> getduty(constr) == MasterPureConstr
    filtered_dual_sol = filter(fonction, master_dual_sol)

    #@show filtered_dual_sol
    
    nb_new_cuts = 0
    one_spsol_is_a_relaxed_sol = false
    total_primal_bound_correction = PrimalBound{S}(0.0)
    
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_cut, one_spsol_is_a_relaxed_sol, total_primal_bound_correction, sp_pb_contrib =
            solve_sps_to_gencuts!(alg_data, reform, master_primal_sol, filtered_dual_sol)
        nb_new_cuts += nb_new_cut
        update_lagrangian_pb!(alg_data, master_val, sp_pb_contrib)
        if nb_new_cut < 0
            # subproblem infeasibility leads to master infeasibility
            return -1 # TODO : type instability
        end
        break # TODO : rm once you implement stabilisation
    end
    return nb_new_cuts, one_spsol_is_a_relaxed_sol, total_primal_bound_correction
end


function bend_cutting_plane_main_loop(alg_data::BendersCutGenerationData,
                                      reformulation::Reformulation,
                                      phase::Int)::BendersCutGenerationRecord

    nb_bc_iterations = 0
    master_form = getmaster(reformulation)

    while true
        opt_result, master_time = solve_relaxed_master!(master_form)

        #@show  opt_result

        if getfeasibilitystatus(opt_result) == INFEASIBLE
            sense = getobjsense(master_form)
            db = DualBound{sense}(infeasibledualboundvalue(sense))
            pb = PrimalBound{sense}(defaultprimalboundvalue(sense))
            set_lp_dual_bound!(alg_data.incumbents, db)
            set_lp_primal_bound!(alg_data.incumbents, pb)
            return BendersCutGenerationRecord(alg_data.incumbents, true)
        end
           
        master_dual_sol = getbestdualsol(opt_result)
        master_primal_sol = getbestprimalsol(opt_result)

        if !isfeasible(opt_result) || master_primal_sol == nothing || master_dual_sol == nothing
            error("Benders algorithm:  the relaxed master LP is infeasible or unboundedhas no solution.")
            return BendersCutGenerationRecord(alg_data.incumbents, true)
        end
        
        master_val = getdualbound(opt_result)
        primal_bound_correction = PrimalBound{getobjsense(master_form)}(0.0)

        set_lp_dual_sol!(alg_data.incumbents, master_dual_sol)
        dual_bound = get_lp_dual_bound(alg_data.incumbents)
        #@show dual_bound 
        
        # TODO: cleanup restricted master columns        

        nb_bc_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_cuts, one_spsol_is_a_relaxed_sol, primal_bound_correction =
                generatecuts!(
                    alg_data, reformulation, master_val, master_primal_sol, master_dual_sol
                )
        end
        #@show nb_new_cuts, one_spsol_is_a_relaxed_sol, primal_bound_correction

        print_intermediate_statistics(
            alg_data, nb_new_cuts, nb_bc_iterations, master_time, sp_time
        )

        if nb_new_cuts < 0
            @error "infeasible subproblem."
            return BendersCutGenerationRecord(alg_data.incumbents, true)
        end

        # TODO: update bendcutgen stabilization

        if  !one_spsol_is_a_relaxed_sol
            set_lp_primal_sol!(alg_data.incumbents, master_primal_sol, primal_bound_correction)
            primal_bound = get_lp_primal_bound(alg_data.incumbents)
            #@show primal_bound
            cur_gap = gap(primal_bound, dual_bound)
            
            if isinteger(master_primal_sol)
                set_ip_primal_sol!(alg_data.incumbents, master_primal_sol, primal_bound_correction)
            end
        end

        if nb_new_cuts == 0 #&& alg_data.slack_cost_increase_applied
            #@show "Benders Speration Algorithm has converged." nb_new_cut cur_gap
            println("end convergence")
            alg_data.has_converged = true
            break
        end
        
        primal_bound = get_lp_primal_bound(alg_data.incumbents)
        cur_gap = gap(primal_bound, dual_bound)
        if cur_gap < 0.00001  #_params_.relative_optimality_tolerance
            println("end cur_gap")
            #break
        end
        
        if nb_bc_iterations >= 100 #alg_data.max_nb_bc_iterations
            @warn "Maximum number of cut generation iteration is reached."
            alg_data.is_feasible = false
            break
        end
    end

    return BendersCutGenerationRecord(alg_data.incumbents, false)
end

function print_intermediate_statistics(alg_data::BendersCutGenerationData,
                                       nb_new_cut::Int,
                                       nb_bc_iterations::Int,
                                       mst_time::Float64, sp_time::Float64)
    mlp = getvalue(get_lp_dual_bound(alg_data.incumbents))
    db = getvalue(get_ip_dual_bound(alg_data.incumbents))
    pb = getvalue(get_ip_primal_bound(alg_data.incumbents))
    @printf(
            "<it=%i> <et=%i> <mst=%.3f> <sp=%.3f> <cuts=%i> <mlp=%.4f> <DB=%.4f> <PB=%.4f>\n",
            nb_bc_iterations, _elapsed_solve_time(), mst_time, sp_time, nb_new_cut, mlp, db, pb
    )
end

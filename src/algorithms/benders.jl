struct BendersCutGeneration <: AbstractAlgorithm end

mutable struct BendersCutGenerationData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
end

function BendersCutGenerationData(S::Type{<:AbstractObjSense}, node_inc::Incumbents)
    i = Incumbents(S)
    set_ip_primal_sol!(i, get_ip_primal_sol(node_inc))
    return BendersCutGenerationData(i, false, true)
end

# Data needed for another round of column generation
struct BendersCutGenerationRecord <: AbstractAlgorithmRecord
    incumbents::Incumbents
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


# Internal methods to the column generation
function update_bendersep_problem!(sp_form::Formulation, primal_sol::PrimalSolution{S}, dual_sol::DualSolution{S}) where {S}

    master_form = sp_form.parent_formulation
    
    for (constr_id, constr) in filter(_active_BendSpMaster_constr_ , getconstrs(sp_form))
        setcurrhs!(sp_form, constr, computereducedrhs(sp_form, constr_id, primal_sol))
    end
    
    for (var_id, var) in filter(_active_BendSpSlackFirstStage_var_ , getvars(sp_form))
        setcurcost!(sp_form, var, computereducedcost(master_form, var_id, dual_sol))
    end


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
                master_form, name, primal_sol, dual_sol, duty; 
                kind = kind, sense = sense
            )
            @logmsg LogLevel(-2) string("Generated cut : ", name)

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

function compute_bendersep_pb_contrib(sp_form::Formulation,
                                      sp_sol_value::DualBound{S}) where {S}
    # Since convexity constraints are not automated and there is no stab
    # the bendersep_dual_bound_contrib is just the reduced cost * multiplicty
    contrib =  sp_sol_value
    
    return contrib
end

function gencut!(master_form::Formulation,
                 sp_form::Formulation,
                 primal_sol::PrimalSolution{S},
                 dual_sol::DualSolution{S}) where {S}
    
    #flag_need_not_generate_more_cut = 0 # Not used
    # flag_is_sp_infeasible = -1
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
    if update_bendersep_problem!(sp_form, primal_sol, dual_sol) # Never returns true
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
    
    bendersep_pb_contrib = compute_bendersep_pb_contrib(sp_form, getdualbound(opt_result))
    # @show bendersep_primal_bound_contrib
    
    if !isfeasible(opt_result) # if status != MOI.OPTIMAL
        # @logmsg LogLevel(-3) "bendersep prob is infeasible"
        return flag_is_sp_infeasible
    end
    
    insertion_status = insert_cuts_in_master!(master_form, sp_form, getprimalsols(opt_result), getdualsols(opt_result))
    
    return insertion_status, bendersep_pb_contrib
end

function gencuts!(reformulation::Reformulation,
                  primal_sol::PrimalSolution{S},
                  dual_sol::DualSolution{S}) where {S}

    nb_new_cuts = 0
    primal_bound_contrib = PrimalBound{S}(0.0)
    master_form = getmaster(reformulation)
    sps = get_benders_sep_sp(reformulation)
    for sp_form in sps
        sp_uid = getuid(sp_form)
        gen_status, contrib = gencut!(master_form, sp_form, primal_sol, dual_sol)

        if gen_status > 0
            nb_new_cuts += gen_status
            primal_bound_contrib += float(contrib)
        elseif gen_status == -1 # Sp is infeasible
            return (gen_status, Inf)
        end
    end
    return (nb_new_cuts, primal_bound_contrib)
end


function compute_master_pb_contrib(alg::BendersCutGenerationData,
                                   restricted_master_sol_value::DualBound{S}) where {S}
    # TODO: will change with stabilization
    return PrimalBound{S}(restricted_master_sol_value)
end

function update_lagrangian_pb!(alg::BendersCutGenerationData,
                               restricted_master_sol_value::DualBound{S},
                               bendersep_sp_primal_bound_contrib::PrimalBound{S}) where {S}
    lagran_bnd = PrimalBound{S}(0.0)
    lagran_bnd += compute_master_pb_contrib(alg, restricted_master_sol_value)
    lagran_bnd += bendersep_sp_primal_bound_contrib
    set_lp_primal_bound!(alg.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_relaxed_master!(master::Formulation)
    @show "function solve_relaxed_master!(master::Formulation)"
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit _to "relaxed master" optimize!(master)
    end
    @show opt_result
    return (isfeasible(opt_result), getdualbound(opt_result), 
    getprimalsols(opt_result), getdualsols(opt_result), elapsed_time)
end



function generatecuts!(alg::BendersCutGenerationData,
                       reform::Reformulation,
                       master_val::DualBound{S},
                       primal_sol::PrimalSolution{S},
                       dual_sol::DualSolution{S}) where {S}

    # Filter the dual solution
    master_form = reform.master
    fonction = c -> getduty(getconstr(master_form, c[1])) == MasterPureConstr
    for id_val in dual_sol.sol
        @show id_val
        @show id_val[1]
        @show getconstr(master_form, id_val[1])
        @show getduty(getconstr(master_form, id_val[1]))
        @show fonction(id_val)
   end

    fonction = c -> getduty(getconstr(master_form, c[1])) == MasterPureConstr
    filtered_dual_sol = filter(fonction, dual_sol)
    
    
    nb_new_cuts = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_cut, sp_pb_contrib =  gencuts!(reform, primal_sol, filtered_dual_sol)
        nb_new_cuts += nb_new_cut
        update_lagrangian_pb!(alg, master_val, sp_pb_contrib)
        if nb_new_cut < 0
            # subproblem infeasibility leads to master infeasibility
            return -1
        end
        break # TODO : rm
    end
    return nb_new_cuts
end


function bend_cutting_plane_main_loop(alg_data::BendersCutGenerationData,
                                      reformulation::Reformulation,
                                      phase::Int)::BendersCutGenerationRecord

    setglobalstrategy!(reformulation, GlobalStrategy(SimpleBenders, SimpleBranching, DepthFirst))
    nb_bc_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    master_form = reformulation.master

    while true
        master_status, master_val, primal_sols, dual_sols, master_time =
            solve_relaxed_master!(master_form)

        @show master_status, master_val, primal_sols, dual_sols, master_time
        
        if master_status == MOI.INFEASIBLE || master_status == MOI.INFEASIBLE_OR_UNBOUNDED
            @error "Alg_Dataorithm returned that restricted master LP is infeasible or unbounded (status = $master_status)."
            return BendersCutGenerationRecord(alg_data.incumbents)
        end
       
       
        set_lp_dual_sol!(alg_data.incumbents, dual_sols[1])
        
        #if isinteger(primal_sols[1])
       #     set_ip_primal_sol!(alg_data.incumbents, primal_sols[1])
        #end

        # TODO: cleanup restricted master columns        

        nb_bc_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_cut = generatecuts!(
                alg_data, reformulation, master_val, primal_sols[1], dual_sols[1]
            )
        end

        if nb_new_cut < 0
            @error "Infeasible subproblem."
            return BendersCutGenerationRecord(alg_data.incumbents)
        end


        print_intermediate_statistics(
            alg_data, nb_new_cut, nb_bc_iterations, master_time, sp_time
        )

        # TODO: update bendcutgen stabilization

        ub = min(
            get_lp_primal_bound(alg_data.incumbents), get_ip_primal_bound(alg_data.incumbents)
        )
        lb = get_lp_dual_bound(alg_data.incumbents)

        if nb_new_cut == 0 || diff(lb + 0.00001, ub) < 0
            alg_data.has_converged = true
            return BendersCutGenerationRecord(alg_data.incumbents)
        end
        if nb_bc_iterations > 1000 ##TDalg_data.max_nb_bc_iterations
            @warn "Maximum number of cut generation iteration is reached."
            alg_data.is_feasible = false
            return BendersCutGenerationRecord(alg_data.incumbents)
        end
    end
    return BendersCutGenerationRecord(alg_data.incumbents)
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

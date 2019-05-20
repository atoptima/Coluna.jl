struct BendersCutGeneration <: AbstractSolver end

mutable struct BendersCutGenerationData <: AbstractSolverData
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
struct BendersCutGenerationRecord <: AbstractSolverRecord
    incumbents::Incumbents
end

# Overload of the solver interface
function prepare!(::Type{ColumnGeneration}, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Prepare BendersCutGeneration."
    return
end

function run!(::Type{BendersCutGeneration}, solver_data::BendersCutGenerationData,
              formulation, node, parameters)
    @logmsg LogLevel(-1) "Run BendersCutGeneration."
    Base.@time e = bendcutgen_solver_ph2(solver_data, formulation)
    return e
end


# Internal methods to the column generation
function update_bendersep_problem!(sp_form::Formulation, primal_sol::PrimalSolution) 

    master_form = sp_form.parent_formulation
    
    for (constr_id, constr) in filter(_active_bendersep_sp_constr_ , getconstrs(sp_form))
        setcurrhs!(constr, computereducedrhs(master_form, constr_id, primal_sol))
        commit_rhs_change!(sp_form, constr)
    end

    return false
end

function update_bendersep_target!(sp_form::Formulation)
    # println("bendersep target will only be needed after automating convexity constraints")
end


function insert_cuts_in_master!(master_form::Formulation,
                               sp_form::Formulation,
                               sp_sols::Vector{DualSolution{S}}) where {S}

    sp_uid = getuid(sp_form)
    nb_of_gen_cuts = 0

    for sp_sol in sp_sols
        # the solution value represent the cut violation at this stage
        if getvalue(sp_sol) > 0.0001 # TODO the cut feasibility tolerance
            nb_of_gen_cuts += 1
            ref = getconstrcounter(master_form) + 1
            name = string("BC", sp_uid, "_", ref)
            resetsolvalue(master_form, sp_sol) # now the sol value represents the dual sol value
            kind = Core
            sense = Less
            duty = BendersCutConstr
            bc = setdualspsol!(
                master_form, name, sp_sol, duty; 
                kind = kind, sense = sense
            )
            @logmsg LogLevel(-2) string("Generated cut : ", name)

            # TODO: check if cut exists
            #== mc_id = getid(mc)
            id_of_existing_mc = - 1
            primalspsol_matrix = getprimalspsolmatrix(master_form)
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
                                      sp_sol_value::PrimalBound{S}) where {S}
    # Since convexity constraints are not automated and there is no stab
    # the bendersep_dual_bound_contrib is just the reduced cost * multiplicty
    contrib =  sp_sol_value
    
    return contrib
end

function gencut!(master_form::Formulation,
                 sp_form::Formulation,
                 primal_sol::PrimalSolution)
    
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
    if update_bendersep_problem!(sp_form, primal_sol) # Never returns true
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
    TO.@timeit to "Bendersep subproblem" begin
        status, value, p_sols, d_sols = optimize!(sp_form)
    end
    
    bendersep_pb_contrib = compute_bendersep_pb_contrib(sp_form, value)
    # @show bendersep_primal_bound_contrib
    
    if status != MOI.OPTIMAL
        # @logmsg LogLevel(-3) "bendersep prob is infeasible"
        return flag_is_sp_infeasible
    end
    
    insertion_status = insert_cuts_in_master!(master_form, sp_form, d_sols)
    
    return insertion_status, bendersep_pb_contrib
end

function gencuts!(reformulation::Reformulation,
                  primal_sol::PrimalSolution{S}) where {S}

    nb_new_cuts = 0
    primal_bound_contrib = PrimalBound{S}(0.0)
    master_form = getmaster(reformulation)
    for sp_form in reformulation.dw_bendersep_subprs
        sp_uid = getuid(sp_form)
        gen_status, contrib = gencut!(master_form, sp_form, primal_sol)

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
                                   restricted_master_sol_value::PrimalBound{S}) where {S}
    # TODO: will change with stabilization
    return PrimalBound{S}(restricted_master_sol_value)
end

function update_lagrangian_pb!(alg::BendersCutGenerationData,
                               restricted_master_sol_value::PrimalBound{S},
                               bendersep_sp_primal_bound_contrib::PrimalBound{S}) where {S}
    lagran_bnd = PrimalBound{S}(0.0)
    lagran_bnd += compute_master_pb_contrib(alg, restricted_master_sol_value)
    lagran_bnd += bendersep_sp_primal_bound_contrib
    set_lp_primal_bound!(alg.incumbents, lagran_bnd)
    return lagran_bnd
end

function solve_relaxed_master!(master::Formulation)
    # GLPK.write_lp(getinner(get_optimizer(master_form)), string(dirname(@__FILE__ ), "/mip_", nb_bc_iterations,".lp"))
    elapsed_time = @elapsed begin
        status, val, primal_sols, dual_sols = TO.@timeit to "LP restricted master" optimize!(master)
    end
    return status, val, primal_sols, dual_sols, elapsed_time
end

function generatecuts!(alg::BendersCutGenerationData, reform::Reformulation,
                          master_val, primal_sol)
    nb_new_cuts = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_cut, sp_pb_contrib =  gencuts!(reform, primal_sol)
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


function bendcutgen_solver_ph2(alg::BendersCutGenerationData,
                           reformulation::Reformulation)::BendersCutGenerationRecord
    nb_bc_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    master_form = reformulation.master

    while true
        master_status, master_val, primal_sols, dual_sols, master_time =
            solve_relaxed_master!(master_form)

        if master_status == MOI.INFEASIBLE || master_status == MOI.INFEASIBLE_OR_UNBOUNDED
            @error "Solver returned that restricted master LP is infeasible or unbounded (status = $master_status)."
            return BendersCutGenerationRecord(alg.incumbents)
        end

       
        set_lp_dual_sol!(alg.incumbents, dual_sols[1])
        
        #if isinteger(primal_sols[1])
       #     set_ip_primal_sol!(alg.incumbents, primal_sols[1])
        #end

        # TODO: cleanup restricted master columns        

        nb_bc_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_cut = generatecuts!(
                alg, reformulation, master_val, primal_sols[1]
            )
        end

        if nb_new_cut < 0
            @error "Infeasible subproblem."
            return BendersCutGenerationRecord(alg.incumbents)
        end


        print_intermediate_statistics(
            alg, nb_new_cut, nb_bc_iterations, master_time, sp_time
        )

        # TODO: update bendcutgen stabilization

        ub = min(
            get_lp_primal_bound(alg.incumbents), get_ip_primal_bound(alg.incumbents)
        )
        lb = get_lp_dual_bound(alg.incumbents)

        if nb_new_cut == 0 || diff(lb + 0.00001, ub) < 0
            alg.has_converged = true
            return BendersCutGenerationRecord(alg.incumbents)
        end
        if nb_bc_iterations > 1000 ##TDalg.max_nb_bc_iterations
            @warn "Maximum number of cut generation iteration is reached."
            alg.is_feasible = false
            return BendersCutGenerationRecord(alg.incumbents)
        end
    end
    return BendersCutGenerationRecord(alg.incumbents)
end

function print_intermediate_statistics(alg::BendersCutGenerationData,
                                       nb_new_cut::Int,
                                       nb_bc_iterations::Int,
                                       mst_time::Float64, sp_time::Float64)
    mlp = getvalue(get_lp_dual_bound(alg.incumbents))
    db = getvalue(get_ip_dual_bound(alg.incumbents))
    pb = getvalue(get_ip_primal_bound(alg.incumbents))
    @printf(
            "<it=%i> <et=%i> <mst=%.3f> <sp=%.3f> <cuts=%i> <mlp=%.4f> <DB=%.4f> <PB=%.4f>\n",
            nb_bc_iterations, _elapsed_solve_time(), mst_time, sp_time, nb_new_cut, mlp, db, pb
    )
end

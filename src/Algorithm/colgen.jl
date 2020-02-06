Base.@kwdef struct ColumnGeneration <: AbstractAlgorithm
    max_nb_iterations::Int = 500
    optimality_tol::Float64 = 1e-5
    log_print_frequency::Int = 1
end

# Data stored while algorithm is runningf
mutable struct ColGenRuntimeData
    incumbents::Incumbents
    has_converged::Bool
    is_feasible::Bool
    params::ColumnGeneration
end

function ColGenRuntimeData(
    algparams::ColumnGeneration, form::Reformulation, node::Node
)
    inc = Incumbents(form.master.obj_sense)
    update_ip_primal_sol!(inc, get_ip_primal_sol(node.incumbents))
    return ColGenRuntimeData(inc, false, true, algparams)
end

# Data needed for another round of column generation
mutable struct ColumnGenerationResult <: AbstractAlgorithmResult
    incumbents::Incumbents
    proven_infeasible::Bool
end

# Overload of the algorithm's prepare function
function prepare!(alg::ColumnGeneration, form, node)
    @logmsg LogLevel(-1) "Prepare ColumnGeneration."
    return
end

# Overload of the algorithm's run function
function run!(alg::ColumnGeneration, form::Reformulation, node::Node)    
    @logmsg LogLevel(-1) "Run ColumnGeneration."
    algdata = ColGenRuntimeData(alg, form, node)
    result = cg_main_loop(algdata, form, 2)
    masterform = getmaster(form)
    if should_do_ph_1(masterform, result)
        record!(form, node)
        set_ph_one(masterform)
        result = cg_main_loop(algdata, form, 1)
    end
    if result.proven_infeasible
        result.incumbents = Incumbents(getsense(result.incumbents))
    end
    if result.proven_infeasible
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status INFEASIBLE."
    else
        @logmsg LogLevel(-1) "ColumnGeneration terminated with status FEASIBLE."
    end
    update!(node.incumbents, result.incumbents) # this should be done in the strategy, no?
    return result
end

# Internal methods to the column generation
function should_do_ph_1(master::Formulation, result::ColumnGenerationResult)
    ip_gap(result.incumbents) <= 0.00001 && return false
    primal_lp_sol = get_lp_primal_sol(result.incumbents)
    if contains(master, primal_lp_sol, MasterArtVar)
        @logmsg LogLevel(-2) "Artificial variables in lp solution, need to do phase one"
        return true
    else
        @logmsg LogLevel(-2) "No artificial variables in lp solution, will not proceed to do phase one"
        return false
    end
end

function set_ph_one(master::Formulation)
    for (id, v) in Iterators.filter(x->(!isanArtificialDuty(getduty(x))), getvars(master))
        setcurcost!(master, v, 0.0)
    end
    return
end

function update_pricing_problem!(spform::Formulation, dual_sol::DualSolution)
    masterform = getmaster(spform)
    for (var_id, var) in getvars(spform)
        if getcurisactive(spform, var) && getduty(var) <= AbstractDwSpVar
            redcost = computereducedcost(masterform, var_id, dual_sol)
            #setcurcost!(spform, var, redcost)
        end
    end
    return false
end


function update_pricing_problem2!(spform::Formulation, dual_sol::DualSolution, redcostvec)
    masterform = getmaster(spform)
    for (var_id, var) in getvars(spform)
        if getcurisactive(spform, var) && getduty(var) <= AbstractDwSpVar
            redcost = computereducedcost(masterform, var_id, dual_sol)
            #println(">>> varid $var_id : $(redcostvec[var_id]) == $redcost")
            #@assert redcostvec[var_id] == redcost
            setcurcost!(spform, var, redcost)
        end
    end
    return false
end

function update_pricing_target!(spform::Formulation)
    # println("pricing target will only be needed after automating convexity constraints")
end

function record_solutions!(
    spform::Formulation, sols::Vector{PrimalSolution{S}}
)::Vector{VarId} where {S}
    recorded_solution_ids = Vector{VarId}()
    for sol in sols
        if contrib_improves_mlp(getbound(sol))
            (insertion_status, col_id) = setprimalsol!(spform, sol)
            if insertion_status
                push!(recorded_solution_ids, col_id)
            else
                @warn string("column already exists as", col_id)
            end

        end
    end
    return recorded_solution_ids
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

contrib_improves_mlp(sp_primal_bound::PrimalBound{MinSense}) = (sp_primal_bound < 0.0 - 1e-8)
contrib_improves_mlp(sp_primal_bound::PrimalBound{MaxSense}) = (sp_primal_bound > 0.0 + 1e-8)

function compute_pricing_db_contrib(
    spform::Formulation, sp_sol_primal_bound::PrimalBound{S}, sp_lb::Float64,
    sp_ub::Float64
) where {S}
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
)::Tuple{Bool,Vector{VarId},Float64}
    
    recorded_solution_ids = Vector{VarId}()
    sp_is_feasible = true

    #dual_bound_contrib = 0 # Not used
    #pseudo_dual_bound_contrib = 0 # Not used

    # TODO renable this. Needed at least for the diving
    # if can_not_generate_more_col(princing_prob)
    #     return flag_cannot_generate_more_col
    # end

    # # Compute target
    # update_pricing_target!(spform)

    # # Reset var bounds, var cost, sp minCost
    # if update_pricing_problem!(spform, dual_sol) # Never returns true
    #     #     This code is never executed because update_pricing_prob always returns false
    #     #     @logmsg LogLevel(-3) "pricing prob is infeasible"
    #     #     # In case one of the subproblem is infeasible, the master is infeasible
    #     #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
    #     #     return flag_is_sp_infeasible
    # end

    # if alg.colgen_stabilization != nothing && true #= TODO add conds =#
    #     # switch off the reduced cost estimation when stabilization is applied
    # end

    # Solve sub-problem and insert generated columns in master
    # @logmsg LogLevel(-3) "optimizing pricing prob"
    TO.@timeit Coluna._to "Pricing subproblem" begin
        opt_result = optimize!(spform)
    end

    pricing_db_contrib = compute_pricing_db_contrib(
        spform, getprimalbound(opt_result), sp_lb, sp_ub
    )

    if !isfeasible(opt_result)
        sp_is_feasible = false 
        # @logmsg LogLevel(-3) "pricing prob is infeasible"
        return sp_is_feasible, recorded_solution_ids, PrimalBound(spform)
    end

    recorded_solution_ids = record_solutions!(
        spform, getprimalsols(opt_result)
    )

    return sp_is_feasible, recorded_solution_ids, pricing_db_contrib
end

# function computereducedcost(form::Formulation, var_id::Id{Variable}, dualsol::DualSolution{S})  where {S<:Coluna.AbstractSense}
#     var = getvar(form, var_id)
#     rc = getperenecost(form, var)
#     coefficient_matrix = getcoefmatrix(form)
#     sign = 1
#     if getobjsense(form) == MinSense
#         sign = -1
#     end
#     for (constr_id, dual_val) in dualsol
#         coeff = coefficient_matrix[constr_id, var_id]
#         rc += sign * dual_val * coeff
#     end
#     return rc
# end

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

function _getcoeffpos(coeffpos::Int, coeffarray::Vector{Union{Nothing, Tuple{ConstrId, Float64}}}, constrid::ConstrId, constridsem::ConstrId)
    coeffpos -= 1
    lookforkeycoeff = true
    while lookforkeycoeff
        coeffpos += 1
        keycoeff = coeffarray[coeffpos]

        if keycoeff === nothing
            lookforkeycoeff = true
        else
            lookforkeycoeff = (keycoeff[1] < constrid && keycoeff[1] != constridsem && coeffpos < length(coeffarray))
        end
    end
    return coeffpos
end

function _computeTEST(coeffarray, coeffposbegin, coeffposend, dualsol)::Float64
    term::Float64 = 0
    coeffpos = coeffposbegin
    keycoeff = coeffarray[coeffpos]
    for k in 1:length(dualsol.sol.array)
        dualsolentry = dualsol.sol.array[k]
        dualsolentry === nothing && continue

        #println("\e[33m constraint $constrid in membership of var ? \e[00m")
        while keycoeff === nothing || (keycoeff[1] < dualsolentry[1] && coeffpos < coeffposend - 1)
            coeffpos += 1
            keycoeff = coeffarray[coeffpos]
        end
        #println("\t coeffpos = $coeffpos.")
        if keycoeff !== nothing && keycoeff[1] == dualsolentry[1]
            #println("\t yes.")
            term += keycoeff[2] * dualsolentry[2]
        end
    end
    return term
end


function test2(reform::Reformulation, redcostsvec, dualsol)
    redcosts = deepcopy(redcostsvec.perenecosts)
    master = getmaster(reform)
    sign = getobjsense(master) == MinSense ? -1 : 1
    matrix = getcoefmatrix(master)
    sum::Float64 = 0
    # for i in 1:length(matrix.cols_major.pcsc.pma.array)
    #     elem = matrix.cols_major.pcsc.pma.array[i]
    #     if elem !== nothing
    #         if elem[1] == 
    #         sum += elem[2]
    #     end
    # end

    colmajormatrix = matrix.cols_major
    colkeys = colmajormatrix.col_keys
    colkeyslen = length(colkeys)
    semaphores = colmajormatrix.pcsc.semaphores
    coeffarray = colmajormatrix.pcsc.pma.array
    coeffarraylen = length(coeffarray)
    constridsem = DynamicSparseArrays.semaphore_key(ConstrId)
    redcost_pos = 1
    varkey_pos = 1
    term::Float64 = 0
    coeffpos::Int = 1
    keycoeff::Union{Nothing, Tuple{ConstrId, Float64}} = coeffarray[1]
    #@show length(dualsol)
    for redcost_pos in 1:redcostsvec.length
        varid = redcostsvec.varids[redcost_pos]
        curcolkey = colkeys[varkey_pos]
        #println("\e[31m computing red cost for variable $varid (curcolkey = $curcolkey) \e[00m")
        while curcolkey === nothing || (curcolkey < varid && varkey_pos < colkeyslen)
            varkey_pos += 1
            curcolkey = colkeys[varkey_pos]
        end
        if curcolkey == varid
            #println("> found")
            # term = 0
            # coeffpos = semaphores[varkey_pos] + 1
            # keycoeff = coeffarray[coeffpos]
            # for (constrid, val) in dualsol
            #     #println("\e[33m constraint $constrid in membership of var ? \e[00m")
            #     while keycoeff === nothing || (keycoeff[1] < constrid && keycoeff[1] != constridsem && coeffpos < coeffarraylen)
            #         coeffpos += 1
            #         keycoeff = coeffarray[coeffpos]
            #     end
            #     #println("\t coeffpos = $coeffpos.")
            #     if keycoeff !== nothing && keycoeff[1] == constrid
            #         #println("\t yes.")
            #         term += keycoeff[2] * val
            #     end
            # end
            coeffposbegin = semaphores[varkey_pos] + 1
            curcolkey = colkeys[varkey_pos]
            while curcolkey === nothing
                varkey_pos += 1
                curcolkey = colkeys[varkey_pos]
            end
            coeffposend = semaphores[varkey_pos] + 1
            term = _computeTEST(coeffarray, coeffposbegin, coeffposend, dualsol)
            redcosts[redcost_pos] += sign * term
        end
    end
    return redcosts
end

function test3(reform::Reformulation, redcostsvec, dualsol)
    redcosts = deepcopy(redcostsvec.perenecosts)
    master = getmaster(reform)
    sign = getobjsense(master) == MinSense ? -1 : 1
    matrix = getcoefmatrix(master)
    sum::Float64 = 0
    for i in 1:length(matrix.cols_major.pcsc.pma.array)
         elem = matrix.cols_major.pcsc.pma.array[i]
         if elem !== nothing
             sum += elem[2]
         end
    end
    return sum
end

# function test1(vec1)
#     sum_val = 0
#     sum_key = 0
#     for i in 1:length(vec1)
#         elem = vec1[i]
#         if elem !== nothing
#             sum_val += elem[2]
#             sum_key += elem[1]
#         end
#     end
#     return sum_val
# end

# function test2(vec2, vec3)
#     sum_val = 0
#     sum_key = 0
#     for i in 1:length(vec2)
#         key = vec2[i]
#         if key !== nothing
#             sum_val += vec3[i]
#             sum_key += key
#         end
#     end
#     return sum_val
# end

# function main()
#     vec1 = Vector{Union{Nothing, Tuple{Int,Int}}}()
#     vec2 = Vector{Union{Nothing, Int}}()
#     vec3 = Vector{Union{Nothing, Int}}()

#     for i in 1:10000000
#         if rand(0:0.01:1) < 0.3
#             key = rand(1:10000)
#             value = rand(1:100000)
#             push!(vec1, (key, value))
#             push!(vec2, key)
#             push!(vec3, value)
#         else
#             push!(vec1, nothing)
#             push!(vec2, nothing)
#             push!(vec3, nothing)
#         end
#     end

#     test1(vec1)
#     test2(vec2, vec3)
    
#     @time test1(vec1)
#     @time test2(vec2, vec3)

#     return
# end
# #for ()
function computereducedcosts!(reform::Reformulation, redcostsvec, dualsol)
    redcosts = deepcopy(redcostsvec.perenecosts)
    master = getmaster(reform)
    sign = getobjsense(master) == MinSense ? -1 : 1
    matrix = getcoefmatrix(master)

    term::Float64 = 0

    redcost_pos = 1
    varkey_pos = 1
    for i in 1:redcostsvec.length
        varid = redcostsvec.varids[i]
        #println("\e[41m computing red cost of $varid \e[00m (looking for var)")
        while true
            #println("\t\t \e[35m varkeypos = $varkey_pos  && varid = $(matrix.cols_major.col_keys[varkey_pos]) \e[00m")
            if matrix.cols_major.col_keys[varkey_pos] !== nothing && (matrix.cols_major.col_keys[varkey_pos] >= varid || varkey_pos >= length(matrix.cols_major.col_keys))
                break
            end
            varkey_pos += 1
        end
        if matrix.cols_major.col_keys[varkey_pos] == varid
            #println("\t found memberships of $varid in matrix.")
            term = 0
            coeffpos = matrix.cols_major.pcsc.semaphores[varkey_pos] + 1
            for (constrid, val) in dualsol
                #println("\t\t membership of var in constraint $constrid (val = $val) ?")
                while true
                    keycoeff = matrix.cols_major.pcsc.pma.array[coeffpos]
                    if keycoeff !== nothing && (keycoeff[1] >= constrid || keycoeff[1] == DynamicSparseArrays.semaphore_key(ConstrId))
                        break
                    end
                    coeffpos += 1
                end
                if matrix.cols_major.pcsc.pma.array[coeffpos][1] == constrid
                    #println("\t\t\t value = $(matrix.cols_major.pcsc.pma.array[coeffpos][2])")
                    term += val * matrix.cols_major.pcsc.pma.array[coeffpos][2]
                end
            end
            
            redcosts[i] += sign * term #setcurcost!(redcostsvec.form[i], varid, redcostsvec.perenecosts[i] + sign * term)
        end
        redcost_pos += 1
    end
    return redcosts
end

function solve_sps_to_gencols!(
    reform::Reformulation, redcostsvec, dual_sol::DualSolution{S}, 
    sp_lbs::Dict{FormId, Float64}, sp_ubs::Dict{FormId, Float64}
) where {S}
    nb_new_cols = 0
    dual_bound_contrib = DualBound{S}(0.0)
    masterform = getmaster(reform)
    sps = get_dw_pricing_sps(reform)
    recorded_sp_solution_ids = Dict{FormId, Vector{VarId}}()
    sp_dual_bound_contribs = Dict{FormId, Float64}()

    # guillaume 
    # Update pricing var cost
    # @time begin
    #     redcosts = computereducedcosts!(reform, redcostsvec, dual_sol)
    # end

    #@time begin
        redcosts = test2(reform, redcostsvec, dual_sol)
    #end

    for i in 1:length(redcosts)
        setcurcost!(redcostsvec.form[i], redcostsvec.varids[i], redcosts[i])
    end

    # @time begin
    #     t = test3(reform, redcostsvec, dual_sol)
    # end

    # @time begin
    #      for (spuid, spform) in sps

    # #         # Reset var bounds, var cost, sp minCost
    #          if update_pricing_problem!(spform, dual_sol) # Never returns true
    # #             #     This code is never executed because update_pricing_prob always returns false
    # #             #     @logmsg LogLevel(-3) "pricing prob is infeasible"
    # #             #     # In case one of the subproblem is infeasible, the master is infeasible
    # #             #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
    # #             #     return flag_is_sp_infeasible
    #          end
    #      end
    #  end

    # redcosts2 = Dict{VarId, Float64}()
    # for i in 1:length(redcosts)
    #     redcosts2[redcostsvec.varids[i]] = redcosts[i]
    # end

    # for (spuid, spform) in sps
    #     # Reset var bounds, var cost, sp minCost
    #     if update_pricing_problem2!(spform, dual_sol, redcosts2) # Never returns true
    #         #     This code is never executed because update_pricing_prob always returns false
    #         #     @logmsg LogLevel(-3) "pricing prob is infeasible"
    #         #     # In case one of the subproblem is infeasible, the master is infeasible
    #         #     compute_pricing_dual_bound_contrib(alg, pricing_prob)
    #         #     return flag_is_sp_infeasible
    #     end
    # end

    #@show redcostsvec

    ### BEGIN LOOP TO BE PARALLELIZED
    for (spuid, spform) in sps
        gen_status, new_sp_solution_ids, sp_dual_contrib = solve_sp_to_gencol!(
            masterform, spform, dual_sol, sp_lbs[spuid], sp_ubs[spuid]
        )
        if gen_status # else Sp is infeasible: contrib = Inf
            recorded_sp_solution_ids[spuid] = new_sp_solution_ids
        end
        sp_dual_bound_contribs[spuid] = sp_dual_contrib #float(contrib)
    end
    ### END LOOP TO BE PARALLELIZED

    nb_new_cols = 0
    for (spuid, spform) in sps
        dual_bound_contrib += sp_dual_bound_contribs[spuid]
        nb_new_cols += insert_cols_in_master!(masterform, spform, recorded_sp_solution_ids[spuid]) 
    end
    
    
    return (nb_new_cols, dual_bound_contrib)
end

function compute_master_db_contrib(
    algdata::ColGenRuntimeData, restricted_master_sol_value::PrimalBound{S}
) where {S}
    # TODO: will change with stabilization
    return DualBound{S}(restricted_master_sol_value)
end

function calculate_lagrangian_db(
    algdata::ColGenRuntimeData, restricted_master_sol_value::PrimalBound{S},
    pricing_sp_dual_bound_contrib::DualBound{S}
) where {S}
    lagran_bnd = DualBound{S}(0.0)
    lagran_bnd += compute_master_db_contrib(algdata, restricted_master_sol_value)
    lagran_bnd += pricing_sp_dual_bound_contrib
    return lagran_bnd
end

function solve_restricted_master!(master::Formulation)
    elapsed_time = @elapsed begin
        opt_result = TO.@timeit Coluna._to "LP restricted master" optimize!(master)
    end
    return (isfeasible(opt_result), getprimalbound(opt_result), 
    getprimalsols(opt_result), getdualsols(opt_result), elapsed_time)
end

function generatecolumns!(
    algdata::ColGenRuntimeData, reform::Reformulation, redcostsvec, master_val, 
    dual_sol, sp_lbs, sp_ubs
)
    nb_new_columns = 0
    while true # TODO Replace this condition when starting implement stabilization
        nb_new_col, sp_db_contrib =  solve_sps_to_gencols!(reform, redcostsvec, dual_sol, sp_lbs, sp_ubs)
        nb_new_columns += nb_new_col
        lagran_bnd = calculate_lagrangian_db(algdata, master_val, sp_db_contrib)
        update_ip_dual_bound!(algdata.incumbents, lagran_bnd)
        update_lp_dual_bound!(algdata.incumbents, lagran_bnd)
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

function cg_main_loop(
    algdata::ColGenRuntimeData, reform::Reformulation, phase::Int
)::ColumnGenerationResult
    nb_cg_iterations = 0
    # Phase II loop: Iterate while can generate new columns and
    # termination by bound does not apply
    masterform = getmaster(reform)
    sp_lbs = Dict{FormId, Float64}()
    sp_ubs = Dict{FormId, Float64}()

    # collect multiplicity current bounds for each sp
    # create the vector of perenecosts for sp variables having a DwSp duty.
    dwspvars = Vector{VarId}()
    dwspforms = Vector{Formulation}()

    for (spid, spform) in get_dw_pricing_sps(reform)
        lb_convexity_constr_id = reform.dw_pricing_sp_lb[spid]
        ub_convexity_constr_id = reform.dw_pricing_sp_ub[spid]
        sp_lbs[spid] = getcurrhs(masterform, lb_convexity_constr_id)
        sp_ubs[spid] = getcurrhs(masterform, ub_convexity_constr_id)

        for (varid, var) in getvars(spform)
            if getcurisactive(spform, varid) && getduty(var) <= AbstractDwSpVar
                push!(dwspvars, varid)
                push!(dwspforms, spform)
            end
        end
    end
    redcostsvec = ReducedCostsVector(dwspvars, dwspforms)

    while true
        master_status, master_val, primal_sols, dual_sols, master_time =
            solve_restricted_master!(masterform)

        if (phase != 1 && (master_status == MOI.INFEASIBLE
            || master_status == MOI.INFEASIBLE_OR_UNBOUNDED))
            @error "Solver returned that restricted master LP is infeasible or unbounded (status = $master_status) during phase != 1."
            return ColumnGenerationResult(algdata.incumbents, true)
        end

        update_lp_primal_sol!(algdata.incumbents, primal_sols[1])
        if isinteger(primal_sols[1]) && !contains(masterform, primal_sols[1], MasterArtVar)
            update_ip_primal_sol!(algdata.incumbents, primal_sols[1])
        end

        # TODO: cleanup restricted master columns        

        nb_cg_iterations += 1

        # generate new columns by solving the subproblems
        sp_time = @elapsed begin
            nb_new_col = generatecolumns!(
                algdata, reform, redcostsvec, master_val, dual_sols[1], sp_lbs, sp_ubs
            )
        end

        if nb_new_col < 0
            @error "Infeasible subproblem."
            return ColumnGenerationResult(algdata.incumbents, true)
        end

        print_intermediate_statistics(
            algdata, nb_new_col, nb_cg_iterations, master_time, sp_time
        )

        # TODO: update colgen stabilization

        dual_bound = get_ip_dual_bound(algdata.incumbents)
        primal_bound = get_lp_primal_bound(algdata.incumbents)     
        ip_primal_bound = get_ip_primal_bound(algdata.incumbents)

        if diff(dual_bound, ip_primal_bound) < algdata.params.optimality_tol
            algdata.has_converged = false # ???
            @logmsg LogLevel(1) "Dual bound reached primal bound."
            return ColumnGenerationResult(algdata.incumbents, false)
        end
        if phase == 1 && ph_one_infeasible_db(dual_bound)
            algdata.is_feasible = false
            @logmsg LogLevel(1) "Phase one determines infeasibility."
            return ColumnGenerationResult(algdata.incumbents, true)
        end
        if nb_new_col == 0 || gap(primal_bound, dual_bound) < algdata.params.optimality_tol
            @logmsg LogLevel(1) "Column Generation Algorithm has converged."
            algdata.has_converged = true
            return ColumnGenerationResult(algdata.incumbents, false)
        end
        if nb_cg_iterations > algdata.params.max_nb_iterations
            @warn "Maximum number of column generation iteration is reached."
            return ColumnGenerationResult(algdata.incumbents, false)
        end
    end
    return ColumnGenerationResult(algdata.incumbents, false)
end

function print_intermediate_statistics(
    algdata::ColGenRuntimeData, nb_new_col::Int, nb_cg_iterations::Int,
    mst_time::Float64, sp_time::Float64
)
    mlp = getvalue(get_lp_primal_bound(algdata.incumbents))
    db = getvalue(get_ip_dual_bound(algdata.incumbents))
    pb = getvalue(get_ip_primal_bound(algdata.incumbents))
    @printf(
        "<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cols=%2i> <mlp=%10.4f> <DB=%10.4f> <PB=%.4f>\n",
        nb_cg_iterations, Coluna._elapsed_solve_time(), mst_time, sp_time, nb_new_col, mlp, db, pb
    )
    return
end

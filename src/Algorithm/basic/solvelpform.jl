"""
    Coluna.Algorithm.SolveLpForm(
        get_dual_solution = false,
        relax_integrality = false,
        set_dual_bound = false,
        silent = true
    )

Solve a linear program.
"""
@with_kw struct SolveLpForm <: AbstractOptimizationAlgorithm 
    update_ip_primal_solution = false
    consider_partial_solution = false
    get_dual_solution = false
    relax_integrality = false
    set_dual_bound = false
    silent = true
    log_level = 0
end

# SolveLpForm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_storages_usage(
    algo::SolveLpForm, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storages in the read only mode, as relaxing integrality
    # is reverted before the end of the algorithm, 
    # so the state of the formulation remains the same 
    storages_usage = Tuple{AbstractModel, StorageTypePair, StorageAccessMode}[] 
    push!(storages_usage, (form, StaticVarConstrStoragePair, READ_ONLY))
    if Duty <: MathProg.AbstractMasterDuty
        push!(storages_usage, (form, MasterColumnsStoragePair, READ_ONLY))
        push!(storages_usage, (form, MasterBranchConstrsStoragePair, READ_ONLY))
        push!(storages_usage, (form, MasterCutsStoragePair, READ_ONLY))
    end
    if algo.consider_partial_solution
        push!(storages_usage, (form, PartialSolutionStoragePair, READ_ONLY))
    end
    return storages_usage
end

function optimize_lp_form!(algo::SolveLpForm, optimizer, form::Formulation) # fallback
    error("Cannot optimize LP formulation with optimizer of type ", typeof(optimizer), ".")
end

function optimize_lp_form!(algo::SolveLpForm, optimizer::MoiOptimizer, form::Formulation)
    MOI.set(form.optimizer.inner, MOI.Silent(), algo.silent)
    result = OptimizationState(form)
    optimize_with_moi!(optimizer, form, result)
    for primal_sol in get_primal_solutions(form, optimizer)
        add_lp_primal_sol!(result, primal_sol)
    end
    if algo.get_dual_solution
        for dual_sol in get_dual_solutions(form, optimizer)
            add_lp_dual_sol!(result, dual_sol)
        end
    end
    return result
end

function run!(algo::SolveLpForm, data::ModelData, input::OptimizationInput)::OptimizationOutput
    form = getmodel(data)
    optstate = OptimizationState(form)

    TO.@timeit Coluna._to "SolveLpForm" begin

    if algo.relax_integrality
        relax_integrality!(form)
    end

    partial_sol = nothing
    partial_sol_val = 0.0
    if algo.consider_partial_solution
        partsolstorage = getstorage(data, PartialSolutionStoragePair)
        partial_sol = get_primal_solution(partsolstorage, form)
        partial_sol_val = getvalue(partial_sol)
    end

    optimizer_result = optimize_lp_form!(algo, getoptimizer(form), form)
 
    setterminationstatus!(optstate, getterminationstatus(optimizer_result))   

    lp_primal_sol = get_best_lp_primal_sol(optimizer_result)
    if lp_primal_sol !== nothing
        add_lp_primal_sol!(optstate, lp_primal_sol)
        set_lp_primal_bound!(optstate, get_lp_primal_bound(optstate) + partial_sol_val)
        if algo.update_ip_primal_solution && isinteger(lp_primal_sol) && 
            !contains(lp_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
            if partial_sol !== nothing
                add_ip_primal_sol!(optstate, cat(lp_primal_sol, partial_sol))
            else
                add_ip_primal_sol!(optstate, lp_primal_sol)
            end
        end
    end

    if algo.get_dual_solution
        lp_dual_sol = get_best_lp_dual_sol(optimizer_result)
        if lp_dual_sol !== nothing
            if algo.set_dual_bound
                update_lp_dual_sol!(optstate, lp_dual_sol)
                set_lp_dual_bound!(optstate, get_lp_dual_bound(optstate) + partial_sol_val)
            else
                set_lp_dual_sol!(optstate, lp_dual_sol)
            end
        end
    end

    end # @timeit
    return OptimizationOutput(optstate)
end

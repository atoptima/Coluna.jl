"""
    SolveLpForm

todo
"""
Base.@kwdef struct SolveLpForm <: AbstractOptimizationAlgorithm 
    get_dual_solution = false
    relax_integrality = false
    set_dual_bound = false
    log_level = 0
end

function get_storages_usage!(
    algo::SolveLpForm, form::Formulation, storages_usage::StoragesUsageDict
)
    add!(storages_usage, form, BranchingConstrsStorage)
    add!(storages_usage, form, MasterColumnsStorage)
end

function get_storages_to_restore!(
    algo::SolveLpForm, form::Formulation, storages_to_restore::StoragesToRestoreDict
) 
    add!(storages_to_restore, form, BranchingConstrsStorage, READ_ONLY)
    add!(
        storages_to_restore, form, MasterColumnsStorage, 
        algo.relax_integrality ? READ_AND_WRITE : READ_ONLY
    )
end

function run!(algo::SolveLpForm, form::Formulation, input::OptimizationInput)::OptimizationOutput
    optstate = OptimizationState(form)

    if algo.relax_integrality
        relax_integrality!(form)
    end

    optimizer_result = optimize!(form)

    setfeasibilitystatus!(optstate, getfeasibilitystatus(optimizer_result))    
    setterminationstatus!(optstate, getterminationstatus(optimizer_result))   

    lp_primal_sol = getbestprimalsol(optimizer_result)
    if lp_primal_sol !== nothing
        add_lp_primal_sol!(optstate, lp_primal_sol)
        if isinteger(lp_primal_sol) && !contains(lp_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
            add_ip_primal_sol!(optstate, lp_primal_sol)
        end
    end

    if algo.get_dual_solution
        lp_dual_sol = getbestdualsol(optimizer_result)
        if lp_dual_sol !== nothing
            if algo.set_dual_bound
                update_lp_dual_sol!(optstate, lp_dual_sol)
            else
                set_lp_dual_sol!(optstate, lp_dual_sol)
            end
        end
    end

    return OptimizationOutput(optstate)
end

"""
    SolveLpForm

todo
"""
Base.@kwdef struct SolveLpForm <: AbstractOptimizationAlgorithm 
    get_dual_solution = false
    relax_integrality = false
    set_dual_bound = false
    silent = true
    log_level = 0
end

function get_storages_usage!(
    algo::SolveLpForm, form::Formulation{Duty}, storages_usage::StoragesUsageDict
) where {Duty<:MathProg.AbstractFormDuty}
    add_storage!(storages_usage, form, StaticVarConstrStorage)
    if Duty <: MathProg.AbstractMasterDuty
        add_storage!(storages_usage, form, MasterColumnsStorage)
        add_storage!(storages_usage, form, MasterBranchConstrsStorage)
        add_storage!(storages_usage, form, MasterCutsStorage)
    end
end

function get_storages_to_restore!(
    algo::SolveLpForm, form::Formulation{Duty}, storages_to_restore::StoragesToRestoreDict
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storages in the read only mode, as relaxing integrality
    # is reverted before the end of the algorithm, 
    # so the state of the formulation remains the same 
    add_storage!(storages_to_restore, form, StaticVarConstrStorage, READ_ONLY)
    if Duty <: MathProg.AbstractMasterDuty
        add_storage!(storages_to_restore, form, MasterColumnsStorage, READ_ONLY)
        add_storage!(storages_to_restore, form, MasterBranchConstrsStorage, READ_ONLY)
        add_storage!(storages_to_restore, form, MasterCutsStorage, READ_ONLY)
    end        
end

function optimize_lp_form!(algo::SolveLpForm, optimizer, form::Formulation) # fallback
    error("Cannot optimize LP formulation with optimizer of type ", typeof(optimizer), ".")
end

function optimize_lp_form!(algo::SolveLpForm, optimizer::MoiOptimizer, form::Formulation)
    MOI.set(form.optimizer.inner, MOI.Silent(), algo.silent)
    return optimize!(form)
end

function run!(algo::SolveLpForm, data::ModelData, input::OptimizationInput)::OptimizationOutput
    form = getmodel(data)
    optstate = OptimizationState(form)

    TO.@timeit Coluna._to "SolveLpForm" begin

    if algo.relax_integrality
        relax_integrality!(form)
    end

    optimizer_result = optimize_lp_form!(algo, getoptimizer(form), form)

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

    end 
    return OptimizationOutput(optstate)
end

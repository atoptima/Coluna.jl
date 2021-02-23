"""
todo
"""
@with_kw struct CutCallbacks <: AbstractAlgorithm
    call_robust_facultative = true
    call_robust_core = true
    #call_nonrobust_facultative = false
    #call_nonrobust_core = false
    tol = 1e-6
end

struct CutCallbacksInput
    primalsol::PrimalSolution
end

struct CutCallbacksOutput
    nb_cuts_added::Int
end

struct RobustCutCallbackContext
    form::Formulation
    env::Env
    constrkind::ConstrKind
    proj_sol::PrimalSolution # ordered non zero but O(log^2(n)) lookup time
    proj_sol_dict::Dict{VarId, Float64} # O(1) lookup time
    viol_vals::Vector{Float64}
end

# CutCallbacks does not have child algorithms, therefore get_child_algorithms() is not defined

function get_storages_usage(algo::CutCallbacks, form::Formulation{Duty}
    ) where {Duty<:MathProg.AbstractFormDuty} 
    return [(form, MasterCutsStoragePair, READ_AND_WRITE)]
end

function run!(algo::CutCallbacks, env::Env, data::ModelData, input::CutCallbacksInput)
    form = getmodel(data)
    robust_generators = get_robust_constr_generators(form)
    nb_cuts = 0
    if length(robust_generators) > 0 && (algo.call_robust_facultative || algo.call_robust_core)
        !projection_is_possible(form) && error("Cannot do projection on original variables. Open an issue.")

        projsol1 = proj_cols_on_rep(input.primalsol, form)
        projsol2 = Dict{VarId, Float64}(varid => val for (varid, val) in projsol1)
        viol_vals = Float64[]

        for constrgen in robust_generators
            if constrgen.kind == Facultative && !algo.call_robust_facultative
                continue
            end
            if constrgen.kind == Essential && !algo.call_robust_core
                continue
            end
            context = RobustCutCallbackContext(
                form, env, constrgen.kind, projsol1, projsol2, viol_vals
            )
            constrgen.separation_alg(context)
        end

        nb_cuts += length(viol_vals)
        zeroviols = 0
        for v in viol_vals
            if v < algo.tol
                zeroviols += 1
            end
        end

        @printf "Robust cut separation callback adds %i new cuts\n" nb_cuts
        if nb_cuts > 0
            @printf(
                "avg. viol. = %.2f, max. viol. = %.2f, zero viol. = %i.\n",
                mean(viol_vals), maximum(viol_vals), zeroviols
            )
        end
    end

    return CutCallbacksOutput(nb_cuts)
end

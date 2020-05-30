"""
todo
"""
Base.@kwdef struct CutCallbacks <: AbstractAlgorithm
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
    proj_sol::PrimalSolution # ordered non zero but O(log^2(n)) lookup time
    proj_sol_dict::Dict{VarId, Float64} # O(1) lookup time
    viol_vals::Vector{Float64}
end

function run!(algo::CutCallbacks, data::ModelData, input::CutCallbacksInput)
    form = getmodel(data)
    nb_cuts = 0
    robust_generators = get_robust_constr_generators(form)
    if length(robust_generators) > 0 && (algo.call_robust_facultative || algo.call_robust_core)
        !projection_is_possible(form) && error("Cannot do projection on original variables. Open an issue.")

        projsol1 = proj_cols_on_rep(input.primalsol, form)
        projsol2 = Dict{VarId, Float64}(varid => val for (varid, val) in projsol1)
        context = RobustCutCallbackContext(form, projsol1, projsol2, Float64[])

        for constrgen in robust_generators
            if constrgen.kind == Facultative && algo.call_robust_facultative
                constrgen.separation_alg(context)
            elseif constrgen.kind == Core && algo.call_robust_core
                constrgen.separation_alg(context)
            end
        end
        nb_cuts += length(context.viol_vals)

        zeroviols = 0
        for v in context.viol_vals
            if v < algo.tol
                zeroviols += 1
            end
        end

        nb_new_cuts = length(context.viol_vals)
        @printf "Robust cut separation callback adds %i new cuts\n" nb_new_cuts
        if nb_new_cuts > 0
            @printf(
                "avg. viol. = %.2f, max. viol. = %.2f, zero. viol. = %i.\n",
                mean(context.viol_vals), maximum(context.viol_vals), zeroviols
            )
        end
    end
    
    return CutCallbacksOutput(nb_cuts)
end
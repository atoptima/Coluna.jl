"""
    CutCallbacks(
        call_robust_facultative = true,
        call_robust_essential = true,
        tol::Float64 = 1e-6
    )

Runs the cut user callbacks attached to a formulation.

**Parameters:**
- `call_robust_facultative`: if true, call all the robust facultative cut user callbacks (i.e. user cut callbacks)
- `call_robust_essential`: if true, call all the robust essential cut user callbacks (i.e. lazy constraint callbacks)
- `tol`: tolerance used to determine if a cut is violated

See the JuMP documentation for more information about user callbacks and the tutorials in the
Coluna documentation for examples of user callbacks.
"""
@with_kw struct CutCallbacks <: AlgoAPI.AbstractAlgorithm
    call_robust_facultative = true
    call_robust_essential = true
    tol = 1e-6
end

struct CutCallbacksInput
    primalsol::PrimalSolution
end

struct CutCallbacksOutput
    nb_cuts_added::Int
    nb_essential_cuts_added::Int
    nb_facultative_cuts_added::Int
end
struct RobustCutCallbackContext
    form::Formulation
    env::Env
    constrkind::ConstrKind
    proj_sol::PrimalSolution # ordered non zero but O(log^2(n)) lookup time
    proj_sol_dict::Dict{VarId, Float64} # O(1) lookup time
    viol_vals::Vector{Float64}
    orig_sol::PrimalSolution
end

# CutCallbacks does not have child algorithms, therefore get_child_algorithms() is not defined

function get_units_usage(algo::CutCallbacks, form::Formulation{Duty}
    ) where {Duty<:MathProg.AbstractFormDuty} 
    return [(form, MasterCutsUnit, READ_AND_WRITE)]
end

function run!(algo::CutCallbacks, env::Env, form::Formulation, input::CutCallbacksInput)
    robust_generators = get_robust_constr_generators(form)
    nb_ess_cuts = 0
    nb_fac_cuts = 0
    if length(robust_generators) > 0 && (algo.call_robust_facultative || algo.call_robust_essential)
        !MathProg.projection_is_possible(form) && error("Cannot do projection on original variables. Open an issue.")

        projsol1 = proj_cols_on_rep(input.primalsol)
        projsol2 = Dict{VarId, Float64}(varid => val for (varid, val) in projsol1)
        viol_vals = Float64[]

        for constrgen in robust_generators
            cur_viol_vals = Float64[]
            if constrgen.kind == Facultative && !algo.call_robust_facultative
                continue
            end
            if constrgen.kind == Essential && !algo.call_robust_essential
                continue
            end
            context = RobustCutCallbackContext(
                form, env, constrgen.kind, projsol1, projsol2, cur_viol_vals, input.primalsol
            )
            constrgen.separation_alg(context)
            if constrgen.kind == Facultative
                nb_fac_cuts += length(cur_viol_vals)
            else
                nb_ess_cuts += length(cur_viol_vals)
            end
            for v in cur_viol_vals
                push!(viol_vals, v)
            end
        end

        zeroviols = 0
        for v in viol_vals
            if v < algo.tol
                zeroviols += 1
            end
        end

        @printf "Cut separation callback adds %i new essential cuts " nb_ess_cuts
        @printf "and %i new facultative cuts.\n" nb_fac_cuts
        if nb_fac_cuts + nb_ess_cuts > 0
            @printf(
                "avg. viol. = %.2f, max. viol. = %.2f, zero viol. = %i.\n",
                mean(viol_vals), maximum(viol_vals), zeroviols
            )
        end
    end

    return CutCallbacksOutput(nb_ess_cuts + nb_fac_cuts, nb_ess_cuts, nb_fac_cuts)
end

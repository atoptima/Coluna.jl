"""
todo
"""
Base.@kwdef struct CutCallbacks <: AbstractAlgorithm
    call_robust_facultative = true
    call_robust_core = true
    #call_nonrobust_facultative = false
    #call_nonrobust_core = false
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
end

function run!(algo::CutCallbacks, data::ModelData, input::CutCallbacksInput)
    form = getmodel(data)

    robust_generators = get_robust_constr_generators(form)
    if length(robust_generators) > 0 && (algo.call_robust_facultative || algo.call_robust_core)
        !projection_is_possible(form) && error("Cannot do projection on original variables. Open an issue.")

        projsol1 = proj_cols_on_rep(input.primalsol, form)
        projsol2 = Dict{VarId, Float64}(varid => val for (varid, val) in projsol1)
        context = RobustCutCallbackContext(form, projsol1, projsol2)

        for constrgen in robust_generators
            if constrgen.kind == Facultative && algo.call_robust_facultative
                constrgen.separation_alg(context)
            elseif constrgen.kind == Core && algo.call_robust_core
                constrgen.separation_alg(context)
            end
        end
        
    end


    return CutCallbacksOutput(0)
end
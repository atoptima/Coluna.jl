
function set_block(model::JuMP.Model, var_ref::JuMP.VariableRef, block::Int)
    MOI.set(model, Coluna.VariableDantzigWolfeAnnotation(),
        var_ref, block)
end

function set_block(model::JuMP.Model, constr_ref::JuMP.ConstraintRef, block::Int)
    MOI.set(model, Coluna.ConstraintDantzigWolfeAnnotation(),
        constr_ref, block)
end

function set_dantzig_wolfe_decompostion(model::JuMP.Model, decomp_func::Function)
    for name in keys(model.obj_dict)
        model_obj = model[name]
        if typeof(model_obj) <: Union{JuMP.VariableRef, JuMP.ConstraintRef}
            block = decomp_func(name, nothing)
            set_block(model, model_obj, block)
        else
            for index in keys(model_obj)
                block = decomp_func(name, index)
                set_block(model, model_obj[index], block)
            end
        end
    end
end

function set_dantzig_wolfe_cardinality_bounds(model::JuMP.Model,
        card_bounds_dict::Dict{Int, Tuple{Int,Int}})

    MOI.set(model, Coluna.DantzigWolfePricingCardinalityBounds(),
            card_bounds_dict)
end

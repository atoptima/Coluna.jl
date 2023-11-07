# # Propagation between formulations of Dantzig-Wolf reformulation.
# # In the following tests, we consider that the variables have the possible following duties

# # Original formulation:
# # variable:
# # - OriginalVar
# # constraint:
# # - OriginalConstr

# # Master:
# # variable:
# # - MasterRepPricingVar
# # - MasterPureVar
# # - MasterCol
# # - MasterArtVar
# # constraint:
# # - MasterPureConstr
# # - MasterMixedConstr
# # - MasterConvexityConstr

# # Pricing subproblems:
# # variable:
# # - DwSpPricingVar
# # - DwSpSetupVar
# # constraint:
# # - DwSpPureConstr

# ## Helpers

function _presolve_propagation_vars(form, var_descriptions)
    vars = Tuple{String, Coluna.MathProg.Variable}[]
    for (name, duty, cost, lb, ub, id, origin_form_id) in var_descriptions
        if isnothing(id)
            var = if isnothing(origin_form_id)
                Coluna.MathProg.setvar!(form, name, duty, cost = cost, lb = lb, ub = ub)
            else
                Coluna.MathProg.setvar!(
                    form, name, duty, cost = cost, lb = lb, ub = ub, id = Coluna.MathProg.VarId(
                        duty,
                        form.env.var_counter += 1,
                        origin_form_id;
                    )
                )
            end
        else
            id_of_clone = if isnothing(origin_form_id)
                ClMP.VarId(id; duty = duty)
            else
                ClMP.VarId(id; duty = duty, origin_form_uid = origin_form_id)
            end
            var = Coluna.MathProg.setvar!(form, name, duty; id = id_of_clone, cost = cost, lb = lb, ub = ub) 
        end
        push!(vars, (name, var))
    end
    return vars
end

function _presolve_propagation_constrs(form, constr_descriptions)
    constrs = Tuple{String, Coluna.MathProg.Constraint}[]
    for (name, duty, rhs, sense, id) in constr_descriptions
        if isnothing(id)
            constr = Coluna.MathProg.setconstr!(form, name, duty, rhs = rhs, sense = sense)
        else
            id_of_clone = ClMP.ConstrId(id; duty = duty)
            constr = Coluna.MathProg.setconstr!(form, name, duty; id = id_of_clone, rhs = rhs, sense = sense)
        end
        push!(constrs, (name, constr))
    end
    return constrs
end

function _mathprog_formulation!(env, form_duty, var_descriptions, constr_descriptions)
    form = Coluna.MathProg.create_formulation!(env, form_duty)

    vars = _presolve_propagation_vars(form, var_descriptions)
    constrs = _presolve_propagation_constrs(form, constr_descriptions)

    name_to_vars = Dict(name => var for (name, var) in vars)
    name_to_constrs = Dict(name => constr for (name, constr) in constrs)
    return form, name_to_vars, name_to_constrs
end

function _presolve_formulation(var_names, constr_names, matrix, form, name_to_vars, name_to_constrs; lm=1, um=1)
    rhs = [Coluna.MathProg.getcurrhs(form, name_to_constrs[name]) for name in constr_names]
    sense = [Coluna.MathProg.getcursense(form, name_to_constrs[name]) for name in constr_names]
    lbs = [Coluna.MathProg.getcurlb(form, name_to_vars[name]) for name in var_names]
    ubs = [Coluna.MathProg.getcurub(form, name_to_vars[name]) for name in var_names]
    partial_solution = zeros(Float64, length(lbs))

    form_repr = Coluna.Algorithm.PresolveFormRepr(
        matrix,
        rhs,
        sense,
        lbs, 
        ubs,
        partial_solution,
        lm,
        um
    )

    col_to_var = [name_to_vars[name] for name in var_names]
    row_to_constr = [name_to_constrs[name] for name in constr_names]
    var_to_col = Dict(ClMP.getid(name_to_vars[name]) => i for (i, name) in enumerate(var_names))
    constr_to_row = Dict(ClMP.getid(name_to_constrs[name]) => i for (i, name) in enumerate(constr_names))

    presolve_form = Coluna.Algorithm.PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form_repr,
        Coluna.MathProg.ConstrId[],
        Dict{Coluna.MathProg.VarId, Float64}()
    )
    return presolve_form
end
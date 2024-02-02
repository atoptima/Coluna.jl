function propagate_global_bounds!(
    presolve_repr_master::PresolveFormulation, presolve_sp::PresolveFormulation
)
    # TODO: does not work with representatives of multiple subproblems.
    lm = presolve_sp.form.lower_multiplicity
    um = presolve_sp.form.upper_multiplicity
    for (i, var) in enumerate(presolve_sp.col_to_var)
        repr_col = get(presolve_repr_master.var_to_col, getid(var), nothing)
        if !isnothing(repr_col)
            local_lb = presolve_sp.form.lbs[i]
            local_ub = presolve_sp.form.ubs[i]
            global_lb = presolve_repr_master.form.lbs[repr_col]
            global_ub = presolve_repr_master.form.ubs[repr_col]
            new_global_lb = local_lb * (local_lb < 0 ? um : lm)
            new_global_ub = local_ub * (local_ub < 0 ? lm : um)
            isnan(new_global_lb) && (new_global_lb = 0)
            isnan(new_global_ub) && (new_global_ub = 0)
            presolve_repr_master.form.lbs[repr_col] = max(global_lb, new_global_lb)
            presolve_repr_master.form.ubs[repr_col] = min(global_ub, new_global_ub)
        end
    end
    return
end

function propagate_local_bounds!(
    presolve_repr_master::PresolveFormulation, presolve_sp::PresolveFormulation
)
    # TODO: does not work with representatives of multiple subproblems.
    lm = presolve_sp.form.lower_multiplicity
    um = presolve_sp.form.upper_multiplicity
    for (i, var) in enumerate(presolve_sp.col_to_var)
        repr_col = get(presolve_repr_master.var_to_col, getid(var), nothing)
        if !isnothing(repr_col)
            global_lb = presolve_repr_master.form.lbs[repr_col]
            global_ub = presolve_repr_master.form.ubs[repr_col]
            local_lb = presolve_sp.form.lbs[i]
            local_ub = presolve_sp.form.ubs[i]

            if !isinf(global_lb) && !isinf(local_ub) && !isinf(um)
                new_local_lb = global_lb - (um - 1) * local_ub
                presolve_sp.form.lbs[i] = max(new_local_lb, local_lb)
            end

            if !isinf(global_ub) && !isinf(local_lb)
                new_local_ub = global_ub - max(0, lm - 1) * local_lb 
                presolve_sp.form.ubs[i] = min(new_local_ub, local_ub)
            end
        end
    end
    return
end

function get_partial_sol(
    presolve_form::PresolveFormulation, partial_sol_to_fix::Dict{VarId,Float64}
)
    new_partial_sol = zeros(Float64, length(presolve_form.col_to_var))
    for (var_id, value) in partial_sol_to_fix
        if !haskey(presolve_form.var_to_col, var_id) 
            if iszero(value)
                continue
            else 
                return nothing
            end
        end
        new_partial_sol[presolve_form.var_to_col[var_id]] += value
    end
    return new_partial_sol
end

function compute_rhs(presolve_form, restr_partial_sol)
    rhs = presolve_form.form.rhs
    coef_matrix = presolve_form.form.col_major_coef_matrix
    return rhs - coef_matrix * restr_partial_sol
end

function partial_sol_on_repr(
    dw_sps,
    presolve_master_repr::PresolveFormulation, 
    presolve_master_restr::PresolveFormulation,
    restr_partial_sol
)
    partial_solution = zeros(Float64, presolve_master_repr.form.nb_vars)

    nb_fixed_columns = Dict(spid => 0 for (spid, _) in dw_sps)
    new_column_explored = false
    for (col, partial_sol_value) in enumerate(restr_partial_sol)
        if abs(partial_sol_value) > Coluna.TOL
            var = presolve_master_restr.col_to_var[col]
            varid = getid(var)
            if getduty(varid) <= MasterCol
                spid = getoriginformuid(varid)
                spform = get(dw_sps, spid, nothing)
                @assert !isnothing(spform)
                column = @view get_primal_sol_pool(spform).solutions[varid,:]
                for (varid, val) in column
                    getduty(varid) <= DwSpPricingVar || continue
                    master_repr_var_col = get(presolve_master_repr.var_to_col, varid, nothing)
                    if !isnothing(master_repr_var_col)
                        partial_solution[master_repr_var_col] += val * partial_sol_value
                    end
                    if !new_column_explored
                        nb_fixed_columns[spid] += partial_sol_value
                        new_column_explored = true
                    end
                end
                new_column_explored = false
            elseif getduty(varid) <= MasterPureVar
                master_repr_var_col = get(presolve_master_repr.var_to_col, varid, nothing)
                if !isnothing(master_repr_var_col)
                    partial_solution[master_repr_var_col] += partial_sol_value
                end
            end
        end
    end
    return partial_solution, nb_fixed_columns
end

# For each master variable (master representative or master pure), 
# this function calculates the domain, i.e. intevals in which their new (global) bounds should lie
function compute_repr_master_var_domains(
    dw_pricing_sps, 
    presolve_reform::DwPresolveReform,
    local_repr_partial_sol
)
    sp_domains = Dict{VarId,Tuple{Float64,Float64}}()

    for (sp_id, sp_presolve_form) in presolve_reform.dw_sps
        lm = sp_presolve_form.form.lower_multiplicity
        um = sp_presolve_form.form.upper_multiplicity

        # Update domains for master representative variables using multiplicity.
        sp_form = dw_pricing_sps[sp_id]
        for (varid, var) in getvars(sp_form)
            if getduty(varid) <= DwSpPricingVar
                lb = getcurlb(sp_form, var)
                ub = getcurub(sp_form, var)

                (global_lb, global_ub) = get(sp_domains, varid, (0.0, 0.0))
                global_lb += isinf(lb) ? lb : (lb > 0 ? lm : um) * lb
                global_ub += isinf(ub) ? ub : (ub > 0 ? um : lm) * ub

                sp_domains[varid] = (global_lb, global_ub)
            end
        end
    end

    presolve_repr_master = presolve_reform.representative_master
    domains = Vector{Tuple{Float64, Float64}}()
    sizehint!(domains, presolve_repr_master.form.nb_vars)
    for col in 1:presolve_repr_master.form.nb_vars
        varid = getid(presolve_repr_master.col_to_var[col])
        domain = if haskey(sp_domains, varid)
            sp_domains[varid]
        elseif iszero(local_repr_partial_sol[col])
            (-Inf, Inf)
        elseif local_repr_partial_sol[col] > 0
            (0, Inf)
        else # local_repr_partial_sol[col] < 0
            (-Inf, 0)
        end
        push!(domains, domain)
    end

    return domains
end

function propagate_partial_sol_to_global_bounds!(
    presolve_repr_master, local_repr_partial_sol, master_var_domains
)
    new_lbs = zeros(Float64, presolve_repr_master.form.nb_vars)
    new_ubs = zeros(Float64, presolve_repr_master.form.nb_vars)

    for (col, (val, lb, ub, (min_value, max_value))) in enumerate(
        Iterators.zip(
            local_repr_partial_sol,
            presolve_repr_master.form.lbs,
            presolve_repr_master.form.ubs,
            master_var_domains
        )
    )
        new_lbs[col] = max(lb - val, min_value)
        new_ubs[col] = min(ub - val, max_value)
    end

    presolve_repr_master.form.lbs = new_lbs
    presolve_repr_master.form.ubs = new_ubs
    return
end

function propagate_in_presolve_form(
    form::PresolveFormulation,
    rows_to_deactivate::Vector{Int},
    tightened_bounds::Dict{Int,Tuple{Float64,Bool,Float64,Bool}}
)
    form_repr, row_mask, col_mask = PresolveFormRepr(
        form.form,
        rows_to_deactivate,
        tightened_bounds,
        form.form.lower_multiplicity,
        form.form.upper_multiplicity
    )

    col_to_var = form.col_to_var[col_mask]
    row_to_constr = form.row_to_constr[row_mask]

    deactivated_constrs = form.deactivated_constrs
    fixed_vars_dict = form.fixed_variables

    var_to_col = Dict(getid(var) => k for (k, var) in enumerate(col_to_var))
    constr_to_row = Dict(getid(constr) => k for (k, constr) in enumerate(row_to_constr))

    for constr in form.row_to_constr[.!row_mask]
        push!(deactivated_constrs, getid(constr))
    end

    @assert length(col_to_var) == length(form_repr.lbs)
    @assert length(col_to_var) == length(form_repr.ubs)
    @assert length(row_to_constr) == length(form_repr.rhs)

    return PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form_repr,
        deactivated_constrs,
        fixed_vars_dict
    )
end

function update_subproblem_multiplicities!(dw_sps, nb_fixed_columns_per_sp)
    for (spid, presolve_sp) in dw_sps
        lm = presolve_sp.form.lower_multiplicity
        um = presolve_sp.form.upper_multiplicity

        presolve_sp.form.lower_multiplicity = max(
            0, lm - nb_fixed_columns_per_sp[spid]
        )
        presolve_sp.form.upper_multiplicity = max(
            0, um - nb_fixed_columns_per_sp[spid]
        ) # TODO if < 0 -> error
    end
    return
end

"""
Returns the local restricted partial solution.
"""
function propagate_partial_sol_into_master!(
    reform::Reformulation, 
    presolve_reform::DwPresolveReform,
    partial_sol_to_fix::Dict{VarId,Float64},
    verbose::Bool
)
    presolve_representative_master = presolve_reform.representative_master
    presolve_restricted_master = presolve_reform.restricted_master

    # Create the local partial solution from the restricted master presolve representation.
    # This local partial solution must then be "fixed" & propagated.
    local_restr_partial_sol = get_partial_sol(presolve_restricted_master, partial_sol_to_fix)
    isnothing(local_restr_partial_sol) && return nothing

    # Compute the rhs of all constraints.
    # Non-robust and convexity constraints rhs can only be computed using this representation.
    new_rhs = compute_rhs(presolve_restricted_master, local_restr_partial_sol)

    # Project local partial solution on the representative master.
    local_repr_partial_sol, nb_fixed_columns_per_sp = partial_sol_on_repr(
        get_dw_pricing_sps(reform),
        presolve_representative_master,
        presolve_restricted_master,
        local_restr_partial_sol
    )

    if verbose
        print("Partial solution in the representative formulation:")
        master = getmaster(reform)
        for (var, value) in zip(presolve_representative_master.col_to_var, local_repr_partial_sol)
            if !iszero(value)
                print(" ", getname(master, var), "=>", value)
            end
        end
        println()
    end

    # Update the multiplicity of each subproblem.
    update_subproblem_multiplicities!(presolve_reform.dw_sps, nb_fixed_columns_per_sp)

    if verbose
        print("New subproblem multiplicities:")
        for (form_id, presolve_sp) in presolve_reform.dw_sps
            print(
                " sp.", 
                form_id, 
                ":[", 
                presolve_sp.form.lower_multiplicity, 
                ",", 
                presolve_sp.form.upper_multiplicity, 
                "]"
            )
        end
        println()
    end

    # Compute master variables domains (in which variable bounds should lie)
    master_var_domains = compute_repr_master_var_domains(
        get_dw_pricing_sps(reform), presolve_reform, local_repr_partial_sol
    )

    # Propagate local partial solution from the representative master representation
    # into the global bounds.
    propagate_partial_sol_to_global_bounds!(
        presolve_representative_master,
        local_repr_partial_sol,
        master_var_domains
    )

    if verbose
        print("Global bounds after fixing partial solution:")
        for (col, var) in enumerate(presolve_representative_master.col_to_var)
            print(
                " ", 
                getname(master, var), 
                ":[",
                presolve_representative_master.form.lbs[col], 
                ",", 
                presolve_representative_master.form.ubs[col], 
                "]"
            )
        end
        println()
    end

    # Update the rhs of the representative master.
    @assert length(new_rhs) == length(presolve_restricted_master.form.rhs) == 
        length(presolve_representative_master.form.rhs)
    for (row, rhs) in enumerate(new_rhs)
        presolve_representative_master.form.rhs[row] = rhs
    end
    return local_restr_partial_sol
end

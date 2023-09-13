struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
    deactivated_constrs::Vector{ConstrId}
    fixed_vars::Dict{VarId,Int}
end

struct DwPresolveReform
    original_master::PresolveFormulation
    restricted_master::PresolveFormulation
    dw_sps::Dict{FormId, PresolveFormulation}
end

function create_presolve_form(
    form::Formulation,
    keep_var::Function,
    keep_constr::Function;
    lower_multiplicity = 1, 
    upper_multiplicity = 1
)
    constr_ids, var_ids, nz = _submatrix_nz_elems(form, keep_constr, keep_var)

    var_to_col = Dict{VarId,Int64}()
    col_to_var = Variable[]
    for (k, varid) in enumerate(unique(var_ids))
        var = getvar(form, varid)
        @assert !isnothing(var)
        push!(col_to_var, var)
        var_to_col[varid] = k
    end

    constr_to_row = Dict{ConstrId,Int64}()
    row_to_constr = Constraint[]
    for (k, constrid) in enumerate(unique(constr_ids))
        constr = getconstr(form, constrid)
        @assert !isnothing(constr)
        push!(row_to_constr, constr)
        constr_to_row[constrid] = k
    end

    coef_submatrix = sparse(
        map(constr_id -> constr_to_row[constr_id], constr_ids),
        map(var_id -> var_to_col[var_id], var_ids),
        nz
    )

    lbs_vals = Float64[]
    ubs_vals = Float64[]
    for var in col_to_var
        push!(lbs_vals, getcurlb(form, var))
        push!(ubs_vals, getcurub(form, var))
    end

    rhs_vals = Float64[]
    sense_vals = Coluna.ConstrSense[]
    for constr in row_to_constr
        push!(rhs_vals, getcurrhs(form, constr))
        push!(sense_vals, getcursense(form, constr))
    end

    form = PresolveFormRepr(
        coef_submatrix,
        rhs_vals,
        sense_vals,
        lbs_vals,
        ubs_vals,
        lower_multiplicity,
        upper_multiplicity
    )

    deactivated_constrs = ConstrId[]
    fixed_vars = Dict{VarId,Float64}()

    return PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form,
        deactivated_constrs,
        fixed_vars,
    )
end

function propagate_in_presolve_form(
    form::PresolveFormulation,
    rows_to_deactivate::Vector{Int},
    vars_to_fix::Dict{Int, Float64},
    tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}}
)
    col_mask = ones(Bool, form.form.nb_vars)
    col_mask[collect(keys(vars_to_fix))] .= false
    row_mask = ones(Bool, form.form.nb_constrs)
    row_mask[rows_to_deactivate] .= false

    col_to_var = form.col_to_var[col_mask]
    row_to_constr = form.row_to_constr[row_mask]

    var_to_col = Dict(getid(var) => k for (k, var) in  enumerate(col_to_var))
    constr_to_row = Dict(getid(constr) => k for (k, constr) in enumerate(row_to_constr))

    deactivated_constrs = form.deactivated_constrs
    for constr in form.row_to_constr[rows_to_deactivate]
        push!(deactivated_constrs, getid(constr))
    end

    fixed_vars = form.fixed_vars
    for (col, val) in vars_to_fix
        var_id = getid(form.col_to_var[col])
        @assert !haskey(fixed_vars, var_id)
        fixed_vars[var_id] = val
    end

    return PresolveFormulation(
        col_to_var,
        row_to_constr, 
        var_to_col,
        constr_to_row,
        PresolveFormRepr(form.form, rows_to_deactivate, vars_to_fix, tightened_bounds, form.form.lower_multiplicity, form.form.upper_multiplicity),
        deactivated_constrs,
        fixed_vars
    )
end

function create_presolve_reform(reform::Reformulation{DwMaster})
    master = getmaster(reform)
    # Create the presolve formulations
    # Master 1:
    #     Variables: subproblem representatives & master pure 
    #     Constraints: master pure & master mixed & branching constraints & cuts
    original_master_vars = (form, varid, var) -> (
        (getduty(varid) <= MasterPureVar && iscuractive(form, var)) || 
        getduty(varid) <= MasterRepPricingVar
    )
    original_master_constrs = (form, constrid, constr) -> (
        iscuractive(form, constr) && (
            getduty(constrid) <= MasterPureConstr ||
            getduty(constrid) <= MasterMixedConstr ||
            getduty(constrid) <= MasterBranchOnOrigVarConstr ||
            getduty(constrid) <=  MasterUserCutConstr
        )
    )
    original_master = create_presolve_form(master, original_master_vars, original_master_constrs)

    # Master 2:
    #     Variables: columns & master pure & artifical variables
    #     Constraints: master pure & master mixed & convexity constraints & branching constraints & cuts
    restricted_master_vars = (form, varid, var) -> (
        iscuractive(form, var) && (
            getduty(varid) <= MasterPureVar ||
            getduty(varid) <= MasterCol ||
            getduty(varid) <= MasterArtVar
        )
    )
    restricted_master_constrs = (form, constrid, constr) -> (
        iscuractive(form, constr) && (
            getduty(constrid) <= MasterPureConstr ||
            getduty(constrid) <= MasterMixedConstr ||
            getduty(constrid) <= MasterConvexityConstr ||
            getduty(constrid) <= MasterBranchOnOrigVarConstr ||
            getduty(constrid) <=  MasterUserCutConstr
        )
    )
    restricted_master = create_presolve_form(master, restricted_master_vars, restricted_master_constrs)

    # Subproblems:
    #     Variables: pricing variables
    #     Constraints: DwSpPureConstr
    sp_vars = (form, varid, var) -> iscuractive(form, var) && getduty(varid) <= DwSpPricingVar
    sp_constrs = (form, constrid, constr) -> iscuractive(form, constr) && getduty(constrid) <= DwSpPureConstr

    dw_sps = Dict{FormId, PresolveFormulation}()
    for (spid, sp) in get_dw_pricing_sps(reform)
        lm = getcurrhs(master, sp.duty_data.lower_multiplicity_constr_id)
        um = getcurrhs(master, sp.duty_data.upper_multiplicity_constr_id)
        dw_sps[spid] = create_presolve_form(sp, sp_vars, sp_constrs, lower_multiplicity = lm, upper_multiplicity = um)
    end
    return DwPresolveReform(original_master, restricted_master, dw_sps)
end

function update_form_from_presolve!(form::Formulation, presolve_form::PresolveFormulation)
    # Deactivate Constraints
    for constr_id in presolve_form.deactivated_constrs
        deactivate!(form, getconstr(form, constr_id))
    end

    # Fix variables
    for (var_id, val) in presolve_form.fixed_vars
        # Do not propagate variable fixing! The new rhs of constraints is updated in the 
        # next step.
        fix!(form, getvar(form, var_id), val, false)
    end

    # Update rhs
    for (row, rhs) in enumerate(presolve_form.form.rhs)
        setcurrhs!(form, presolve_form.row_to_constr[row], rhs)
    end

    # Update bounds
    for (col, (lb, ub)) in enumerate(Iterators.zip(
        presolve_form.form.lbs,
        presolve_form.form.ubs
    ))
        setcurlb!(form, presolve_form.col_to_var[col], lb)
        setcurub!(form, presolve_form.col_to_var[col], ub)
    end
    return
end

function update_reform_from_presolve!(reform::Reformulation{DwMaster}, presolve_reform::DwPresolveReform)
    master = getmaster(reform)
    # Update master

    update_form_from_presolve!(master, presolve_reform.restricted_master.form)
    # Update subproblems
    for (spid, sp) in get_dw_pricing_sps(reform)
        update_form_from_presolve!(sp, presolve_reform.dw_sps[spid].form)
    end
    return
end

"""
Presolve algorithm
"""
struct PresolveAlgorithm <: AlgoAPI.AbstractAlgorithm
    ϵ::Float64
    PresolveAlgorithm(;ϵ = 1e-6) = new(ϵ)
end

function run!(algo::PresolveAlgorithm, ::Env, reform::Reformulation, _)
    treat!(algo, reform)
    return
end

function treat!(algo::PresolveAlgorithm, reform::Reformulation{DwMaster})
    presolve_reform = create_presolve_reform(reform)
    
    @show presolve_reform.original_master.form

    @show rows_to_deactivate!(presolve_reform.original_master.form)
    @show bounds_tightening(presolve_reform.original_master.form)

    @show presolve_reform

    update_reform!(reform, presolve_reform)
end
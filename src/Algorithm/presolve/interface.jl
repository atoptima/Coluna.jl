struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
    deactivated_constrs::Vector{ConstrId}
    fixed_variables::Dict{VarId, Float64}
end

mutable struct DwPresolveReform
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
    sm_constr_ids, sm_var_ids, nz = _submatrix_nz_elems(form, keep_constr, keep_var)

    constr_ids = Set{ConstrId}()
    for (constr_id, constr) in getconstrs(form)
        if keep_constr(form, constr_id, constr)
            push!(constr_ids, constr_id)
        end
    end

    var_ids = Set{VarId}()
    for (var_id, var) in getvars(form)
        if keep_var(form, var_id, var)
            push!(var_ids, var_id)
        end
    end

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
        map(constr_id -> constr_to_row[constr_id], sm_constr_ids),
        map(var_id -> var_to_col[var_id], sm_var_ids),
        nz,
        length(row_to_constr),
        length(col_to_var),
    )

    lbs_vals = Float64[]
    ubs_vals = Float64[]
    partial_sol = Float64[]
    for var in col_to_var
        push!(lbs_vals, getcurlb(form, var))
        push!(ubs_vals, getcurub(form, var))
        @assert !isnan(getcurlb(form, var))
        @assert !isnan(getcurub(form, var))
        #push!(partial_sol, MathProg.get_value_in_partial_sol(form, var))
        push!(partial_sol, 0.0)
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
        partial_sol,
        lower_multiplicity,
        upper_multiplicity
    )

    deactivated_constrs = ConstrId[]

    return PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form,
        deactivated_constrs,
        Dict{VarId, Float64}()
    )
end

function propagate_in_presolve_form(
    form::PresolveFormulation,
    rows_to_deactivate::Vector{Int},
    tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}};
    fix_vars = true
)
    fixed_vars = fix_vars ? vars_to_fix(form.form, tightened_bounds) : Dict{VarId, Float64}()

    col_mask = ones(Bool, form.form.nb_vars)
    if fix_vars
        col_mask[collect(keys(fixed_vars))] .= false
    end

    row_mask = ones(Bool, form.form.nb_constrs)
    row_mask[rows_to_deactivate] .= false

    col_to_var = form.col_to_var[col_mask]
    row_to_constr = form.row_to_constr[row_mask]

    var_to_col = Dict(getid(var) => k for (k, var) in enumerate(col_to_var))
    constr_to_row = Dict(getid(constr) => k for (k, constr) in enumerate(row_to_constr))

    deactivated_constrs = form.deactivated_constrs
    for constr in form.row_to_constr[rows_to_deactivate]
        push!(deactivated_constrs, getid(constr))
    end

    form_repr = PresolveFormRepr(
        form.form, 
        rows_to_deactivate, 
        tightened_bounds, 
        form.form.lower_multiplicity, 
        form.form.upper_multiplicity;
        fix_vars = fix_vars
    )

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

    master_repr_lb_ub = Dict{VarId, Tuple{Float64,Float64}}()

    dw_sps = Dict{FormId, PresolveFormulation}()
    for (spid, sp) in get_dw_pricing_sps(reform)
        lm = getcurrhs(master, sp.duty_data.lower_multiplicity_constr_id)
        um = getcurrhs(master, sp.duty_data.upper_multiplicity_constr_id)

        dw_sps[spid] = create_presolve_form(sp, sp_vars, sp_constrs, lower_multiplicity = lm, upper_multiplicity = um)
        
        # Update bounds on master repr variables using multiplicity.
        for (varid, var) in getvars(sp)
            if getduty(varid) <= DwSpPricingVar
                lb = getcurlb(sp, var)
                ub = getcurub(sp, var)
                
                (global_lb, global_ub) = get(master_repr_lb_ub, varid, (0.0, 0.0))
                global_lb += (lb > 0 ? lm : um) * lb
                global_ub += (ub > 0 ? um : lm) * ub
            
                master_repr_lb_ub[varid] = (global_lb, global_ub)
            end
        end
    end

    for (varid, (lb, ub)) in master_repr_lb_ub
        var_col = original_master.var_to_col[varid]
        @assert !isnan(lb)
        @assert !isnan(ub)
        original_master.form.lbs[var_col] = lb
        original_master.form.ubs[var_col] = ub
    end
    return DwPresolveReform(original_master, restricted_master, dw_sps)
end

function update_form_from_presolve!(
    form::Formulation, presolve_form::PresolveFormulation; update_rhs = true
)
    println("Updating formulation #$(getuid(form)).")
    # Deactivate Constraints
    constr_deactivation_counter = 0
    for constr_id in presolve_form.deactivated_constrs
        if iscuractive(form, getconstr(form, constr_id))
            deactivate!(form, getconstr(form, constr_id))
            constr_deactivation_counter += 1
        end
    end
    println("\t Deactivating $(constr_deactivation_counter) constraints.")

    # Fixed variables
    var_fix_counter = 0
    for (var_id, val) in presolve_form.fixed_variables
        if iscuractive(form, var_id)
            setcurlb!(form, var_id, 0.0)
            setcurub!(form, var_id, 0.0)
            MathProg.add_to_partial_solution!(form, var_id, val)
            deactivate!(form, var_id)
            var_fix_counter += 1
        end
    end
    println("\t Fixing $(var_fix_counter) variables.")

    # Update rhs
    if update_rhs
        for (row, rhs) in enumerate(presolve_form.form.rhs)
            constr = presolve_form.row_to_constr[row]

            if getduty(getid(constr)) <= MasterConvexityConstr
                if getcursense(form, constr) == Less
                    setcurrhs!(form, constr, max(rhs, 0))
                elseif getcursense(form, constr) == Greater
                    setcurrhs!(form, constr, max(rhs, 0))
                end
            else
                setcurrhs!(form, constr, rhs)
            end
        end
    end

    # Update bounds
    for (col, (lb, ub)) in enumerate(Iterators.zip(
        presolve_form.form.lbs,
        presolve_form.form.ubs
    ))
        @assert !isnan(lb)
        @assert !isnan(ub)
        var = presolve_form.col_to_var[col]

        if getduty(getid(var)) <= MasterCol
            @assert iszero(lb)
            setcurlb!(form, var, 0.0)
            # ignore the upper bound (we keep Inf)
        else
            setcurlb!(form, var, lb)
            setcurub!(form, var, ub)
        end
    end

    # Update partial solution
    partial_sol_counter = 0
    for (col, val) in enumerate(presolve_form.form.partial_solution)
        var = presolve_form.col_to_var[col]
        if getduty(getid(var)) <= MasterArtVar && !iszero(val)
            error(""" Infeasible because artificial variable $(getname(form, var)) is not zero.
            Fixed to $(val) in partial solution.
            """)
        end
        if !iszero(val)
            MathProg.add_to_partial_solution!(form, var, val)
            partial_sol_counter += 1
        end
    end
    println("\t Adding $(partial_sol_counter) variables to partial solution.")
    return
end

function update_reform_from_presolve!(reform::Reformulation{DwMaster}, presolve_reform::DwPresolveReform)
    master = getmaster(reform)

    # Update master
    presolve_restr_master = presolve_reform.restricted_master
    println("Updating restricted master.")
    update_form_from_presolve!(master, presolve_restr_master)

    # Update subproblems
    presolve_repr_master = presolve_reform.original_master
    for (spid, sp) in get_dw_pricing_sps(reform)
        sp_presolve_form = presolve_reform.dw_sps[spid]
        println("Updating subproblem.")
        update_form_from_presolve!(sp, sp_presolve_form)
    end

    println("Updating representative master.")
    update_form_from_presolve!(master, presolve_repr_master; update_rhs = false)
    return
end

"""
Presolve algorithm
"""
struct PresolveAlgorithm <: AlgoAPI.AbstractAlgorithm
    ϵ::Float64
    PresolveAlgorithm(;ϵ = Coluna.TOL) = new(ϵ)
end

# PresolveAlgorithm does not have child algorithms, therefore get_child_algorithms() is not defined
function get_units_usage(algo::PresolveAlgorithm, reform::Reformulation) 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[]
    master = getmaster(reform)
    push!(units_usage, (master, StaticVarConstrUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterBranchConstrsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterCutsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterColumnsUnit, READ_AND_WRITE))
    for (_, dw_sp) in get_dw_pricing_sps(reform)
        push!(units_usage, (dw_sp, StaticVarConstrUnit, READ_AND_WRITE))
    end
    return units_usage
end

struct PresolveInput
    partial_sol_to_fix::Dict{VarId, Float64}
    # may be instead?
    #partial_sol_to_fix::MathProg.PrimalSolution{Formulation{MasterDuty}}
end

struct PresolveOutput 
    feasible::Bool
end

function run!(algo::PresolveAlgorithm, ::Env, reform::Reformulation, input::PresolveInput)::PresolveOutput
    # TO DO : if input.partial_sol_to_fix is not empty, we first need to 
    #         1) augment partial solution inside reform.master with input.partial_sol_to_fix
    #         2) change RHS of master constraints correspondigly
    #         3) fix pure master variables in input.partial_sol_to_fix
    #         4) update global bounds of subproblem variables participating in columns in input.partial_sol_to_fix 
    #            (see document FixingColumnInColuna.md)

    # Should be move in the diving (when generating the formulation of the children because
    # formulation is the single source of truth).
    for (varid, val) in input.partial_sol_to_fix
        if MathProg.getduty(varid) <= MasterCol
            MathProg.setcurlb!(getmaster(reform), varid, val)
        else # especially for MasterPureVar
            MathProg.setcurlb!(getmaster(reform), varid, val)
            MathProg.setcurub!(getmaster(reform), varid, val)
        end
    end

    presolve_reform = create_presolve_reform(reform)

    print("Presolving representative master #1. ")
    tightened_bounds_repr = bounds_tightening(presolve_reform.original_master.form)
    println("$(length(tightened_bounds_repr)) tightened bounds.")
    repr_deactivate_constr = rows_to_deactivate(presolve_reform.original_master.form)
    new_original_master = propagate_in_presolve_form(presolve_reform.original_master, repr_deactivate_constr, tightened_bounds_repr; fix_vars = false)

    print("Presolving restricted master #1. ")
    tightened_bounds_restr = bounds_tightening(presolve_reform.restricted_master.form)
    println("$(length(tightened_bounds_restr)) tightened bounds.")
    restr_deactivate_constr = rows_to_deactivate(presolve_reform.restricted_master.form)
    new_restricted_master = propagate_in_presolve_form(presolve_reform.restricted_master, restr_deactivate_constr, tightened_bounds_restr)

    presolve_reform.restricted_master = new_restricted_master
    presolve_reform.original_master = new_original_master

    propagate_local_and_global_bounds!(reform, presolve_reform) # TODO: cannot perform this operation twice.

    print("Presolving representative master #2. ")
    tightened_bounds_repr = bounds_tightening(presolve_reform.original_master.form)
    println("$(length(tightened_bounds_repr)) tightened bounds.")
    new_original_master = propagate_in_presolve_form(presolve_reform.original_master, Int[], tightened_bounds_repr; fix_vars = false)

    print("Presolving restricted master #2. ")
    tightened_bounds_restr = bounds_tightening(presolve_reform.restricted_master.form)
    println("$(length(tightened_bounds_restr)) tightened bounds.")
    new_restricted_master = propagate_in_presolve_form(presolve_reform.restricted_master, Int[], tightened_bounds_restr)

    presolve_reform.restricted_master = new_restricted_master
    presolve_reform.original_master = new_original_master

    #propagate_local_and_global_bounds!(reform, presolve_reform)

    # # Compute global bounds of aggregated variables.
    # new_original_master = compute_global_bounds(presolve_reform.original_master, new_restricted_master)

    # # Propagate bounds from the original master to the subproblems
    # for (spid, sp) in presolve_reform.dw_sps
    #     propagate_var_bounds_from!(new_original_master, sp)
    # end

    update_reform_from_presolve!(reform, presolve_reform)

    return PresolveOutput(true)
end

function _column_is_proper(col_id, sp_form)
    # Retrieve the column in the pool.
    pool = get_primal_sol_pool(sp_form)
    solution = @view pool.solutions[col_id, :]

    for (var_id, value) in solution
        if value < getcurlb(sp_form, var_id) - Coluna.TOL || value > getcurub(sp_form, var_id) + Coluna.TOL
            return false
        end
    end
    return true
end

# function treat!(algo::PresolveAlgorithm, reform::Reformulation{DwMaster})
#     presolve_reform = create_presolve_reform(reform)
    
#     @show presolve_reform.original_master.form

#     @show rows_to_deactivate!(presolve_reform.original_master.form)
#     @show bounds_tightening(presolve_reform.original_master.form)

#     @show presolve_reform

#     update_reform!(reform, presolve_reform)
# end

"""
Stores a matrix-representation of the formulation and the mapping between the variables & 
constraints of the formulation to the row and column of the matrix and components of the 
vector that represents the formulation.
"""
struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
    deactivated_constrs::Vector{ConstrId}
    fixed_variables::Dict{VarId,Float64}
end

"""
Stores the presolve-representation of the formulations of the Dantzig-Wolfe reformulation.
This datastructure contains:

- `representative_master` that contains the master formulation expressed with representative
  variables and pure master variables
- `restricted_master` that contains the master formulation expressed with pure master variables,
   master columns, and artificial variables
- `dw_sps` a dictionary that contains the subproblem formulations.
"""
mutable struct DwPresolveReform
    representative_master::PresolveFormulation
    restricted_master::PresolveFormulation
    dw_sps::Dict{FormId,PresolveFormulation}
end

function create_presolve_form(
    form::Formulation,
    keep_var::Function,
    keep_constr::Function;
    lower_multiplicity=1,
    upper_multiplicity=1
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
        Dict{VarId,Float64}()
    )
end

function create_presolve_reform(reform::Reformulation{DwMaster}; verbose::Bool=false)
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
            getduty(constrid) <= MasterUserCutConstr ||
            getduty(constrid) <= MasterConvexityConstr
        )
    )
    original_master = create_presolve_form(master, original_master_vars, original_master_constrs)

    if verbose
        print("Initial original and global bounds:")
        for (col, var) in enumerate(original_master.col_to_var)
            print(
                " ", 
                getname(master, var), 
                ":[", 
                original_master.form.lbs[col], 
                ",", 
                original_master.form.ubs[col], 
                "]"
            )
        end
        println()
    end

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
            getduty(constrid) <= MasterBranchOnOrigVarConstr ||
            getduty(constrid) <= MasterUserCutConstr ||
            getduty(constrid) <= MasterConvexityConstr
        )
    )
    restricted_master = create_presolve_form(
        master, restricted_master_vars, restricted_master_constrs
    )

    # Subproblems:
    #     Variables: pricing variables
    #     Constraints: DwSpPureConstr
    sp_vars = (form, varid, var) -> iscuractive(form, var) && getduty(varid) <= DwSpPricingVar
    sp_constrs = (form, constrid, constr) -> iscuractive(form, constr) && 
        getduty(constrid) <= DwSpPureConstr

    dw_sps = Dict{FormId,PresolveFormulation}()
    for (spid, sp) in get_dw_pricing_sps(reform)
        lm = getcurrhs(master, sp.duty_data.lower_multiplicity_constr_id)
        um = getcurrhs(master, sp.duty_data.upper_multiplicity_constr_id)

        dw_sps[spid] = create_presolve_form(
            sp, sp_vars, sp_constrs, lower_multiplicity=lm, upper_multiplicity=um
        )
    end

    return DwPresolveReform(original_master, restricted_master, dw_sps)
end

function update_partial_sol!(
    form::Formulation{DwMaster}, presolve_form::PresolveFormulation, partial_solution
)
    # Update partial solution
    for (col, val) in enumerate(partial_solution)
        var = presolve_form.col_to_var[col]
        duty = getduty(getid(var))
        if duty <= MasterArtVar && !iszero(val)
            error(""" Infeasible because artificial variable $(getname(form, var)) is not zero.
            Fixed to $(val) in partial solution.
            """)
        end
        if !iszero(val) && (duty <= MasterCol || duty <= MasterPureVar)
            MathProg.add_to_partial_solution!(form, var, val)
        end
    end
    return
end

function _update_bounds!(form::Formulation, presolve_form::PresolveFormulation)
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
    return
end

function _update_rhs!(form::Formulation, presolve_form::PresolveFormulation)
    for (row, rhs) in enumerate(presolve_form.form.rhs)
        constr = presolve_form.row_to_constr[row]
        setcurrhs!(form, constr, rhs)
    end
    return
end

function update_form_from_presolve!(form::Formulation, presolve_form::PresolveFormulation)
    # Deactivate Constraints
    for constr_id in presolve_form.deactivated_constrs
        if iscuractive(form, getconstr(form, constr_id))
            deactivate!(form, getconstr(form, constr_id))
        end
    end

    _update_rhs!(form, presolve_form)
    _update_bounds!(form, presolve_form)
    return
end

function update_reform_from_presolve!(
    reform::Reformulation,
    presolve_reform::DwPresolveReform
)
    master = getmaster(reform)
    presolve_repr_master = presolve_reform.representative_master

    # Update subproblems
    for (spid, sp) in get_dw_pricing_sps(reform)
        sp_presolve_form = presolve_reform.dw_sps[spid]
        update_form_from_presolve!(sp, sp_presolve_form)
        lm_row = presolve_repr_master.constr_to_row[sp.duty_data.lower_multiplicity_constr_id]
        presolve_repr_master.form.rhs[lm_row] = sp_presolve_form.form.lower_multiplicity
        um_row = presolve_repr_master.constr_to_row[sp.duty_data.upper_multiplicity_constr_id]
        presolve_repr_master.form.rhs[um_row] = sp_presolve_form.form.upper_multiplicity
    end

    update_form_from_presolve!(master, presolve_repr_master)
    return
end

"""
Presolve algorithm
"""
struct PresolveAlgorithm <: AlgoAPI.AbstractAlgorithm
    ϵ::Float64
    verbose::Bool
    PresolveAlgorithm(; ϵ=Coluna.TOL, verbose=false) = new(ϵ, verbose)
end

# PresolveAlgorithm does not have child algorithms, therefore get_child_algorithms() is not defined
function get_units_usage(algo::PresolveAlgorithm, reform::Reformulation)
    units_usage = Tuple{AbstractModel,UnitType,UnitPermission}[]
    master = getmaster(reform)
    push!(units_usage, (master, StaticVarConstrUnit, READ_AND_WRITE))
    push!(units_usage, (master, PartialSolutionUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterBranchConstrsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterCutsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterColumnsUnit, READ_AND_WRITE))
    for (_, dw_sp) in get_dw_pricing_sps(reform)
        push!(units_usage, (dw_sp, StaticVarConstrUnit, READ_AND_WRITE))
    end
    return units_usage
end

struct PresolveInput
    partial_sol_to_fix::Dict{VarId,Float64}
end

struct PresolveOutput
    feasible::Bool
end

function presolve_formulation!(presolve_form::PresolveFormulation)
    tightened_bounds = bounds_tightening(presolve_form.form)
    presolve_form = propagate_in_presolve_form(presolve_form, Int[], tightened_bounds)
end

function check_feasibility!(form::Formulation, presolve_form::PresolveFormulation, verbose::Bool)
    form_repr = presolve_form.form
    if verbose
        for col in 1:form_repr.nb_vars
            if !(form_repr.lbs[col] <= form_repr.ubs[col])
                println(
                    "Infeasible due to variable ", 
                    getname(form, presolve_form.col_to_var[col]), 
                    " lb = ", 
                    form_repr.lbs[col], 
                    " ub = ", 
                    form_repr.ubs[col], 
                    " of form. ", 
                    getuid(form)
                )
                break
            end
        end
    end

    feasible = all(col -> form_repr.lbs[col] <= form_repr.ubs[col], 1:form_repr.nb_vars)

    if verbose && !feasible 
        println("Formulation ", getuid(form), " is infeasible!")
    end

    return feasible
end

function update_multiplicities!(presolve_repr_master, presolve_sp, feasible::Bool)
    l_mult, u_mult = if feasible 
        lm = presolve_sp.form.lower_multiplicity
        um = presolve_sp.form.upper_multiplicity
        for (var, local_lb, local_ub) in zip(
            presolve_sp.col_to_var, presolve_sp.form.lbs, presolve_sp.form.ubs
        )
            varid = getid(var)
            master_col = presolve_repr_master.var_to_col[varid] 
            global_lb = presolve_repr_master.form.lbs[master_col]
            global_ub = presolve_repr_master.form.ubs[master_col]

            # update of lower multiplicity
            if global_lb > 0 && local_ub > 0 
                # no need to check !isinf(global_lb)
                new_lm = ceil(global_lb / local_ub)
                lm = max(new_lm, lm)
            elseif global_ub < 0 && local_lb < 0
                # no need to check !isinf(global_ub)
                new_lm = ceil(global_ub / local_lb)
                lm = max(new_lm, lm)
            end

            # update of upper multiplicity
            if local_lb > 0 && global_ub > 0
                # no need to check !isinf(local_lb)
                new_um = floor(global_ub / local_lb)
                um = min(um, new_um)
            elseif local_ub < 0 && global_lb < 0
                # no need to check !isinf(local_ub)
                new_um = floor(global_lb / local_ub)
                um = min(um, new_um)
            end
        end
        lm, um
    else
        0, 0
    end

    presolve_sp.form.lower_multiplicity = l_mult
    presolve_sp.form.upper_multiplicity = u_mult
end

function presolve_iteration!(
    reform::Reformulation, presolve_reform::DwPresolveReform, verbose::Bool
)
    master = getmaster(reform)
    # Presolve the respresentative master.
    presolve_formulation!(presolve_reform.representative_master)

    if verbose
        print("Global bounds after presolve:")
        for (col, var) in enumerate(presolve_reform.representative_master.col_to_var)
            print(
                " ", 
                getname(master, var), 
                ":[", 
                presolve_reform.representative_master.form.lbs[col], 
                ",", 
                presolve_reform.representative_master.form.ubs[col], 
                "]"
            )
        end
        println()
    end

    # Presolve subproblems
    for (sp_id, presolve_sp) in presolve_reform.dw_sps
        iszero(presolve_sp.form.upper_multiplicity) && continue

        # Propagate and strengthen local bounds.
        propagate_local_bounds!(presolve_reform.representative_master, presolve_sp)

        if verbose
            println(
                "Multiplicities of $sp_id:[", 
                presolve_sp.form.lower_multiplicity,
                ",",
                presolve_sp.form.upper_multiplicity,
                "]"            
            )
            print("Local bounds of sp $sp_id after propagation from global bounds:")
            for (col, var) in enumerate(presolve_sp.col_to_var)
                print(
                    " ", 
                    getname(get_dw_pricing_sps(reform)[sp_id], var), 
                    ":[", 
                    presolve_sp.form.lbs[col], 
                    ",", 
                    presolve_sp.form.ubs[col], 
                    "]"
                )
            end
            println()    
        end

        presolve_formulation!(presolve_sp)

        if verbose
            print("Local bounds of sp $sp_id after presolve:")
            for (col, var) in enumerate(presolve_sp.col_to_var)
                print(
                    " ", 
                    getname(get_dw_pricing_sps(reform)[sp_id], var), 
                    ":[", 
                    presolve_sp.form.lbs[col], 
                    ",", 
                    presolve_sp.form.ubs[col], 
                    "]"
                )
            end
            println()   
        end 

        feasible = check_feasibility!(get_dw_pricing_sps(reform)[sp_id], presolve_sp, verbose)
        update_multiplicities!(presolve_reform.representative_master, presolve_sp, feasible)

        # Propagate and strengthen global bounds.
        propagate_global_bounds!(presolve_reform.representative_master, presolve_sp)
    end

    if verbose
        print("Global bounds after propagation from local bounds:")
        for (col, var) in enumerate(presolve_reform.representative_master.col_to_var)
            print(
                " ", 
                getname(master, var), 
                ":[", 
                presolve_reform.representative_master.form.lbs[col], 
                ",", 
                presolve_reform.representative_master.form.ubs[col], 
                "]"
            )
        end
        println()
    end

    return check_feasibility!(master, presolve_reform.representative_master, verbose)
end

function deactivate_non_proper_columns!(reform::Reformulation)
    master = getmaster(reform)
    dw_sps = get_dw_pricing_sps(reform)
    for (varid, _) in getvars(master)
        if getduty(varid) <= MasterCol
            spid = getoriginformuid(varid)
            if !_column_is_proper(varid, dw_sps[spid])
                deactivate!(master, varid)
            end
        end
    end
    return
end

function run!(
    algo::PresolveAlgorithm, ::Env, reform::Reformulation, input::PresolveInput
)::PresolveOutput
    algo.verbose && println("**** Start of presolve algorithm ****")

    presolve_reform = create_presolve_reform(reform; verbose = algo.verbose)

    # Identify the partial solution in the restricted master, compute the new rhs
    # of all master constraints and new global and local bounds of the representative and 
    # subproblem variables.
    local_restr_partial_sol = propagate_partial_sol_into_master!(
        reform, presolve_reform, input.partial_sol_to_fix, algo.verbose
    )
    isnothing(local_restr_partial_sol) && return PresolveOutput(false)

    # Perform several rounds of presolve.
    for i in 1:3
        algo.verbose && println("**** Presolve step $i ****")
        if presolve_iteration!(reform, presolve_reform, algo.verbose) == false
            algo.verbose && println("**** End of presolve algorithm ****")
            return PresolveOutput(false)
        end
    end

    update_partial_sol!(
        getmaster(reform), presolve_reform.restricted_master, local_restr_partial_sol
    )
    update_reform_from_presolve!(reform, presolve_reform)

    deactivate_non_proper_columns!(reform)
    algo.verbose && println("**** End of presolve algorithm ****")
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

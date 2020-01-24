struct Preprocess <: AbstractAlgorithm end

mutable struct PreprocessData
    depth::Int
    reformulation::Reformulation # Should handle reformulation & formulation
    constr_in_stack::Dict{ConstrId,Bool}
    stack::DS.Stack{Tuple{Constraint,Formulation}}
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
    cur_sp_bounds::Dict{FormId,Tuple{Int,Int}}
    local_partial_sol::Vector{Tuple{Variable, Int}}
    printing::Bool
end

function PreprocessData(depth::Int, reform::Reformulation)
    cur_sp_bounds = Dict{FormId,Tuple{Int,Int}}()
    master = getmaster(reform)
    for (spuid, spform) in get_dw_pricing_sps(reform)
        conv_lb = getconstr(master, reform.dw_pricing_sp_lb[spuid])
        conv_ub = getconstr(master, reform.dw_pricing_sp_ub[spuid])
        cur_sp_bounds[spuid] = (getcurrhs(master, conv_lb), getcurrhs(master, conv_ub))
    end
    return PreprocessData(
        depth, reform, Dict{ConstrId,Bool}(),
        DS.Stack{Tuple{Constraint, Formulation}}(), Dict{ConstrId,Float64}(),
        Dict{ConstrId,Float64}(), Dict{ConstrId,Int}(), Dict{ConstrId,Int}(), 
        Constraint[], Variable[], cur_sp_bounds, Tuple{Variable,Int}[], false
    )
end

struct PreprocessRecord <: AbstractAlgorithmResult
    proven_infeasible::Bool
end

function prepare!(algo::Preprocess, reformulation, node)
    @logmsg LogLevel(0) "Prepare preprocessing"
    return
end

function run!(algo::Preprocess, reformulation, node)
    @logmsg LogLevel(0) "Run preprocessing"

    alg_data = PreprocessData(node.depth, reformulation)
    master = getmaster(alg_data.reformulation)

    (vars_with_modified_bounds,
    constrs_with_modified_rhs) = fix_local_partial_solution!(alg_data)

    if initconstraints!(alg_data, constrs_with_modified_rhs)
        return PreprocessRecord(true) 
    end

    # Now we try to update local bounds of sp vars
    for var in vars_with_modified_bounds
        update_lower_bound!(alg, var, master, getcurlb(master, var), false)
        update_upper_bound!(alg, var, master, getcurub(master, var), false)
    end

    infeasible = propagation!(alg_data) 
    if !infeasible
        forbid_infeasible_columns!(alg_data)
    end
    return PreprocessRecord(infeasible) 
end

function change_sp_bounds!(alg_data::PreprocessData)
    reformulation = alg_data.reformulation
    master = getmaster(reformulation)
    sps_with_modified_bounds = []

    for (col, col_val) in alg_data.local_partial_sol
        spform = getsp(alg_data, col)
        sp_form_id = getuid(spform)
        if alg_data.cur_sp_bounds[sp_form_id][1] > 0
            alg_data.cur_sp_bounds[sp_form_id] = (
                max(alg.cur_sp_bounds[sp_form_id][1] - col_val, 0),
                alg.cur_sp_bounds[sp_form_id][2]
            )
            conv_lb_constr = getconstr(
                master, reformulation.dw_pricing_sp_lb[sp_form_id]
            )
            setrhs!(master, conv_lb_constr, alg.cur_sp_bounds[sp_form_id][1])
        end
        alg.cur_sp_bounds[sp_form_id] = (
            alg.cur_sp_bounds[sp_form_id][1],
            alg.cur_sp_bounds[sp_form_id][2] - col_val
        )
        conv_ub_constr = getconstr(
            master, reformulation.dw_pricing_sp_ub[sp_form_id]
        )
        setrhs!(master, conv_ub_constr, alg.cur_sp_bounds[sp_form_id][2])
        @assert alg.cur_sp_bounds[sp_ref][2] >= 0
        if !(spform in sps_with_modified_bounds)
            push!(sps_with_modified_bounds, spform)
        end
    end
    return sps_with_modified_bounds
end

function getsp(alg_data::PreprocessData, col::Variable)
    master = getmaster(alg_data.reformulation)
    primal_sp_sols = getprimalsolmatrix(master)
    for (sp_var_id, sp_var_val) in primal_sp_sols[:,getid(getid(col))]
        sp_var = getvar(master, sp_var_id)
        return find_owner_formulation(alg_data.reformulation, sp_var)
    end
end

function project_local_partial_solution(alg_data::PreprocessData)
    sp_vars_vals = Dict{VarId,Float64}()
    primal_sp_sols = getprimalsolmatrix(getmaster(alg_data.reformulation))
    for (col, col_val) in alg_data.local_partial_sol
        for (sp_var_id, sp_var_val) in primal_sp_sols[:,getid(getid(col))]
            if !haskey(sp_vars_vals, sp_var_id)
                sp_vars_vals[sp_var_id] = col_val * sp_var_val
            else
                sp_vars_vals[sp_var_id] += col_val * sp_var_val
            end
        end
    end
    return sp_vars_vals
end

function fix_local_partial_solution!(alg_data::PreprocessData)
    sps_with_modified_bounds = change_sp_bounds!(alg_data)
    sp_vars_vals = project_local_partial_solution(alg_data)

    # Updating rhs of master constraints
    master = getmaster(alg_data.reformulation)
    master_coef_matrix = getcoefmatrix(master)
    constrs_with_modified_rhs = Constraint[]
    for (var_id, val) in sp_vars_vals 
        for (constr_id, coef) in Iterators.filter(vc ->
            getcurisactive(master,vc) && getcurisexplicit(mastervc),
            master_coef_matrix[:,var_id])
            constr = getconstr(master, constr_id)
            setrhs!(master, constr, getcurrhs(master, constr) - val * coef)
            push!(constrs_with_modified_rhs, constr)
        end
    end

    # Changing global bounds of subprob variables
    vars_with_modified_bounds = Variable[]
    for sp_prob in sps_with_modified_bounds
        (cur_sp_lb, cur_sp_ub) = alg.cur_sp_bounds[getuid(sp_prob)]

        for (var_id, var) in Iterators.filter(
            v -> getcurisactive(spform,v) == true && getduty(v) <= AbstractDwSpVar,
            getvars(spform))
            var_val_in_local_sol = (
                haskey(sp_vars_vals, var_id) ? sp_vars_vals[var_id] : 0.0
            )
            bounds_changed = false

            clone_in_master = getvar(master, var_id)
            new_global_lb = max(
                getcurlb(master, clone_in_master) - var_val_in_local_sol,
                getcurlb(sp_prob, var) * cur_sp_lb
            )
            if new_global_lb != getcurlb(master, clone_in_master)
                setlb!(clone_in_master) = new_global_lb
                bounds_changed = true
            end

            new_global_ub = min(
                getcurub(master, clone_in_master) - var_val_in_local_sol,
                getcurub(sp_prob, var) * cur_sp_ub
            )
            if new_global_ub != getcurub(master, clone_in_master)
                setub!(clone_in_master) = new_global_ub
                bounds_changed = true
            end

            if bounds_changed
                push!(vars_with_modified_bounds, clone_in_master)
            end
        end
    end
    return (vars_with_modified_bounds, constrs_with_modified_rhs)
end

function initconstraints!(
        alg_data::PreprocessData, constrs_with_modified_rhs::Vector{Constraint}
    )

    # Contains the constraints to start propagation
    constrs_to_stack = Tuple{Constraint,Formulation}[]

    # Master constraints
    master = getmaster(alg_data.reformulation)
    master_coef_matrix = getcoefmatrix(master)
    for (constr_id, constr) in Iterators.filter(
        c -> getcurisactive(master,c) && getcurisexplicit(master, c), 
        getconstrs(master))
        if getduty(constr) != MasterConvexityConstr
            initconstraint!(alg_data, constr, master)
            push!(constrs_to_stack, (constr, master))
        end
    end

    # Subproblem constraints
    for (spuid, spform) in get_dw_pricing_sps(alg_data.reformulation)
        for (constr_id, constr) in Iterators.filter(
            c -> getcurisactive(spform,c) && getcurisexplicit(spform, c), 
            getconstrs(spform))
            initconstraint!(alg_data, constr, spform)
            push!(constrs_to_stack, (constr, spform))
        end
    end

    # We add to the stack all constraints affected
    # by the fixing of the local partial sol
    for constr in constrs_with_modified_rhs
        if !((constr, master) in constrs_to_stack)
            push!(constrs_to_stack, (constr, master))
        end
    end

    # Adding constraints to stack
    for (constr, form) in constrs_to_stack
        if (update_min_slack!(alg_data, constr, form, false, 0.0) 
            || update_max_slack!(alg_data, constr, form, false, 0.0))
            return true
        end
    end
    return false
end

function initconstraint!(
    alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    alg_data.constr_in_stack[getid(constr)] = false
    alg_data.nb_inf_sources_for_min_slack[getid(constr)] = 0
    alg_data.nb_inf_sources_for_max_slack[getid(constr)] = 0
    compute_min_slack!(alg_data, constr, form)
    compute_max_slack!(alg_data, constr, form)
    return
end

function compute_min_slack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    slack = getcurrhs(form, constr)
    if getduty(constr) <= AbstractMasterConstr
        var_filter = (var -> isanOriginalRepresentatives(getduty(var)))
    else
        var_filter = (var -> (getduty(var) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[getid(constr),:]
        var = getvar(form, var_id)
        if !var_filter(var) 
            continue
        end
        if coef > 0
            cur_ub = getcurub(form, var)
            if cur_ub == Inf
                alg_data.nb_inf_sources_for_min_slack[getid(constr)] += 1
            else
                slack -= coef * cur_ub
            end
        else
            cur_lb = getcurlb(form, var)
            if cur_lb == -Inf
                alg_data.nb_inf_sources_for_min_slack[getid(constr)] += 1
            else
                slack -= coef * cur_lb
            end
        end
    end
    alg_data.cur_min_slack[getid(constr)] = slack
    return
end

function compute_max_slack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    slack = getcurrhs(form, constr)
    if getduty(constr) <= AbstractMasterConstr
        var_filter = (var -> isanOriginalRepresentatives(getduty(var)))
    else
        var_filter = (var -> (getduty(var) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[getid(constr),:]
        var = getvar(form, var_id)
        if !var_filter(var) 
            continue
        end
        if coef > 0
            cur_lb = getcurlb(form, var)
            if cur_lb == -Inf
                alg_data.nb_inf_sources_for_max_slack[getid(constr)] += 1
            else
                slack -= coef*cur_lb
            end
        else
            cur_ub = getcurub(form, var)
            if cur_ub == Inf
                alg_data.nb_inf_sources_for_max_slack[getid(constr)] += 1
            else
                slack -= coef*cur_ub
            end
        end
    end
    alg_data.cur_max_slack[getid(constr)] = slack
    return
end

function update_max_slack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation,
        var_was_inf_source::Bool, delta::Float64
    )
    alg_data.cur_max_slack[getid(constr)] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_max_slack[getid(constr)] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_max_slack[getid(constr)]
    sense = getcursense(form, constr)
    if nb_inf_sources == 0
        if (sense != Greater) && alg_data.cur_max_slack[getid(constr)] < -0.0001
            return true
        elseif (sense == Greater) && alg_data.cur_max_slack[getid(constr)] <= -0.0001
            # add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if sense != Greater
            add_to_stack!(alg_data, constr, form)
        end
    end
    return false
end

function update_min_slack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation,
        var_was_inf_source::Bool, delta::Float64
    )
    alg_data.cur_min_slack[getid(constr)] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_min_slack[getid(constr)] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_min_slack[getid(constr)]
    sense = getcursense(form, constr)
    if nb_inf_sources == 0
        if (sense != Less) && alg_data.cur_min_slack[getid(constr)] > 0.0001
            return true
        elseif (sense == Less) && alg_data.cur_min_slack[getid(constr)] >= 0.0001
            #add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if sense != Less
            add_to_stack!(alg_data, constr, form)
        end
    end
    return false
end

function add_to_preprocessing_list!(alg_data::PreprocessData, var::Variable)
    if !(var in alg_data.preprocessed_vars)
        push!(alg_data.preprocessed_vars, var)
    end
    return
end

function add_to_preprocessing_list!(
       alg_data::PreprocessData, constr::Constraint
    )
    if !(constr in alg_data.preprocessed_constrs)
        push!(alg_data.preprocessed_constrs, constr)
    end
    return
end

function add_to_stack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    if !alg_data.constr_in_stack[getid(constr)]
        push!(alg_data.stack, (constr, form))
        alg_data.constr_in_stack[getid(constr)] = true
    end
    return
end

function update_lower_bound!(
        alg_data::PreprocessData, var::Variable, form::Formulation,
        new_lb::Float64, check_monotonicity::Bool = true
    )
    cur_lb = getcurlb(form, var)
    cur_ub = getcurub(form, var)
    if new_lb > cur_lb || !check_monotonicity
        if new_lb > cur_ub
            return true
        end

        diff = cur_lb == -Inf ? -new_lb : cur_lb - new_lb
        coef_matrix = getcoefmatrix(form)
        for (constr_id, coef) in Iterators.filter(
            c -> getcurisactive(form,c) && getcurisexplicit(form, c), 
            coef_matrix[:, getid(var)])

            func = coef < 0 ? update_min_slack! : update_max_slack!
            if func(
                    alg_data, getconstr(form, constr_id),
                    form, cur_lb == -Inf , diff * coef
                )
                return true
            end
        end
        alg_data.printing && println(
            "updating lb of var ", getname(var), " from ", cur_lb, " to ",
            new_lb, " duty ", getduty(var)
        )
        setcurlb!(form, var, new_lb)
        add_to_preprocessing_list!(alg_data, var)

        # Now we update bounds of clones
        if getduty(var) == MasterRepPricingVar 
            subprob = find_owner_formulation(form.parent_formulation, var)
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(subprob)]
            clone_in_sp = getvar(subprob, getid(var))
            if update_lower_bound!(
                    alg_data, clone_in_sp, subprob,
                    getcurlb(form, var) - (max(sp_ub, 1) - 1) * getcurub(subprob, clone_in_sp)
                )
                return true
            end
        elseif getduty(var) == DwSpPricingVar
            master = form.parent_formulation
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(form)]
            clone_in_master = getvar(master, getid(var))
            if update_lower_bound!(
                    alg_data, clone_in_master, master, getcurlb(form, var) * sp_lb
                )
                return true
            end
            new_ub_in_sp = (
                getcurub(master, clone_in_master) - (max(sp_lb, 1) - 1) * getcurlb(form, var)
            )
            if update_upper_bound!(alg_data, var, form, new_ub_in_sp)
                return true
            end
        end
    end
    return false
end

function update_upper_bound!(
        alg_data::PreprocessData, var::Variable, form::Formulation,
        new_ub::Float64, check_monotonicity::Bool = true
    )
    cur_lb = getcurlb(form, var)
    cur_ub = getcurub(form, var)
    if new_ub < cur_ub || !check_monotonicity
        if new_ub < cur_lb
            return true
        end

        diff = cur_ub == Inf ? -new_ub : cur_ub - new_ub
        coef_matrix = getcoefmatrix(form)
        for (constr_id, coef) in Iterators.filter(
            c -> getcurisactive(form,c) && getcurisexplicit(form, c), 
            coef_matrix[:, getid(var)])
            func = coef > 0 ? update_min_slack! : update_max_slack!
            if func(
                alg_data, getconstr(form, constr_id),
                form, cur_ub == Inf , diff*coef
            )
                return true
            end
        end
        if alg_data.printing
            println(
                "updating ub of var ", getname(var), " from ", cur_ub,
                " to ", new_ub, " duty ", getduty(var)
            )
        end
        setcurub!(form, var, new_ub)
        add_to_preprocessing_list!(alg_data, var)

        # Now we update bounds of clones
        if getduty(var) == MasterRepPricingVar 
            subprob = find_owner_formulation(form.parent_formulation, var)
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(subprob)]
            clone_in_sp = getvar(subprob, getid(var))
            if update_upper_bound!(
                alg_data, clone_in_sp, subprob,
                getcurub(form, var) - (max(sp_lb, 1) - 1) * getcurlb(subprob, clone_in_sp)
            )
                return true
            end
        elseif getduty(var) == DwSpPricingVar
            master = form.parent_formulation
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(form)]
            clone_in_master = getvar(master, getid(var))
            if update_upper_bound!(
                alg_data, clone_in_master, master, getcurub(form, var) * sp_ub
            )
                return true
            end
            new_lb_in_sp = (
                getcurlb(master, clone_in_master) - (max(sp_ub, 1) - 1) * getcurub(form, var)
            )
            if update_lower_bound!(alg_data, var, form, new_lb_in_sp)
                return true
            end
        end
    end
    return false
end

function adjust_bound(form::Formulation, var::Variable, bound::Float64, is_upper::Bool)
    if getcurkind(form, var) != Continuous 
        bound = is_upper ? floor(bound) : ceil(bound)
    end
    return bound
end

function compute_new_bound(
        nb_inf_sources::Int, slack::Float64, var_contrib_to_slack::Float64,
        inf_bound::Float64, coef::Float64
    )
    if nb_inf_sources == 0
        bound = (slack - var_contrib_to_slack) / coef
    elseif nb_inf_sources == 1 && isinf(var_contrib_to_slack)
        bound = slack / coef 
    else
        bound = inf_bound
    end
    return bound
end

function compute_new_var_bound(
        alg_data::PreprocessData, var::Variable, form::Formulation, 
        cur_lb::Float64, cur_ub::Float64, coef::Float64, constr::Constraint
    )

    if coef > 0 && getcursense(form, constr) == Less
        is_ub = true
        return (is_ub, compute_new_bound(
            alg_data.nb_inf_sources_for_max_slack[getid(constr)],
            alg_data.cur_max_slack[getid(constr)], -coef * cur_lb, Inf, coef
        ))
    elseif coef > 0 && getcursense(form, constr) != Less
        is_ub = false
        return (is_ub, compute_new_bound(
            alg_data.nb_inf_sources_for_min_slack[getid(constr)],
            alg_data.cur_min_slack[getid(constr)], -coef * cur_ub, -Inf, coef
        ))
    elseif coef < 0 && getcursense(form, constr) != Greater
        is_ub = false
        return (is_ub, compute_new_bound(
            alg_data.nb_inf_sources_for_max_slack[getid(constr)],
            alg_data.cur_max_slack[getid(constr)], -coef * cur_ub, -Inf
        ))
    else
        is_ub = true
        return (is_ub, compute_new_bound(
            alg_data.nb_inf_sources_for_min_slack[getid(constr)], 
            alg_data.cur_min_slack[getid(constr)], -coef * cur_lb, Inf
        ))
    end
end

function strengthen_var_bounds_in_constr!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    if getduty(constr) <= AbstractMasterConstr
        var_filter = (var -> isanOriginalRepresentatives(getduty(var)))
    else
        var_filter = (var -> (getduty(var) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (var_id, coef) in coef_matrix[getid(constr),:]
        var = getvar(form, var_id)
        if !var_filter(var) 
            continue
        end
        (is_ub, bound) = compute_new_var_bound(
            alg_data, var, form, getcurlb(form, var), getcurub(form, var), coef, constr
        )
        if !isinf(bound)
            bound = adjust_bound(form, var, bound, is_ub)
            func = is_ub ? update_upper_bound! : update_lower_bound!
            if func(alg_data, var, form, bound)
                return true
            end
        end
    end
    return false
end

function propagation!(alg_data::PreprocessData)
    while !isempty(alg_data.stack)
        (constr, form) = pop!(alg_data.stack)
        alg_data.constr_in_stack[getid(constr)] = false

        if alg_data.printing
            println("constr ", getname(constr), " ", typeof(constr), " popped")
            println(
                "rhs ", getcurrhs(form, constr), " max: ",
                alg_data.cur_max_slack[getid(constr)], " min: ",
                alg_data.cur_min_slack[getid(constr)]
            )
        end
        if strengthen_var_bounds_in_constr!(alg_data, constr, form)
            return true
        end
    end
    return false
end

function forbid_infeasible_columns!(alg_data::PreprocessData)
    master = getmaster(alg_data.reformulation)
    primal_sp_sols = getprimalsolmatrix(getmaster(alg_data.reformulation))
    for var in alg_data.preprocessed_vars
        if getduty(var) == DwSpPricingVar
            for (col_id, coef) in primal_sp_sols[getid(var),:]
                if !(getcurlb(var) <= coef <= getcurub(var)) # TODO ; get the subproblem...
                    setcurub!(master, getvar(master, col_id), 0.0)
                end
            end
        end
    end
    return
end

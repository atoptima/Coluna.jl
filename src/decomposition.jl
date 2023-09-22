function set_glob_art_var(form::Formulation, is_pos::Bool, env::Env)
    name = string("global_", (is_pos ? "pos" : "neg"), "_art_var")
    cost = env.params.global_art_var_cost
    cost *= getobjsense(form) == MinSense ? 1.0 : -1.0
    return setvar!(
        form, name, MasterArtVar;
        cost = cost, lb = 0.0, ub = Inf, kind = Continuous
    )
end

function create_global_art_vars!(masterform::Formulation, env::Env)
    global_pos = set_glob_art_var(masterform, true, env)
    global_neg = set_glob_art_var(masterform, false, env)
    matrix = getcoefmatrix(masterform)
    for (constrid, constr) in getconstrs(masterform)
        iscuractive(masterform, constrid) || continue
        getduty(constrid) <= AbstractMasterOriginConstr || continue
        if getcursense(masterform, constr) == Greater
            matrix[constrid, getid(global_pos)] = 1.0
        elseif getcursense(masterform, constr) == Less
            matrix[constrid, getid(global_neg)] = -1.0
        else # Equal
            matrix[constrid, getid(global_pos)] = 1.0
            matrix[constrid, getid(global_neg)] = -1.0
        end
    end
end

function instantiate_master!(
    env::Env, origform::Formulation{Original}, ::Type{BD.Master}, ::Type{BD.DantzigWolfe}
)
    form = create_formulation!(
        env,
        MathProg.DwMaster();
        obj_sense = getobjsense(origform)
    )
    setobjconst!(form, getobjconst(origform))
    return form
end

function instantiate_master!(
    env::Env, origform::Formulation{Original}, ::Type{BD.Master}, ::Type{BD.Benders}
)
    return create_formulation!(
        env,
        MathProg.BendersMaster();
        obj_sense = getobjsense(origform)
    )
end

function instantiate_sp!(
    env::Env, master::Formulation{DwMaster}, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe}
)
    return create_formulation!(
        env,
        MathProg.DwSp(nothing, nothing, nothing, Integ);
        parent_formulation = master,
        obj_sense = getobjsense(master)
    )
end

function instantiate_sp!(
    env::Env, master::Formulation{BendersMaster}, ::Type{BD.BendersSepSp}, ::Type{BD.Benders}
)
    return create_formulation!(
        env,
        MathProg.BendersSp();
        parent_formulation = master,
        obj_sense = getobjsense(master)
    )
end

# Master of Dantzig-Wolfe decomposition
# We clone the variables and the single variable constraints at the same time
function instantiate_orig_vars!(
    masterform::Formulation{DwMaster},
    origform::Formulation,
    annotations::Annotations,
    mast_ann
)
    vars_per_ann = annotations.vars_per_ann
    for (ann, vars) in vars_per_ann
        formtype = BD.getformulation(ann)
        if formtype <: BD.Master
            for (_, var) in vars
                clonevar!(origform, masterform, masterform, var, MasterPureVar, is_explicit = true)
            end
        end
    end
    return
end

function instantiate_orig_constrs!(
    masterform::Formulation{DwMaster},
    origform::Formulation{Original},
    env::Env,
    annotations::Annotations,
    mast_ann
)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (_, constr) in constrs
        cloneconstr!(
            origform, masterform, masterform, constr, MasterMixedConstr, 
            loc_art_var_abs_cost = env.params.local_art_var_cost
        ) # TODO distinguish Pure versus Mixed
    end
    # Cut generation callbacks
    for constrgen in get_robust_constr_generators(origform)
        set_robust_constr_generator!(masterform, constrgen.kind, constrgen.separation_alg)
    end
    return
end

function create_side_vars_constrs!(
    masterform::Formulation{DwMaster},
    origform::Formulation{Original},
    env::Env,
    annotations::Annotations
)
    coefmatrix = getcoefmatrix(masterform)
    for (spuid, spform) in get_dw_pricing_sps(masterform.parent_formulation)
        ann = get(annotations, spform)
        setupvars = filter(v -> getduty(v.first) == DwSpSetupVar, getvars(spform))
        @assert length(setupvars) == 1
        setupvar = collect(values(setupvars))[1]
        setuprepvar = clonevar!(origform, masterform, spform, setupvar, MasterRepPricingSetupVar, is_explicit = false)

        # create convexity constraint & storing information about the convexity constraint
        # in the duty data of the formulation
        lb_mult = Float64(BD.getlowermultiplicity(ann))
        name = string("sp_lb_", spuid)
        lb_conv_constr = setconstr!(
            masterform, name, MasterConvexityConstr;
            rhs = lb_mult, kind = Essential, sense = Greater, inc_val = 100.0, 
            loc_art_var_abs_cost = env.params.local_art_var_cost
        )
        coefmatrix[getid(lb_conv_constr), getid(setuprepvar)] = 1.0

        ub_mult =  Float64(BD.getuppermultiplicity(ann))
        name = string("sp_ub_", spuid)
        ub_conv_constr = setconstr!(
            masterform, name, MasterConvexityConstr; rhs = ub_mult,
            kind = Essential, sense = Less, inc_val = 100.0, 
            loc_art_var_abs_cost = env.params.local_art_var_cost
        )
        coefmatrix[getid(ub_conv_constr), getid(setuprepvar)] = 1.0

        spform.duty_data.lower_multiplicity_constr_id = getid(lb_conv_constr)
        spform.duty_data.upper_multiplicity_constr_id = getid(ub_conv_constr)
        spform.duty_data.setup_var = getid(setupvar)

        # If pricing subproblem variables are continuous, the master columns generated by
        # the subproblem must have a continuous perenkind.
        # This piece of information is stored in the duty data of the formulation.
        continuous_columns = true
        for (varid, var) in getvars(spform)
            if getduty(varid) <= DwSpPricingVar && getperenkind(spform, var) !== Continuous
                continuous_columns = false
                break
            end
        end
        spform.duty_data.column_var_kind = continuous_columns ? Continuous : Integ
    end
    return
end

function create_artificial_vars!(masterform::Formulation{DwMaster}, env::Env)
    create_global_art_vars!(masterform, env)
    return
end

# Pricing subproblem of Danztig-Wolfe decomposition
function instantiate_orig_vars!(
    spform::Formulation{DwSp},
    origform::Formulation{Original},
    annotations::Annotations,
    sp_ann
)
    !haskey(annotations.vars_per_ann, sp_ann) && return
    vars = annotations.vars_per_ann[sp_ann]
    masterform = spform.parent_formulation
    for (varid, var) in vars
        # An original variable annotated in a subproblem is a DwSpPricingVar
        clonevar!(origform, spform, spform, var, DwSpPricingVar, is_explicit = true)
        
        if haskey(masterform, varid) && !is_representative(annotations, varid)
            error("""
                Variable $(getname(masterform, varid)) is two subproblems but is not representative.
                Please open an issue.
                """)
        end
        
        if !haskey(masterform, varid)
            lb, ub = if is_representative(annotations, varid)
                (
                    getperenlb(origform, var) * sum(BD.getlowermultiplicity.(annotations.ann_per_repr_var[varid])),
                    getperenub(origform, var) * sum(BD.getuppermultiplicity.(annotations.ann_per_repr_var[varid]))
                )
            else
                (
                    getperenlb(origform, var) * BD.getlowermultiplicity(sp_ann),
                    getperenub(origform, var) * BD.getuppermultiplicity(sp_ann)
                )
            end
            clonevar!(
                origform,
                masterform,
                spform,
                var,
                MasterRepPricingVar,
                is_explicit = false,
                lb = lb,
                ub = ub
            )
        end
    end
    return
end

function instantiate_orig_constrs!(
    spform::Formulation{DwSp},
    origform::Formulation{Original},
    ::Env,
    annotations::Annotations,
    sp_ann
)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (_, constr) in constrs
        cloneconstr!(origform, spform, spform, constr, DwSpPureConstr; loc_art_var_abs_cost = 0.0)
    end
    return
end

function create_side_vars_constrs!(
    spform::Formulation{DwSp},
    ::Formulation{Original},
    ::Env,
    ::Annotations
)
    name = "PricingSetupVar_sp_$(getuid(spform))"
    setvar!(
        spform, name, DwSpSetupVar; cost = 0.0, lb = 1.0, ub = 1.0, kind = Integ,
        is_explicit = true
    )
    return
end

function _dutyexpofbendmastvar(
    var::Variable, annotations::Annotations, origform::Formulation{Original}
)
    orig_coef = getcoefmatrix(origform)
    for (constrid, _) in @view orig_coef[:, getid(var)]
        constr_ann = annotations.ann_per_constr[constrid]
        #if coef != 0 && BD.getformulation(constr_ann) == BD.Benders  # TODO use haskey instead testing != 0
        if BD.getformulation(constr_ann) == BD.BendersSepSp
            return MasterBendFirstStageVar, true
        end
    end
    return MasterPureVar, true
end

# Master of Benders decomposition
function instantiate_orig_vars!(
    masterform::Formulation{BendersMaster},
    origform::Formulation{Original},
    annotations::Annotations,
    mast_ann
)
    !haskey(annotations.vars_per_ann, mast_ann) && return
    vars = annotations.vars_per_ann[mast_ann]
    for (_, var) in vars
        clonevar!(origform, masterform, masterform, var, MasterPureVar, is_explicit = true)
    end
    return
end

function instantiate_orig_constrs!(
    masterform::Formulation{BendersMaster},
    origform::Formulation{Original},
    ::Env,
    annotations::Annotations,
    mast_ann
)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (_, constr) in constrs
        cloneconstr!(
            origform, masterform, masterform, constr, MasterPureConstr, is_explicit = true
        )
    end
    return
end

function create_side_vars_constrs!(
    masterform::Formulation{BendersMaster},
    ::Formulation{Original},
    ::Env,
    ::Annotations
)
    for (spid, spform) in get_benders_sep_sps(masterform.parent_formulation)
        name = "η[$(spid)]"
        var = setvar!(
            masterform, name, MasterBendSecondStageCostVar;
            cost = 1.0,
            lb = -Inf,
            ub = Inf,
            kind = Continuous,
            is_explicit = true
        )
        spform.duty_data.second_stage_cost_var = getid(var)
    end
    return
end

create_artificial_vars!(::Formulation{BendersMaster}, ::Env) = return

function instantiate_orig_vars!(
    spform::Formulation{BendersSp},
    origform::Formulation{Original},
    annotations::Annotations,
    sp_ann
)
    if haskey(annotations.vars_per_ann, sp_ann)
        vars = annotations.vars_per_ann[sp_ann]
        for (_, var) in vars
            clonevar!(origform, spform, spform, var, BendSpSepVar, cost = getperencost(origform, var))
        end
    end
    return
end

function _dutyexpofbendspconstr(constr, annotations::Annotations, origform)
    orig_coef = getcoefmatrix(origform)
    for (varid, _) in orig_coef[getid(constr), :]
        var_ann = annotations.ann_per_var[varid]
        if BD.getformulation(var_ann) == BD.Master
            return BendSpTechnologicalConstr, true
        end
    end
    return BendSpPureConstr, true
end

function instantiate_orig_constrs!(
    spform::Formulation{BendersSp},
    origform::Formulation{Original},
    ::Env,
    annotations::Annotations,
    sp_ann
)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (_, constr) in constrs
        duty, explicit  = _dutyexpofbendspconstr(constr, annotations, origform)
        cloneconstr!(origform, spform, spform, constr, duty, is_explicit = explicit, loc_art_var_abs_cost = 1.0)
    end
    return
end

function create_side_vars_constrs!(
    spform::Formulation{BendersSp},
    origform::Formulation{Original},
    ::Env,
    annotations::Annotations
)
    spcoef = getcoefmatrix(spform)
    origcoef = getcoefmatrix(origform)

    # 1st level representative variables.
    masterform = getmaster(spform)
    mast_ann = get(annotations, masterform)
    if haskey(annotations.vars_per_ann, mast_ann)
        vars = annotations.vars_per_ann[mast_ann]
        for (varid, var) in vars
            duty, _ = _dutyexpofbendmastvar(var, annotations, origform)
            if duty == MasterBendFirstStageVar
                name = getname(origform, var)
                repr_id = VarId(
                    varid,
                    duty = BendSpFirstStageRepVar,
                    assigned_form_uid = getuid(masterform)
                )

                repr = setvar!(
                    spform, name, BendSpFirstStageRepVar;
                    cost = getcurcost(origform, var),
                    lb = getcurlb(origform, var),
                    ub = getcurub(origform, var),
                    kind = Continuous,
                    is_explicit = false,
                    id = repr_id
                )

                for (constrid, coeff) in @view origcoef[:, varid]
                    spconstr = getconstr(spform, constrid)
                    if spconstr !== nothing
                        spcoef[getid(spconstr), getid(repr)] = coeff
                    end
                end
            end
        end
    end
    return
end

function assign_orig_vars_constrs!(
    destform::Formulation,
    origform::Formulation{Original},
    env::Env,
    annotations::Annotations,
    ann
)
    instantiate_orig_vars!(destform, origform, annotations, ann)
    instantiate_orig_constrs!(destform, origform, env, annotations, ann)
    clonecoeffs!(origform, destform)
end

_optimizerbuilder(opt::Function) = () -> UserOptimizer(opt)
_optimizerbuilder(opt::MOI.AbstractOptimizer) = () -> MoiOptimizer(opt)
_optimizerbuilder(opt::BD.AbstractCustomOptimizer) = () -> CustomOptimizer(opt)

function getoptimizerbuilders(prob::Problem, ann::BD.Annotation)
    optimizers = BD.getoptimizerbuilders(ann)
    if length(optimizers) > 0
        return map(o -> _optimizerbuilder(o), optimizers)
    end
    return [prob.default_optimizer_builder]
end

function _push_in_sp_dict!(
    dws::Dict{FormId, Formulation{DwSp}}, 
    ::Dict{FormId, Formulation{BendersSp}},
    spform::Formulation{DwSp}
)
    push!(dws, getuid(spform) => spform)
end

function _push_in_sp_dict!(
    ::Dict{FormId, Formulation{DwSp}}, 
    benders::Dict{FormId, Formulation{BendersSp}},
    spform::Formulation{BendersSp}
)
    push!(benders, getuid(spform) => spform)
end

function instantiate_formulations!(
    prob::Problem, env::Env, annotations::Annotations, parent, node::BD.Root
)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    origform = get_original_formulation(prob)
    master = instantiate_master!(env, origform, form_type, dec_type)
    store!(annotations, master, ann)

    dw_pricing_sps = Dict{FormId, Formulation{DwSp}}()
    benders_sep_sps = Dict{FormId, Formulation{BendersSp}}()
    for (_, child) in BD.subproblems(node)
        sp = instantiate_formulations!(prob, env, annotations, master, child)
        _push_in_sp_dict!(dw_pricing_sps, benders_sep_sps, sp)
    end
    return master, dw_pricing_sps, benders_sep_sps
end

function instantiate_formulations!(
    prob::Problem, env::Env, annotations::Annotations, parent::Formulation{MasterDuty}, node::BD.Leaf
) where {MasterDuty}
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    spform = instantiate_sp!(env, parent, form_type, dec_type)
    store!(annotations, spform, ann)
    return spform
end

function build_formulations!(
    reform::Reformulation, prob::Problem, env::Env, annotations::Annotations, parent,
    node::BD.Root
)
    ann = BD.annotation(node)
    master = getmaster(reform)
    for (_, dw_sp) in get_dw_pricing_sps(reform)
        build_formulations!(dw_sp, reform, prob, env, annotations, master)
    end
    for (_, bend_sp) in get_benders_sep_sps(reform)
        build_formulations!(bend_sp, reform, prob, env, annotations, master)
    end

    origform = get_original_formulation(prob)
    assign_orig_vars_constrs!(master, origform, env, annotations, ann)
    create_side_vars_constrs!(master, origform, env, annotations)
    create_artificial_vars!(master, env)
    closefillmode!(getcoefmatrix(master))
    push_optimizer!.(Ref(master), getoptimizerbuilders(prob, ann))
    push_optimizer!.(Ref(origform), getoptimizerbuilders(prob, ann))
end

# parent is master
function build_formulations!(
    spform, reform::Reformulation, prob::Problem, env::Env, annotations::Annotations, parent::Formulation{MasterDuty}
) where {MasterDuty}
    ann = annotations.ann_per_form[getuid(spform)]
    origform = get_original_formulation(prob)
    assign_orig_vars_constrs!(spform, origform, env, annotations, ann)
    create_side_vars_constrs!(spform, origform, env, annotations)
    closefillmode!(getcoefmatrix(spform))
    push_optimizer!.(Ref(spform), getoptimizerbuilders(prob, ann))
end

# Error messages for `check_annotations`.
# TODO: specific error type for these two errors.
_err_check_annotations(id::VarId) = error("""
A variable (id = $id) is not annotated.
Make sure you do not use anonymous variables (variable with no name declared in JuMP macro variable).
Otherwise, open an issue at https://github.com/atoptima/Coluna.jl/issues
""")

_err_check_annotations(id::ConstrId) = error("""
A constraint (id = $id) is not annotated.
Make sure you do not use anonymous constraints (constraint with no name declared in JuMP macro variable).
Otherwise, open an issue at https://github.com/atoptima/Coluna.jl/issues
""")

"""
Make sure that all variables and constraints of the original formulation are
annotated. Otherwise, it returns an error.
"""
function check_annotations(prob::Problem, annotations::Annotations)
    origform = get_original_formulation(prob)

    for (varid, _) in getvars(origform)
        if !haskey(annotations.ann_per_var, varid) && !haskey(annotations.ann_per_repr_var, varid)
            return _err_check_annotations(varid)
        end
    end

    for (constrid, _) in getconstrs(origform)
        if !haskey(annotations.ann_per_constr, constrid)
            return _err_check_annotations(constrid)
        end
    end
    return true
end

function build_reformulation(prob::Problem, annotations::Annotations, env::Env)
    
end

"""
Reformulate the original formulation of prob according to the annotations.
The environment maintains formulation ids.
"""
function reformulate!(prob::Problem, annotations::Annotations, env::Env)
    # Once the original formulation built, we close the "fill mode" of the
    # coefficient matrix which is a super fast writing mode compared to the default
    # writing mode of the dynamic sparse matrix.
    origform = get_original_formulation(prob)
    if getcoefmatrix(origform).matrix.fillmode
        closefillmode!(getcoefmatrix(origform))
    end

    decomposition_tree = annotations.tree
    if !isnothing(decomposition_tree)
        check_annotations(prob, annotations)
    
        root = BD.getroot(decomposition_tree)
        master, dw_pricing_subprs, benders_sep_subprs = instantiate_formulations!(prob, env, annotations, origform, root)
        reform = Reformulation(env, origform, master, dw_pricing_subprs, benders_sep_subprs)
        master.parent_formulation = reform
        set_reformulation!(prob, reform)

        build_formulations!(reform, prob, env, annotations, origform, root)
        relax_integrality!(getmaster(reform))
    else # No decomposition provided by BlockDecomposition
        push_optimizer!(
            prob.original_formulation,
            prob.default_optimizer_builder
        )
    end
    return
end

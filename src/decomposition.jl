set_glob_art_var(f::Formulation, is_pos::Bool) = setvar!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var"),
    MasterArtVar; cost = (getobjsense(f) == MinSense ? 100000.0 : -100000.0),
    lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
)

function create_local_art_vars!(master::Formulation)
    matrix = getcoefmatrix(master)
    constrs = filter(v -> getduty(v[2]) == MasterConvexityConstr, getconstrs(master))
    for (constr_id, constr) in getconstrs(master)
        v = setvar!(
            master, string("local_art_of_", getname(constr)),
            MasterArtVar;
            cost = (getobjsense(master) == MinSense ? 10000.0 : -10000.0),
            lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
        )
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(v)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(v)] = -1.0
        end
    end
    return
end

function create_global_art_vars!(master::Formulation)
    global_pos = set_glob_art_var(master, true)
    global_neg = set_glob_art_var(master, false)
    matrix = getcoefmatrix(master)
    constrs = filter(_active_master_rep_orig_constr_, getconstrs(master))
    for (constr_id, constr) in constrs
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(global_pos)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(global_neg)] = -1.0
        end
    end
end

function build_benders_master!(prob::Problem,
                       annotation_id::Int,
                       reformulation::Reformulation,
                       master_form::Formulation,
                       vars_in_form::VarDict,
                       constrs_in_form::ConstrDict,
                          opt_builder::Function)

   orig_form = get_original_formulation(prob)

    mast_form_uid = getuid(master_form)
    orig_coefficient_matrix = getcoefmatrix(orig_form)
    mast_coefficient_matrix = getcoefmatrix(master_form)
    


    # add SpArtVar and master SecondStageCostVar 
    for sp_form in reformulation.benders_sep_subprs
        sp_uid = getuid(sp_form)
 
        ## add all Sp var in master SecondStageCostConstr
        vars = filter(_active_benders_sp_var_, getvars(sp_form))
        second_stage_cost_exist = false

        ## Identify whether there is a second stage cost
        for (var_id, var) in vars
            cost = getperenecost(var)
            if cost > 0.000001
                second_stage_cost_exist = true
                break
            end
            if cost < - 0.000001
                second_stage_cost_exist = true
                break
            end
            
        end
        
        if (second_stage_cost_exist)
            # create SecondStageCostVar
            name = "cv_sp_$(sp_uid)"
            cost = 1.0
            lb = 0.0
            ub = 1.0
            kind = Continuous
            duty = MasterBendSecondStageCostVar 
            sense = Positive
            is_explicit = true
            second_stage_cost_var = setvar!(
                master_form, name, duty; cost = cost, lb = lb, ub = ub, kind = kind,
                sense = sense, is_explicit = is_explicit
            )
            clone_in_formulation!(sp_form, master_form, second_stage_cost_var,
                                  BendSpRepSecondStageCostVar, false)


            # create SecondStageCostConstr
            name = "cc_sp_$(sp_uid)"
            duty = BendSpSecondStageCostConstr
            rhs = 0.0
            kind = Core
            sense = (getobjsense(orig_form) == MinSense ? Greater : Less)
            second_stage_cost_constr = setconstr!(sp_form, name, duty;
                                                  rhs = rhs, kind = kind,
                                                  sense = sense)
            mast_coefficient_matrix[getid(second_stage_cost_constr),getid(second_stage_cost_var)] = 1.0


            for (var_id, var) in vars
                cost = getperenecost(var)
                mast_coefficient_matrix[getid(second_stage_cost_constr), var_id] = - cost
                setperenecost!(var, 0.0)
                setcurcost!(var, 0.0)
                setcost!(sp_form, var, 0.0)
            end
            

        end

        
 
    end

    
    
    pure_mast_vars = VarDict()
    non_pure_mast_vars = VarDict()
    for id_var in vars_in_form
        constr_membership = orig_coefficient_matrix[:,id_var[1]]
        non_pure_constr_membership = filter(c->(getformuid(c) != mast_form_uid), constr_membership)
        if (length(non_pure_constr_membership) > 0)
            push!(non_pure_mast_vars, id_var)
        else
            push!(pure_mast_vars, id_var)
        end
    end
    # copy of pure master variables
    clone_in_formulation!(master_form, orig_form, pure_mast_vars, MasterPureVar)
    # copy of first stage  master variables
    clone_in_formulation!(master_form, orig_form, non_pure_mast_vars, MasterBendFirstStageVar)
    
    
    # copy of pure master constraints
    clone_in_formulation!(master_form, orig_form, constrs_in_form, MasterPureConstr)

    initialize_optimizer!(master_form, opt_builder)


    return
end


function instantiatemaster!(prob::Problem, reform, ::Type{BD.Master}, ::Type{BD.DantzigWolfe})
    form = Formulation{DwMaster}(
        prob.form_counter; parent_formulation = reform,
        obj_sense = getobjsense(get_original_formulation(prob))
    )
    setmaster!(reform, form)
    return form
end

function instantiatemaster!(prob::Problem, reform, ::Type{BD.Master}, ::Type{BD.Benders})
    form = Formulation{BendersMaster}(
        prob.form_counter; parent_formulation = reform,
        obj_sense = getobjsense(get_original_formulation(prob))
    )
    setmaster!(reform, form)
    return form
end

function instantiatesp!(prob::Problem, reform, mast, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe})
    form = Formulation{DwSp}(
        prob.form_counter; parent_formulation = mast,
        obj_sense = getobjsense(mast)
    )
    add_dw_pricing_sp!(reform, form)
    return form
end

function instantiatesp!(prob::Problem, reform, mast, ::Type{BD.BendersSepSp}, ::Type{BD.Benders})
    form = Formulation{BendersSp}(
        prob.form_counter; parent_formulation = mast,
        obj_sense = getobjsense(mast)
    )
    add_benders_sep_sp!(reform, form)
    return form
end

# Master of Dantzig-Wolfe decomposition
varexpduty(F, BDF, BDD) = error("Cannot deduce duty of original variable in $F annoted in $BDF using $BDD.")
varexpduty(::Type{DwMaster}, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe}) = MasterRepPricingVar, false
varexpduty(::Type{DwMaster}, ::Type{BD.Master}, ::Type{BD.DantzigWolfe}) = MasterPureVar, true

function instantiate_orig_vars!(mast::Formulation{DwMaster}, orig_form, annotations, mast_ann)
    vars_per_ann = annotations.vars_per_ann
    for (ann, vars) in vars_per_ann
        formtype = BD.getformulation(ann)
        dectype = BD.getdecomposition(ann)
        for (id, var) in vars
            duty, explicit = varexpduty(DwMaster, formtype, dectype)
            clone_in_formulation!(mast, orig_form, var, duty, explicit)
        end
    end
    return
end

function instantiate_orig_constrs!(mast::Formulation{DwMaster}, orig_form, annotations, mast_ann)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (id, constr) in constrs
        clone_in_formulation!(mast, orig_form, constr, MasterMixedConstr)
    end
    return
end

function create_side_vars_constrs!(mast::Formulation{DwMaster})
    coefmatrix = getcoefmatrix(mast)
    for sp in mast.parent_formulation.dw_pricing_subprs
        spuid = getuid(sp)
        setupvars = filter(var -> getduty(var[2]) == DwSpSetupVar, getvars(sp))
        @assert length(setupvars) == 1
        setupvar = collect(values(setupvars))[1] # issue 106
        clone_in_formulation!(mast, sp, setupvar, MasterRepPricingSetupVar, false)
        # create convexity constraint
        name = "sp_lb_$spuid"
        lb_conv_constr = setconstr!(
            mast, name, MasterConvexityConstr; rhs = 0.0, kind = Core,
            sense = Greater
        )
        mast.parent_formulation.dw_pricing_sp_lb[spuid] = getid(lb_conv_constr)
        setincval!(getrecordeddata(lb_conv_constr), 100.0)
        setincval!(getcurdata(lb_conv_constr), 100.0)
        coefmatrix[getid(lb_conv_constr), getid(setupvar)] = 1.0

        name = "sp_ub_$spuid"
        rhs = 1.0
        sense = Less
        ub_conv_constr = setconstr!(
            mast, name, MasterConvexityConstr; rhs = 1.0, kind = Core, 
            sense = Less
        )
        mast.parent_formulation.dw_pricing_sp_ub[spuid] = getid(ub_conv_constr)
        setincval!(getrecordeddata(ub_conv_constr), 100.0)
        setincval!(getcurdata(ub_conv_constr), 100.0)       
        coefmatrix[getid(ub_conv_constr), getid(setupvar)] = 1.0
    end
    return
end

function create_artificial_vars!(mast::Formulation{DwMaster})
    create_global_art_vars!(mast)
    create_local_art_vars!(mast)
    return
end

# Pricing subproblem of Danztig-Wolfe decomposition
function instantiate_orig_vars!(sp::Formulation{DwSp}, orig_form, annotations, sp_ann)
    !haskey(annotations.vars_per_ann, sp_ann) && return
    vars = annotations.vars_per_ann[sp_ann]
    for (id, var) in vars
        # An original variable annoted in a subproblem is a DwSpPureVar
        clone_in_formulation!(sp, orig_form, var, DwSpPricingVar)
    end
    return
end

function instantiate_orig_constrs!(sp::Formulation{DwSp}, orig_form, annotations, sp_ann)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (id, constr) in constrs
        clone_in_formulation!(sp, orig_form, constr, DwSpPureConstr)
    end
    return
end

function create_side_vars_constrs!(sp::Formulation{DwSp})
    name = "PricingSetupVar_sp_$(getuid(sp))"
    setvar!(
        sp, name, DwSpSetupVar; cost = 0.0, lb = 1.0, ub = 1.0, 
        kind = Continuous, sense = Positive, is_explicit = true
    )
    return
end

# Master of Benders decomposition
function instantiate_orig_vars!(mast::Formulation{BendersMaster}, orig_form, annotations, mast_ann)
    !haskey(annotations.vars_per_ann, mast_ann) && return
    vars = annotations.vars_per_ann[mast_ann]
    for (id, var) in vars
        clone_in_formulation!(mast, orig_form, var, MasterPureVar)
    end
    setvar!(
        mast, "η", MasterBendSecondStageCostVar; cost = 1.0, lb = -Inf, ub = Inf, 
        kind = Continuous, sense = Free, is_explicit = true
    )
    return
end

function instantiate_orig_constrs!(mast::Formulation{BendersMaster}, orig_form, annotations, mast_ann)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (id, constr) in constrs
        clone_in_formulation!(mast, orig_form, constr, MasterPureConstr)
    end
    return
end

function create_side_vars_constrs!(mast::Formulation{BendersMaster})
    return
end

function create_artificial_vars!(mast::Formulation{BendersMaster})
    return
end

# Separation sp of Benders decomposition
function involvedinbendsp(var, orig_form, annotations, sp_ann)
    !haskey(annotations.constrs_per_ann, sp_ann) && return false
    constrs = annotations.constrs_per_ann[sp_ann]
    orig_coef = getcoefmatrix(orig_form)
    for (constr_id, constr) in constrs
        if orig_coef[constr_id, getid(var)] != 0
            return true
        end
    end
    return false
end

function instantiate_orig_vars!(sp::Formulation{BendersSp}, orig_form, annotations, sp_ann)
    if haskey(annotations.vars_per_ann, sp_ann)
        vars = annotations.vars_per_ann[sp_ann]
        for (id, var) in vars
            clone_in_formulation!(sp, orig_form, var, BendSpSepVar)
        end
    end
    mast_ann = getparent(annotations, sp_ann)
    if haskey(annotations.vars_per_ann, mast_ann)
        vars = annotations.vars_per_ann[mast_ann]
        for (id, var) in vars
            if involvedinbendsp(var, orig_form, annotations, sp_ann)
                name = "μ[$(split(getname(var), "[")[end])"
                μ = setvar!(
                    sp, name, BendSpRepFirstStageVar; cost = 0.0, lb = -Inf, ub = Inf, 
                    kind = Continuous, sense = Free, is_explicit = true, id = id
                )
            end
        end
    end
    return
end

function dutyofbendspconstr(constr, annotations, orig_form)
    orig_coef = getcoefmatrix(orig_form)
    for (varid, coef) in orig_coef[getid(constr), :]
        var_ann = annotations.ann_per_var[varid]
        if coef != 0 && BD.getformulation(var_ann) == BD.Master
            return BendSpTechnologicalConstr
        end
    end
    return BendSpPureConstr
end

function instantiate_orig_constrs!(sp::Formulation{BendersSp}, orig_form, annotations, sp_ann)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (id, constr) in constrs
        duty = dutyofbendspconstr(constr, annotations, orig_form)
        clone_in_formulation!(sp, orig_form, constr, duty)
    end
    return
end

function create_side_vars_constrs!(sp::Formulation{BendersSp})
    sp_coef = getcoefmatrix(sp)
    # Cost constraint
    mast = getmaster(sp)
    η = collect(values(filter(var -> getduty(var[2]) == MasterBendSecondStageCostVar, getvars(mast))))[1]
    ν = setvar!(
        sp, "ν", BendSpRepSecondStageCostVar; cost = 1.0, lb = -Inf, ub = Inf,
        kind = Continuous, sense = Free, is_explicit = true, id = getid(η)
    )
    cost = setconstr!(
        sp, "cost", BendSpSecondStageCostConstr; rhs = 0.0, kind = Core, 
        sense = Equal
    )
    sp_coef[getid(cost), getid(ν)] = 1.0
    for (var_id, var) in filter(var -> getduty(var[2]) == BendSpSepVar, getvars(sp))
            sp_coef[getid(cost), var_id] = - getperenecost(var)
    end
    return
end

function assign_orig_vars_constrs!(form, orig_form, annotations, ann)
    instantiate_orig_vars!(form, orig_form, annotations, ann)
    instantiate_orig_constrs!(form, orig_form, annotations, ann)
    clone_coefficients!(form, orig_form)
end

function getoptbuilder(prob::Problem, ann)
    if BD.getoptimizerbuilder(ann) != nothing
        return BD.getoptimizerbuilder(ann)
    end
    return prob.default_optimizer_builder
end

function buildformulations!(prob::Problem, annotations::Annotations, reform, 
                               parent, node::BD.Root)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    form = instantiatemaster!(prob, reform, form_type, dec_type)
    orig_form = get_original_formulation(prob)
    assign_orig_vars_constrs!(form, orig_form, annotations, ann)
    for (id, child) in BD.subproblems(node)
        buildformulations!(prob, annotations, reform, node, child)
    end
    create_side_vars_constrs!(form)
    create_artificial_vars!(form)
    initialize_optimizer!(form, getoptbuilder(prob, ann))
    return
end

function buildformulations!(prob::Problem, annotations::Annotations, reform, 
                               parent, node::BD.Leaf)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    mast = getmaster(reform)
    form = instantiatesp!(prob, reform, mast, form_type, dec_type)
    orig_form = get_original_formulation(prob)
    assign_orig_vars_constrs!(form, orig_form, annotations, ann)
    create_side_vars_constrs!(form)
    initialize_optimizer!(form, getoptbuilder(prob, ann))
    return
end

function reformulate!(prob::Problem, annotations::Annotations, 
                      strategy::GlobalStrategy)
    decomposition_tree = annotations.tree

    root = BD.getroot(decomposition_tree)

    # Create reformulation
    reform = Reformulation(prob, strategy)
    set_re_formulation!(prob, reform)
    buildformulations!(prob, annotations, reform, reform, root)

    @show getmaster(reform)

    for sp in reform.dw_pricing_subprs
        @show sp
    end

    for sp in reform.benders_sep_subprs
        @show sp
    end
    exit()
end
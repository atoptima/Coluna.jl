set_glob_art_var(f::Formulation, is_pos::Bool) = setvar!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var"),
    MasterArtVar; cost = (getobjsense(f) == MinSense ? 100000.0 : -100000.0),
    lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
)

function create_local_art_vars!(master_form::Formulation)
    matrix = getcoefmatrix(master_form)
    constrs = filter(v -> getduty(v[2]) == MasterConvexityConstr, getconstrs(master_form))
    for (constr_id, constr) in getconstrs(master_form)
        v = setvar!(
            master_form, string("local_art_of_", getname(constr)),
            MasterArtVar;
            cost = (getobjsense(master_form) == MinSense ? 10000.0 : -10000.0),
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

function create_global_art_vars!(master_form::Formulation)
    global_pos = set_glob_art_var(master_form, true)
    global_neg = set_glob_art_var(master_form, false)
    matrix = getcoefmatrix(master_form)
    constrs = filter(_active_master_rep_orig_constr_, getconstrs(master_form))
    for (constr_id, constr) in constrs
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(global_pos)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(global_neg)] = -1.0
        end
    end
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
    master_form = Formulation{BendersMaster}(
        prob.form_counter; parent_formulation = reform,
        obj_sense = getobjsense(get_original_formulation(prob))
    )
    setmaster!(reform, master_form)
    return master_form
end

function instantiatesp!(prob::Problem, reform, master_form, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe})
    sp_form = Formulation{DwSp}(
        prob.form_counter; parent_formulation = master_form,
        obj_sense = getobjsense(master_form)
    )
    add_dw_pricing_sp!(reform, sp_form)
    return sp_form
end

function instantiatesp!(prob::Problem, reform, master_form, ::Type{BD.BendersSepSp}, ::Type{BD.Benders})
    sp_form = Formulation{BendersSp}(
        prob.form_counter; parent_formulation = master_form,
        obj_sense = getobjsense(master_form)
    )
    add_benders_sep_sp!(reform, sp_form)
    return sp_form
end

# Master of Dantzig-Wolfe decomposition

# returns the duty of a variable and whether it is explicit according to the 
# type of formulation it belongs and the type of formulation it will clone in.
varexpduty(F, BDF, BDD) = error("Cannot deduce duty of original variable in $F annoted in $BDF using $BDD.")
varexpduty(::Type{DwMaster}, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe}) = MasterRepPricingVar, false
varexpduty(::Type{DwMaster}, ::Type{BD.Master}, ::Type{BD.DantzigWolfe}) = MasterPureVar, true

function instantiate_orig_vars!(master_form::Formulation{DwMaster}, orig_form::Formulation, annotations, mast_ann)
    vars_per_ann = annotations.vars_per_ann
    for (ann, vars) in vars_per_ann
        formtype = BD.getformulation(ann)
        dectype = BD.getdecomposition(ann)
        for (id, var) in vars
            duty, explicit = varexpduty(DwMaster, formtype, dectype)
            clonevar!(master_form, var, duty, is_explicit = explicit)
        end
    end
    return
end

function instantiate_orig_constrs!(master_form::Formulation{DwMaster}, orig_form::Formulation, annotations, mast_ann)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (id, constr) in constrs
        cloneconstr!(master_form, constr, MasterMixedConstr) # TODO distinguish Pure versus Mixed
    end
    return
end


function create_side_vars_constrs!(master_form::Formulation{DwMaster}, orig_form::Formulation, annotations)
    coefmatrix = getcoefmatrix(master_form)
    for sp_form in master_form.parent_formulation.dw_pricing_subprs
        spuid = getuid(sp_form)
        ann = get(annotations, sp_form)
        setupvars = filter(var -> getduty(var[2]) == DwSpSetupVar, getvars(sp_form))
        @assert length(setupvars) == 1
        setupvar = collect(values(setupvars))[1] # issue 106
        clonevar!(master_form, setupvar, MasterRepPricingSetupVar, is_explicit = false)
        # create convexity constraint
        lb_mult = Float64(BD.getminmultiplicity(ann))
        name = string("sp_lb_", spuid)
        lb_conv_constr = setconstr!(
            master_form, name, MasterConvexityConstr; 
            rhs = lb_mult, kind = Core, sense = Greater
        )
        master_form.parent_formulation.dw_pricing_sp_lb[spuid] = getid(lb_conv_constr)
        setincval!(getrecordeddata(lb_conv_constr), 100.0)
        setincval!(getcurdata(lb_conv_constr), 100.0)
        coefmatrix[getid(lb_conv_constr), getid(setupvar)] = 1.0

        ub_mult =  Float64(BD.getmaxmultiplicity(ann))
        name = string("sp_ub_", spuid)
        ub_conv_constr = setconstr!(
            master_form, name, MasterConvexityConstr; rhs = ub_mult, 
            kind = Core, sense = Less
        )
        master_form.parent_formulation.dw_pricing_sp_ub[spuid] = getid(ub_conv_constr)
        setincval!(getrecordeddata(ub_conv_constr), 100.0)
        setincval!(getcurdata(ub_conv_constr), 100.0)       
        coefmatrix[getid(ub_conv_constr), getid(setupvar)] = 1.0
    end
    return
end

function create_artificial_vars!(master_form::Formulation{DwMaster})
    create_global_art_vars!(master_form)
    create_local_art_vars!(master_form)
    return
end

# Pricing subproblem of Danztig-Wolfe decomposition
function instantiate_orig_vars!(sp_form::Formulation{DwSp}, orig_form::Formulation, annotations, sp_ann)
    !haskey(annotations.vars_per_ann, sp_ann) && return
    vars = annotations.vars_per_ann[sp_ann]
    for (id, var) in vars
        # An original variable annoted in a subproblem is a DwSpPureVar
        clonevar!(sp_form, var, DwSpPricingVar)
    end
    return
end

function instantiate_orig_constrs!(sp_form::Formulation{DwSp}, orig_form::Formulation, annotations, sp_ann)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (id, constr) in constrs
        cloneconstr!(sp_form, constr, DwSpPureConstr)
    end
    return
end


function create_side_vars_constrs!(sp_form::Formulation{DwSp}, orig_form::Formulation, annotations)
    name = "PricingSetupVar_sp_$(getuid(sp_form))"
    setvar!(
    sp_form, name, DwSpSetupVar; cost = 0.0, lb = 1.0, ub = 1.0, 
        kind = Continuous, sense = Positive, is_explicit = true
    ) 
    return
end


function dutyexpofbendmastvar(var, annotations, orig_form::Formulation)
    orig_coef = getcoefmatrix(orig_form)
    for (constrid, coef) in orig_coef[:, getid(var)]
        constr_ann = annotations.ann_per_constr[constrid]
        #if coef != 0 && BD.getformulation(constr_ann) == BD.Benders  # TODO use haskey instead testing != 0
        if BD.getformulation(constr_ann) == BD.BendersSepSp 
            return MasterBendFirstStageVar, true
        end
    end
    return MasterPureVar, true
end



# Master of Benders decomposition
function instantiate_orig_vars!(master_form::Formulation{BendersMaster}, orig_form, annotations, mast_ann)
    !haskey(annotations.vars_per_ann, mast_ann) && return
    vars = annotations.vars_per_ann[mast_ann]
    for (id, var) in vars
        duty, explicit = dutyexpofbendmastvar(var, annotations, orig_form)
        clonevar!(master_form, var, duty, is_explicit = explicit)
    end
    return
end

function dutyexpofbendmastconstr(constr, annotations, orig_form::Formulation)
    #==orig_coef = getcoefmatrix(orig_form)
    for (varid, coef) in orig_coef[getid(constr), :]
        var_ann = annotations.ann_per_var[varid]
        if BD.getformulation(var_ann) == BD.BendersSepSp 
            return MasterRepBendSpTechnologicalConstr, false
        end
    end ==# # All constr annotated for master are in master
    return MasterPureConstr, true
end

function instantiate_orig_constrs!(master_form::Formulation{BendersMaster}, orig_form::Formulation, annotations, mast_ann)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (id, constr) in constrs
        duty, explicit = dutyexpofbendmastconstr(constr, annotations, orig_form)
        cloneconstr!(master_form, constr, duty, is_explicit = explicit)
    end
    return
end

function create_side_vars_constrs!(master_form::Formulation{BendersMaster}, orig_form::Formulation, annotations)
    
    coefmatrix = getcoefmatrix(master_form)

    eta = setvar!(
        master_form, "η", MasterBendSecondStageCostVar; cost = 1.0,
        lb = 0.0 , ub = Inf, 
        kind = Continuous, sense = Free, is_explicit = true
    )
    cost = setconstr!(
        master_form, "cost", MasterRepBendSpSecondStageCostConstr; rhs = 0.0, kind = Core, 
        sense = Equal, is_explicit = true
    )
    coefmatrix[getid(cost), getid(eta)] = 1.0
    
    for sp_form in master_form.parent_formulation.benders_sep_subprs
        nu = collect(values(filter(var -> getduty(var[2]) == BendSpSlackSecondStageCostVar, getvars(sp_form))))[1]
        name = "ν[$(split(getname(nu), "[")[end])"
        setvar!(
            master_form, name, MasterBendSecondStageCostVar; cost = 0.0,
            lb = -  Inf, ub = Inf, 
            kind = Continuous, sense = Free, is_explicit = true, id = getid(nu)
        )
        coefmatrix[getid(cost), getid(nu)] = - 1.0
        
        #==techno_constrs = filter(c -> getduty(c[2]) == BendSpTechnologicalConstr, getconstrs(sp_form))
        @show techno_constrs
        for (constr_id, constr) in techno_constrs
        cloneconstr!(master_form, constr, MasterRepBendSpTechnologicalConstr, is_explicit = false)
        end  ==#                                       
    end
    return
end

function create_artificial_vars!(master_form::Formulation{BendersMaster})
    return
end

# Separation sp_form of Benders decomposition
#function involvedinbendsp(var, orig_form, annotations, sp_ann)
#    !haskey(annotations.constrs_per_ann, sp_ann) && return false
#    constrs = annotations.constrs_per_ann[sp_ann]
#    orig_coef = getcoefmatrix(orig_form)
#    for (constr_id, constr) in constrs
#        if orig_coef[constr_id, getid(var)] != 0 # TODO use haskey instead
#            return true
#        end
#    end
#    return false
#end

function instantiate_orig_vars!(sp_form::Formulation{BendersSp}, orig_form::Formulation, annotations, sp_ann)
    if haskey(annotations.vars_per_ann, sp_ann)
        vars = annotations.vars_per_ann[sp_ann]
        for (id, var) in vars
            clonevar!(sp_form, var, BendSpSepVar, cost = 0.0)
        end
    end
    mast_ann = getparent(annotations, sp_ann)
    if haskey(annotations.vars_per_ann, mast_ann)
        vars = annotations.vars_per_ann[mast_ann]
        for (id, var) in vars
            duty, explicit = dutyexpofbendmastvar(var, annotations, orig_form)
            if duty == MasterBendFirstStageVar
                name = "μ[$(split(getname(var), "[")[end])"
                #clonevar!(sp_form, var, BendSpSepVar)
                mu = setvar!(
                    sp_form, name, BendSpSlackFirstStageVar; cost = getcurcost(var),
                    lb = - getcurub(var), ub = getcurub(var), 
                    kind = Continuous, sense = getcursense(var), is_explicit = true, id = id
                )
            end
        end
    end
    return
end


function dutyexpofbendspconstr(constr, annotations, orig_form)
    orig_coef = getcoefmatrix(orig_form)
    for (varid, coef) in orig_coef[getid(constr), :]
        var_ann = annotations.ann_per_var[varid]
        if BD.getformulation(var_ann) == BD.Master
            return BendSpTechnologicalConstr, true
        end
    end
    return BendSpPureConstr, true
end

function instantiate_orig_constrs!(sp_form::Formulation{BendersSp}, orig_form::Formulation, annotations, sp_ann)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (id, constr) in constrs
        duty, explicit  = dutyexpofbendspconstr(constr, annotations, orig_form)
        cloneconstr!(sp_form, constr, duty, is_explicit = explicit)
    end
    return
end

function create_side_vars_constrs!(sp_form::Formulation{BendersSp}, orig_form::Formulation, annotations)
    sp_coef = getcoefmatrix(sp_form)
    sp_id = getuid(sp_form)
    # Cost constraint
    master_form = sp_form.parent_formulation
    nu = setvar!(
        sp_form, "ν[$sp_id]", BendSpSlackSecondStageCostVar; cost = 1.0, lb = -Inf, ub = Inf,
        kind = Continuous, sense = Free, is_explicit = true
    )
    cost = setconstr!(
        sp_form, "cost[$sp_id]", BendSpSecondStageCostConstr; rhs = 0.0, kind = Core, 
        sense = Equal, is_explicit = true
    )
    sp_coef[getid(cost), getid(nu)] = 1.0
    #@show "*****scost****" getvars(sp_form)
    for (var_id, var) in filter(id_var -> getduty(id_var[2]) == BendSpSepVar, getvars(sp_form))  
        orig_var = getvar(orig_form, var_id)
        #@show "*****orig_var****" orig_var
        sp_coef[getid(cost), var_id] = - getperenecost(orig_var)         
    end
    return
end

function assign_orig_vars_constrs!(form, orig_form::Formulation, annotations, ann)
    instantiate_orig_vars!(form, orig_form, annotations, ann)
    instantiate_orig_constrs!(form, orig_form, annotations, ann)
    clonecoeffs!(form, orig_form)
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
    master_form = instantiatemaster!(prob, reform, form_type, dec_type)
    store!(annotations, master_form, ann)
    orig_form = get_original_formulation(prob)
    assign_orig_vars_constrs!(master_form, orig_form, annotations, ann)
    for (id, child) in BD.subproblems(node)
        buildformulations!(prob, annotations, reform, node, child)
    end
    create_side_vars_constrs!(master_form, orig_form, annotations)
    create_artificial_vars!(master_form)
    initialize_optimizer!(master_form, getoptbuilder(prob, ann))
    return
end

function buildformulations!(prob::Problem, annotations::Annotations, reform, 
                            parent, node::BD.Leaf)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    master_form = getmaster(reform)
    sp_form = instantiatesp!(prob, reform, master_form, form_type, dec_type)
    store!(annotations, sp_form, ann)
    orig_form = get_original_formulation(prob)
    assign_orig_vars_constrs!(sp_form, orig_form, annotations, ann)
    create_side_vars_constrs!(sp_form, orig_form, annotations)
    initialize_optimizer!(sp_form, getoptbuilder(prob, ann))
    return
end

function reformulate!(prob::Problem, annotations::Annotations, 
                      strategy::GlobalStrategy)
    decomposition_tree = annotations.tree

    root = BD.getroot(decomposition_tree)
    @show prob.original_formulation
                                                 
    # Create reformulation
    reform = Reformulation(prob, strategy)
    set_re_formulation!(prob, reform)
    buildformulations!(prob, annotations, reform, reform, root)

    # println("\e[1;31m ------------- \e[00m")
    # @show get_original_formulation(prob)
    # println("\e[1;31m ------------- \e[00m")
    # @show getmaster(reform)
    # println("\e[1;32m ------------- \e[00m")
    # for sp in reform.benders_sep_subprs
    #     @show sp
    #     println("\e[1;32m ------------- \e[00m")
    #     #exit()
    # end
end

#if duty <: AbstractMasterRepBendSpnConstr
#cloneconstr!(master_form, constr, duty)
#end

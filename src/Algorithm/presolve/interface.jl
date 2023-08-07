struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
end

function create_presolve_form(form::Formulation, keep_var::Function, keep_constr::Function)
    coef_submatrix = _submatrix(form, keep_constr, keep_var)
    
    @show form
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

    for (spid, sp) in get_dw_pricing_sps(reform)
        presolve_sp = create_presolve_form(sp, sp_vars, sp_constrs)
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
end
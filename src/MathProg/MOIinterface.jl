### Some notes:
#
# - Make use of : MOI.VariablePrimalStart(), MOI.ConstraintPrimalStart(),
#                 MOI.ConstraintDualStart(), MOI.ConstraintBasisStatus()
#
# - RawSolver() -> For directly interacting with solver
#
############################################################

function set_obj_sense!(optimizer::MoiOptimizer, ::Type{<:MaxSense})
    MOI.set(getinner(optimizer), MOI.ObjectiveSense(), MOI.MAX_SENSE)
    return
end

function set_obj_sense!(optimizer::MoiOptimizer, ::Type{<:MinSense})
    MOI.set(getinner(optimizer), MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return
end

function update_bounds_in_optimizer!(form::Formulation, optimizer::MoiOptimizer, var::Variable)
    inner = getinner(optimizer)
    moi_record = getmoirecord(var)
    moi_kind = getkind(moi_record)
    moi_bounds = getbounds(moi_record)
    moi_index = getindex(moi_record)
    if getcurkind(form, var) == Binary && moi_index.value != -1
        MOI.delete(inner, moi_kind)
        setkind!(moi_record, MOI.add_constraint(
            inner, MOI.SingleVariable(moi_index), MOI.Integer()
        ))
    end
    if moi_bounds.value != -1
        MOI.set(inner, MOI.ConstraintSet(), moi_bounds,
            MOI.Interval(getcurlb(form, var), getcurub(form, var))
        )
    else
        setbounds!(moi_record, MOI.add_constraint(
            inner, MOI.SingleVariable(moi_index),
            MOI.Interval(getcurlb(form, var), getcurub(form, var))
        ))
    end
    return
end

function update_cost_in_optimizer!(form::Formulation, optimizer::MoiOptimizer, var::Variable)
    cost = getcurcost(form, var)
    moi_index = getindex(getmoirecord(var))
    MOI.modify(
        getinner(optimizer), MoiObjective(),
        MOI.ScalarCoefficientChange{Float64}(moi_index, cost)
    )
    return
end

function update_obj_const_in_optimizer!(form::Formulation, optimizer::MoiOptimizer)
    MOI.modify(
        getinner(optimizer), MoiObjective(), 
        MOI.ScalarConstantChange{Float64}(getobjconst(form))
    )
    return
end

function update_constr_member_in_optimizer!(optimizer::MoiOptimizer,
                                            c::Constraint, v::Variable,
                                            coeff::Float64)
    moi_c_index = getindex(getmoirecord(c))
    moi_v_index = getindex(getmoirecord(v))
    MOI.modify(
        getinner(optimizer), moi_c_index,
        MOI.ScalarCoefficientChange{Float64}(moi_v_index, coeff)
    )
    return
end

function update_constr_rhs_in_optimizer!(
    form::Formulation, optimizer::MoiOptimizer, constr::Constraint
)
    moi_c_index = getindex(getmoirecord(constr))
    rhs = getcurrhs(form, constr)
    sense = getcursense(form, constr)
    MOI.set(getinner(optimizer), MOI.ConstraintSet(), moi_c_index, convert_coluna_sense_to_moi(sense)(rhs))
    return
end

function enforce_bounds_in_optimizer!(
    form::Formulation, optimizer::MoiOptimizer, var::Variable
)
    moirecord = getmoirecord(var)
    moi_bounds = MOI.add_constraint(
        getinner(optimizer), MOI.SingleVariable(getindex(moirecord)),
        MOI.Interval(getcurlb(form, var), getcurub(form, var))
    )
    setbounds!(moirecord, moi_bounds)
    return
end

function enforce_kind_in_optimizer!(
    form::Formulation, optimizer::MoiOptimizer, v::Variable
)
    inner = getinner(optimizer)
    kind = getcurkind(form, v)
    moirecord = getmoirecord(v)
    moi_kind = getkind(moirecord)
    if moi_kind.value != -1
        if MOI.is_valid(inner, moi_kind)
            MOI.delete(inner, moi_kind)
        end
        setkind!(moirecord, MoiVarKind())
    end
    if kind != Continuous # Continuous is translated as no constraint in MOI
        moi_set = (kind == Binary ? MOI.ZeroOne() : MOI.Integer())
        setkind!(moirecord, MOI.add_constraint(
            inner, MOI.SingleVariable(getindex(moirecord)), moi_set
        ))
    end
    return
end

function add_to_optimizer!(form::Formulation, optimizer::MoiOptimizer, var::Variable)
    inner = getinner(optimizer)
    moirecord = getmoirecord(var)
    moi_index = MOI.add_variable(inner)
    setindex!(moirecord, moi_index)
    update_cost_in_optimizer!(form, optimizer, var)
    enforce_kind_in_optimizer!(form, optimizer, var)
    enforce_bounds_in_optimizer!(form, optimizer, var)
    MOI.set(inner, MOI.VariableName(), moi_index, getname(form, var))
    return
end

function add_to_optimizer!(
    form::Formulation, optimizer::MoiOptimizer, constr::Constraint, var_checker::Function
)
    constr_id = getid(constr)
    inner = getinner(optimizer)
    matrix = getcoefmatrix(form)
    terms = MOI.ScalarAffineTerm{Float64}[]
    for (varid, coeff) in @view matrix[constr_id, :]
        if var_checker(form, varid)
            moi_id = getindex(getmoirecord(getvar(form, varid)))
            push!(terms, MOI.ScalarAffineTerm{Float64}(coeff, moi_id))
        end
    end

    lhs = MOI.ScalarAffineFunction(terms, 0.0)
    moi_set = convert_coluna_sense_to_moi(getcursense(form, constr))
    moi_constr = MOI.add_constraint(
        inner, lhs, moi_set(getcurrhs(form, constr))
    )
    
    moirecord = getmoirecord(constr)
    setindex!(moirecord, moi_constr)
    MOI.set(inner, MOI.ConstraintName(), moi_constr, getname(form, constr))
    return
end

function remove_from_optimizer!(form::Formulation, optimizer::MoiOptimizer, ids::Set{Id{T}}) where {
    T <: AbstractVarConstr}
    for id in ids
        vc = getelem(form, id)
        @logmsg LogLevel(-3) string("Removing varconstr of name ", getname(form, vc))
        remove_from_optimizer!(form, optimizer, vc)
    end
    return
end

function remove_from_optimizer!(::Formulation, optimizer::MoiOptimizer, var::Variable)                       
    inner = getinner(optimizer)
    moirecord = getmoirecord(var)
    @assert getindex(moirecord).value != -1
    MOI.delete(inner, getbounds(moirecord))
    setbounds!(moirecord, MoiVarBound())
    getkind(moirecord).value != -1 && MOI.delete(inner, getkind(moirecord))
    setkind!(moirecord, MoiVarKind())
    MOI.delete(inner, getindex(moirecord))
    setindex!(moirecord, MoiVarIndex())
    return
end

function remove_from_optimizer!(
    ::Formulation, optimizer::MoiOptimizer, constr::Constraint
)
    moirecord = getmoirecord(constr)
    @assert getindex(moirecord).value != -1
    MOI.delete(getinner(optimizer), getindex(moirecord))
    setindex!(moirecord, MoiConstrIndex())
    return
end

function _getcolunakind(record::MoiVarRecord)
    record.kind.value == -1 && return Continuous
    record.kind isa MoiBinary && return Binary
    return Integ
end

function _getreducedcost(form::Formulation, optimizer, var::Variable)
    varname = getname(form, var)
    opt = typeof(optimizer)
    @warn """
        Cannot retrieve reduced cost of variable $varname from formulation solved with optimizer of type $opt. 
        Method returns nothing.
    """
    return
end

function getreducedcost(form::Formulation, optimizer::MoiOptimizer, var::Variable)
    sign = getobjsense(form) == MinSense ? 1.0 : -1.0
    inner = getinner(optimizer)
    if MOI.get(inner, MOI.ResultCount()) < 1
        @warn """
            No dual solution stored in the optimizer of formulation. Cannot retrieve reduced costs.
            Method returns nothing.
        """
        return
    end
    if !iscuractive(form, var) || !isexplicit(form, var)
        varname = getname(form, var)
        @warn """
            Cannot retrieve reduced cost of variable $varname because the variable must be active and explicit.
            Method returns nothing.
        """
        return
    end
    bounds_interval_idx = getbounds(getmoirecord(var))
    dualval = MOI.get(inner, MOI.ConstraintDual(1), bounds_interval_idx)
    return sign * dualval
end
getreducedcost(form::Formulation, optimizer::MoiOptimizer, varid::VarId) = getreducedcost(form, optimizer, getvar(form, varid))

function get_primal_solutions(form::F, optimizer::MoiOptimizer) where {F <: Formulation}
    inner = getinner(optimizer)
    nb_primal_sols = MOI.get(inner, MOI.ResultCount())
    solutions = PrimalSolution{F}[]
    for res_idx in 1:nb_primal_sols
        if MOI.get(inner, MOI.PrimalStatus(res_idx)) != MOI.FEASIBLE_POINT
            continue
        end

        solcost = getobjconst(form)
        solvars = VarId[]
        solvals = Float64[]

        # Get primal values of variables
        for (id, var) in getvars(form)
            iscuractive(form, id) && isexplicit(form, id) || continue
            moirec = getmoirecord(var)
            moi_index = getindex(moirec)
            val = MOI.get(inner, MOI.VariablePrimal(res_idx), moi_index)
            solcost += val * getcurcost(form, id)
            val = round(val, digits = Coluna.TOL_DIGITS)
            if abs(val) > Coluna.TOL
                push!(solvars, id)
                push!(solvals, val)
            end
        end
        push!(solutions, PrimalSolution(form, solvars, solvals, solcost, FEASIBLE_SOL))
    end
    return solutions
end

function get_dual_solutions(form::F, optimizer::MoiOptimizer) where {F <: Formulation}
    inner = getinner(optimizer)
    nb_dual_sols = MOI.get(inner, MOI.ResultCount())
    solutions = DualSolution{F}[]
    for res_idx in 1:nb_dual_sols
        if MOI.get(inner, MOI.DualStatus(res_idx)) != MOI.FEASIBLE_POINT
            continue
        end

        solcost = getobjconst(form)
        solconstrs = ConstrId[]
        solvals = Float64[]

        # Get dual value of constraints
        for (id, constr) in getconstrs(form)
            moi_index = getindex(getmoirecord(constr))
            MOI.is_valid(inner, moi_index) || continue
            val = MOI.get(inner, MOI.ConstraintDual(res_idx), moi_index)
            solcost += val * getcurrhs(form, id)
            val = round(val, digits = Coluna.TOL_DIGITS)
            if abs(val) > Coluna.TOL
                push!(solconstrs, id)
                push!(solvals, val)      
            end
        end

        # Get reduced cost of variables
        var_red_costs = Dict{VarId, Tuple{Float64,ActiveBound}}()
        for (varid, var) in getvars(form)
            moi_bounds_index = getbounds(getmoirecord(var))
            MOI.is_valid(inner, moi_bounds_index) || continue
            basis_status = MOI.get(inner, MOI.ConstraintBasisStatus(res_idx), moi_bounds_index)
            val = MOI.get(inner, MOI.ConstraintDual(res_idx), moi_bounds_index)
            if basis_status == MOI.NONBASIC_AT_LOWER
                solcost += val * getcurlb(form, varid)
                if abs(val) > Coluna.TOL
                    var_red_costs[varid] = (val, LOWER)
                end
            elseif basis_status == MOI.NONBASIC_AT_UPPER
                solcost += val * getcurub(form, varid)
                if abs(val) > Coluna.TOL
                    var_red_costs[varid] = (val, UPPER)
                end
            end
        end
        push!(solutions, DualSolution(
            form, solconstrs, solvals, solcost, FEASIBLE_SOL; var_red_costs = var_red_costs
        ))
    end
    return solutions
end

function _show_function(io::IO, moi_model::MOI.ModelLike,
                        func::MOI.ScalarAffineFunction)
    for term in func.terms
        moi_index = term.variable_index
        coeff = term.coefficient
        name = MOI.get(moi_model, MOI.VariableName(), moi_index)
        if name == ""
            name = string("x", moi_index.value)
        end
        print(io, " + ", coeff, " ", name)
    end
    return
end

function _show_function(io::IO, moi_model::MOI.ModelLike,
                        func::MOI.SingleVariable)
    moi_index = func.variable
    name = MOI.get(moi_model, MOI.VariableName(), moi_index)
    if name == ""
        name = string("x", moi_index.value)
    end
    print(io, " + ", name)
    return
end

get_moi_set_info(set::MOI.EqualTo) = ("==", set.value)
get_moi_set_info(set::MOI.GreaterThan) = (">=", set.lower)
get_moi_set_info(set::MOI.LessThan) = ("<=", set.upper)
get_moi_set_info(set::MOI.Integer) = ("is", "Integer")
get_moi_set_info(set::MOI.ZeroOne) = ("is", "Binary")
get_moi_set_info(set::MOI.Interval) = (
    "is bounded in", string("[", set.lower, ";", set.upper, "]")
)

function _show_set(io::IO, moi_model::MOI.ModelLike,
                   set::MOI.AbstractScalarSet)
    op, rhs = get_moi_set_info(set)
    print(io, " ", op, " ", rhs)
    return
end

function _show_constraint(io::IO, moi_model::MOI.ModelLike,
                          moi_index::MOI.ConstraintIndex)
    name = MOI.get(moi_model, MOI.ConstraintName(), moi_index)
    if name == ""
        name = string("constr_", moi_index.value)
    end
    print(io, name, " : ")
    func = MOI.get(moi_model, MOI.ConstraintFunction(), moi_index)
    _show_function(io, moi_model, func)
    set = MOI.get(moi_model, MOI.ConstraintSet(), moi_index)
    _show_set(io, moi_model, set)
    println(io, "")
    return
end

function _show_constraints(io::IO, moi_model::MOI.ModelLike)
    for (F, S) in MOI.get(moi_model, MOI.ListOfConstraints())
        F == MOI.SingleVariable && continue
        for moi_index in MOI.get(moi_model, MOI.ListOfConstraintIndices{F, S}())
            _show_constraint(io, moi_model, moi_index)
        end
    end
    for (F, S) in MOI.get(moi_model, MOI.ListOfConstraints())
        F !== MOI.SingleVariable && continue
        for moi_index in MOI.get(moi_model, MOI.ListOfConstraintIndices{MOI.SingleVariable,S}())
            _show_constraint(io, moi_model, moi_index)
        end
    end
    return
end

function _show_obj_fun(io::IO, moi_model::MOI.ModelLike)
    sense = MOI.get(moi_model, MOI.ObjectiveSense())
    sense == MOI.MIN_SENSE ? print(io, "Min") : print(io, "Max")
    obj = MOI.get(moi_model, MoiObjective())
    _show_function(io, moi_model, obj)
    println(io, "")
    return
end

function _show_optimizer(io::IO, optimizer::MOI.ModelLike)
    println(io, "MOI Optimizer {", typeof(optimizer), "} = ")
    _show_obj_fun(io, optimizer)
    _show_constraints(io, optimizer)
    return
end

_show_optimizer(io::IO, optimizer::MOI.Utilities.CachingOptimizer) = _show_optimizer(io, optimizer.model_cache)

Base.show(io::IO, optimizer::MoiOptimizer) = _show_optimizer(io, getinner(optimizer))

### Some notes:
#
# - Make use of : MOI.VariablePrimalStart(), MOI.ConstraintPrimalStart(),
#                 MOI.ConstraintDualStart(), MOI.ConstraintBasisStatus()
#
# - RawSolver() -> For directly interacting with solver
#
############################################################

getinner(opt::MOIU.CachingOptimizer) = opt.model_cache.inner
getinner(opt::MOI.ModelLike) = opt.inner

function create_moi_optimizer(factory::JuMP.OptimizerFactory,
                              sense::Type{<:AbstractObjSense})
    # optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), factory())
    optimizer = factory()
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer, MoiObjective(),f)
    set_obj_sense(optimizer, sense)
    return optimizer
end

function set_obj_sense(optimizer::MOI.AbstractOptimizer, ::Type{<:MaxSense})
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    return
end

function set_obj_sense(optimizer::MOI.AbstractOptimizer, ::Type{<:MinSense})
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return
end

function compute_moi_terms(members::VarMembership)
    return [
        MOI.ScalarAffineTerm{Float64}(
            coef, getindex(getmoirecord(getelements(members)[id]))
        ) for (id, coef) in members
    ]
end

function compute_moi_terms(var_dict::VarDict)
    return [
        MOI.ScalarAffineTerm{Float64}(
            get_cost(getcurdata(var)), getindex(getmoirecord(var))
        ) for (id, var) in var_dict
    ]
end

function set_optimizer_obj(moi_optimizer::MOI.AbstractOptimizer,
                           new_obj::VarDict)
    terms = compute_moi_terms(new_obj)
    objf = MOI.ScalarAffineFunction(terms, 0.0)
    MOI.set(moi_optimizer, MoiObjective(), objf)
    return
end

function update_cost_in_optimizer(optimizer::MOI.AbstractOptimizer, v::Variable)
    cost = get_cost(getcurdata(v))
    moi_index = getindex(getmoirecord(v))
    MOI.modify(
        optimizer, MoiObjective(),
        MOI.ScalarCoefficientChange{Float64}(moi_index, cost)
    )
    return
end

function update_constr_member_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                           c::Constraint, v::Variable,
                                           coeff::Float64)
    moi_c_index = getindex(getmoirecord(c))
    moi_v_index = getindex(getmoirecord(v))
    MOI.modify(
        optimizer, moi_c_index,
        MOI.ScalarCoefficientChange{Float64}(moi_v_index, coeff)
    )
    return
end

function enforce_bounds_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                     v::Variable)
    cur_data = getcurdata(v)
    moirecord = getmoirecord(v)
    moi_bounds = MOI.add_constraint(
        optimizer, MOI.SingleVariable(getindex(moirecord)),
        MOI.Interval(getlb(cur_data), getub(cur_data))
    )
    setbounds!(moirecord, moi_bounds)
    return
end

function enforce_var_kind_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                       v::Variable)
    kind = getkind(getcurdata(v))
    moirecord = getmoirecord(v)
    if kind == Continuous
        moi_bounds = getbounds(moirecord)
        if moi_bounds.value != -1
            MOI.delete(optimizer, moi_bounds)
            setbounds!(moirecord, MoiVarBound(-1))
        end
    else
        moi_set = (kind == Binary ? MOI.ZeroOne() : MOI.Integer())
        setkind!(moirecord, MOI.add_constraint(
            optimizer, MOI.SingleVariable(getindex(moirecord)), moi_set
        ))
    end
    return
end

function add_to_optimzer!(optimizer::MOI.AbstractOptimizer, v::Variable)
    cur_data = getcurdata(v)
    moirecord = getmoirecord(v)
    moi_index = MOI.add_variable(optimizer)
    setindex!(moirecord, moi_index)
    update_cost_in_optimizer(optimizer, v)
    enforce_var_kind_in_optimizer(optimizer, v)
    if (getkind(cur_data) != Binary)
        enforce_bounds_in_optimizer(optimizer, v)
    end
    MOI.set(optimizer, MOI.VariableName(), moi_index, getname(v))
    return
end

function add_to_optimzer!(optimizer::MOI.AbstractOptimizer,
                          constr::Constraint,
                          members::VarMembership)

    terms = compute_moi_terms(members)
    f = MOI.ScalarAffineFunction(terms, 0.0)
    cur_data = getcurdata(constr)
    moi_set = get_moi_set(setsense(cur_data))
    moi_constr = MOI.add_constraint(
        optimizer, f, moi_set(getrhs(cur_data))
    )
    moirecord = getmoirecord(constr)
    setindex!(moirecord, moi_constr)
    MOI.set(optimizer, MOI.ConstraintName(), moi_constr, getname(constr))
    return
end

function fill_primal_sol(moi_optimizer::MOI.AbstractOptimizer,
                         sol::Dict{VarId,Float64},
                         vars::VarDict, res_idx::Int = 1)
    for (id, var) in vars
        moi_index = getindex(getmoirecord(var))
        val = MOI.get(moi_optimizer, MOI.VariablePrimal(res_idx), moi_index)
        #@logmsg LogLevel(-4) string("Var ", getname(var), " = ", val)
        if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            sol[id] = val
        end
    end
    return
end

function fill_dual_sol(moi_optimizer::MOI.AbstractOptimizer,
                       sol::Dict{ConstrId,Float64},
                       constrs::ConstrDict)
    for (id, constr) in constrs
        val = 0.0
        moi_index = getindex(getmoirecord(constr))
        try # This try is needed because of the erroneous assertion in LQOI
            val = MOI.get(moi_optimizer, MOI.ConstraintDual(), moi_index)
        catch err
            if (typeof(err) == AssertionError &&
                !(err.msg == "dual >= 0.0" || err.msg == "dual <= 0.0"))
                throw(err)
            end
        end
        # @logmsg LogLevel(-4) string("Constr dual ", constr.name, " = ",
        #                             constr.val)
        # @logmsg LogLevel(-4) string("Constr primal ", constr.name, " = ",
        #                             MOI.get(optimizer, MOI.ConstraintPrimal(),
        #                                     constr.moi_index))
        if val > 0.000001 || val < - 0.000001 # todo use a tolerance
            sol[id] = val
        end
    end
    return
end

function call_moi_optimize_with_silence(optimizer::MOI.AbstractOptimizer)
    #backup_stdout = stdout
    #(rd_out, wr_out) = redirect_stdout()
    MOI.optimize!(optimizer)
    #close(wr_out)
    #close(rd_out)
    #redirect_stdout(backup_stdout)
    return
end

function remove_from_optimizer!(optimizer::MOI.AbstractOptimizer,
                                var::Variable)
    moirecord = getmoirecord(var)
    @assert getindex(moirecord).value != -1
    MOI.delete(optimizer, getbounds(moirecord))
    setbounds!(moirecord, MoiVarBound())
    MOI.delete(optimizer, getkind(moirecord))
    setkind!(moirecord, MoiVarKind())
    MOI.delete(optimizer, getindex(moirecord))
    setindex!(optimizer, MoiVarIndex())
    return
end

function remove_from_optimizer!(optimizer::MOI.AbstractOptimizer,
                                constr::Constraint)
    moirecord = getmoirecord(constr)
    @assert getindex(moirecord).value != -1
    MOI.delete(optimizer, getindex(moirecord))
    setindex!(optimizer, MoiConstrIndex())
    return
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

function _show_optimizer(io::IO, moi_optimizer::MOI.ModelLike)
    println(io, "MOI Optimizer {", typeof(moi_optimizer), "} = ")
    _show_obj_fun(io, moi_optimizer)
    _show_constraints(io, moi_optimizer)
    return
end

Base.show(io::IO, moi_optimizer::MOIU.CachingOptimizer) = _show_optimizer(io, moi_optimizer.model_cache)

Base.show(io::IO, moi_optimizer::MOI.ModelLike) = _show_optimizer(io, moi_optimizer)

_show_optimizer(moi_optimizer::MOI.ModelLike) = _show_optimizer(stdout, moi_optimizer)
